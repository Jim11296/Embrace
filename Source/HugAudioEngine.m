//
//  AudioGraph.m
//  Embrace
//
//  Created by Ricci Adams on 2018-11-21.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "HugAudioEngine.h"

#import "HugLimiter.h"
#import "HugLinearRamper.h"
#import "HugStereoField.h"
#import "HugFastUtils.h"
#import "HugLevelMeter.h"
#import "HugMeterData.h"
#import "HugSimpleGraph.h"
#import "HugRingBuffer.h"
#import "HugUtils.h"
#import "HugAudioSettings.h"
#import "HugAudioSource.h"

//!graph: Awkward
#import "Player.h"
#import "TrackScheduler.h"
#import "MTSEscapePod.h"
#import "Preferences.h"

static void sMemoryBarrier()
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    OSMemoryBarrier();
    #pragma clang diagnostic pop
}


static void sAtomicIncrement64Barrier(volatile OSAtomic_int64_aligned64_t *theValue)
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    OSAtomicIncrement64Barrier(theValue);
    #pragma clang diagnostic pop
}


static BOOL sCheckError(OSStatus err, NSString *operation)
{
    return HugCheckError(err, @"HugAudioEngine", operation);
}


enum {
    PacketTypeUnknown = 0,

    // Transmitted via _statusRingBuffer
    PacketTypePlayback = 1,
    PacketTypeMeter    = 2,
    PacketTypeDanger   = 3,
    
    // Transmitted via _errorRingBuffer
    PacketTypeStatusBufferFull = 101, // Uses PacketDataUnknown
    PacketTypeOverload         = 102, // Uses PacketDataUnknown
    PacketTypeErrorMessage     = 200,
};

typedef struct {
    uint64_t timestamp;
    UInt16 type;
} PacketDataUnknown;

typedef struct {
    uint64_t timestamp;
    UInt16 type;
    HugPlaybackInfo info;
} PacketDataPlayback;

typedef struct {
    uint64_t timestamp;
    UInt16 type;
    UInt16 frameCount;
    uint64_t renderTime;
} PacketDataDanger;

typedef struct {
    uint64_t timestamp;
    UInt16 type;
    HugMeterDataStruct leftMeterData;
    HugMeterDataStruct rightMeterData;
} PacketDataMeter;

typedef struct {
    uint64_t timestamp;
    UInt16 type;
    UInt16 msgLength;
    char   message[0];
} PacketErrorMessage;

typedef struct {
    volatile SInt64 inputID;
    volatile HugAudioSourceInputBlock inputBlock;

    volatile SInt64 nextInputID;
    volatile HugAudioSourceInputBlock nextInputBlock;

    volatile float     stereoWidth;
    volatile float     stereoBalance;
    volatile float     volume;
    volatile float     preGain;

    volatile UInt64    renderStart;
} RenderUserInfo;


static OSStatus sOutputUnitRenderCallback(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData)
{
    __unsafe_unretained AURenderPullInputBlock block = (__bridge __unsafe_unretained AURenderPullInputBlock) *(void **)inRefCon;
    OSStatus err = block(ioActionFlags, inTimeStamp, inNumberFrames, 0, ioData);

    if (err) NSLog(@"%ld", (long)err);
    
    return err;
}


static OSStatus sHandleAudioDeviceOverload(AudioObjectID inObjectID, UInt32 inNumberAddresses, const AudioObjectPropertyAddress inAddresses[], void *inClientData)
{
    PacketDataUnknown packet = { 0, PacketTypeOverload };
    HugRingBufferWrite((HugRingBuffer *)inClientData, &packet, sizeof(packet));
    
    return noErr;
}


@implementation HugAudioEngine {
    RenderUserInfo _renderUserInfo;

    HugAudioSource *_currentSource;
    AudioUnit _outputAudioUnit;

    HugSimpleGraph *_graph;
    AURenderPullInputBlock _graphRenderBlock;

    AudioDeviceID _outputDeviceID;
    NSDictionary *_outputSettings;

    HugLimiter      *_emergencyLimiter;
    HugStereoField  *_stereoField;
    HugLevelMeter   *_leftLevelMeter;
    HugLevelMeter   *_rightLevelMeter;
    HugLinearRamper *_preGainRamper;
    HugLinearRamper *_volumeRamper;

    HugRingBuffer   *_errorRingBuffer;
    HugRingBuffer   *_statusRingBuffer;

    HugPlaybackStatus _playbackStatus;
    NSTimeInterval    _timeElapsed;
    NSTimeInterval    _timeRemaining;
    HugMeterData     *_leftMeterData;
    HugMeterData     *_rightMeterData;
    float             _dangerLevel;
    NSTimeInterval    _lastOverloadTime;

    NSArray<AUAudioUnit *> *_effectAudioUnits;
}


- (void) uninitializeAll
{
//    [self _iterateGraphAudioUnits:^(AudioUnit unit, NSString *unitString) {
//        sCheckError(AudioUnitUninitialize(unit), @"AudioUnitUninitialize");
//    }];
    
    for (AUAudioUnit *unit in _effectAudioUnits) {
        [unit deallocateRenderResources];
    }
}


- (void) buildTail
{
    HugLogMethod();

    AudioComponentDescription outputCD = {
        kAudioUnitType_Output,
        kAudioUnitSubType_HALOutput,
        kAudioUnitManufacturer_Apple,
        kAudioComponentFlag_SandboxSafe,
        0
    };

    AudioComponent outputComponent = AudioComponentFindNext(NULL, &outputCD);

    sCheckError( AudioComponentInstanceNew(outputComponent, &_outputAudioUnit), @"AudioComponentInstanceNew[ Output ]" );

    _stereoField      = HugStereoFieldCreate();
    _preGainRamper    = HugLinearRamperCreate();
    _volumeRamper     = HugLinearRamperCreate();
    _leftLevelMeter   = HugLevelMeterCreate();
    _rightLevelMeter  = HugLevelMeterCreate();
    _emergencyLimiter = HugLimiterCreate();
    
    _statusRingBuffer = HugRingBufferCreate(8196);
    _errorRingBuffer  = HugRingBufferCreate(8196);

    [self updateVolume:0];
    [self updateStereoBalance:0];
}


- (void) _sendAudioSourceToRenderThread:(HugAudioSource *)source
{
    HugLog(@"HugAudioEngine", @"Sending %@ to render thread", source);

    HugAudioSourceInputBlock inputBlock = [source inputBlock];

    if ([self isRunning]) {
        _renderUserInfo.nextInputBlock = inputBlock;
        sMemoryBarrier();

        sAtomicIncrement64Barrier(&_renderUserInfo.nextInputID);

        NSInteger loopGuard = 0;
        while (1) {
            sMemoryBarrier();

            if (_renderUserInfo.inputID == _renderUserInfo.nextInputID) {
                break;
            }
        
            if (![self isRunning]) return;

            if (loopGuard >= 1000) {
                HugLog(@"HugAudioEngine", @"_sendAudioSourceToRenderThread timed out");
                break;
            }

            usleep(1000);
            loopGuard++;
        }
    } else {
        _renderUserInfo.inputBlock = nil;
        _renderUserInfo.nextInputBlock = inputBlock;
        sMemoryBarrier();

        sAtomicIncrement64Barrier(&_renderUserInfo.nextInputID);
    }
    
    _currentSource = source;
}


- (void) reconnectGraph
{
    HugLogMethod();

    HugLimiter      *limiter          = _emergencyLimiter;
    HugStereoField  *stereoField      = _stereoField;
    HugLevelMeter   *leftLevelMeter   = _leftLevelMeter;
    HugLevelMeter   *rightLevelMeter  = _rightLevelMeter;
    HugLinearRamper *preGainRamper    = _preGainRamper;
    HugLinearRamper *volumeRamper     = _volumeRamper;
    HugRingBuffer   *statusRingBuffer = _statusRingBuffer;
    HugRingBuffer   *errorRingBuffer  = _errorRingBuffer;

    RenderUserInfo *userInfo = &_renderUserInfo;

    HugSimpleGraph *graph = [[HugSimpleGraph alloc] init];
     
    void (^__sendStatusPacket)(void *, CFIndex) = ^(void *buffer, CFIndex length) {
        if (!HugRingBufferWrite(statusRingBuffer, buffer, length)) {
            PacketDataUnknown packet = { 0, PacketTypeStatusBufferFull };
            HugRingBufferWrite(errorRingBuffer, &packet, sizeof(packet));
        }
    };
    #define sendStatusPacket(packet) __sendStatusPacket(&(packet), sizeof((packet)));
    
    [graph addBlock:^(
        AudioUnitRenderActionFlags *ioActionFlags,
        const AudioTimeStamp *timestamp,
        AUAudioFrameCount inNumberFrames,
        NSInteger inputBusNumber,
        AudioBufferList *ioData
    ) {
        userInfo->renderStart = HugGetCurrentHostTime();

        HugAudioSourceInputBlock inputBlock = userInfo->inputBlock;
        HugPlaybackInfo info = {0};
        
        BOOL willChangeUnits = (userInfo->nextInputID != userInfo->inputID);

        float *leftData  = ioData->mNumberBuffers > 0 ? ioData->mBuffers[0].mData : NULL;
        float *rightData = ioData->mNumberBuffers > 1 ? ioData->mBuffers[1].mData : NULL;

        if (!inputBlock) {
            *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
            HugApplySilence(leftData, inNumberFrames);
            HugApplySilence(rightData, inNumberFrames);

        } else {
            inputBlock(inNumberFrames, ioData, &info);
            
            // Do something with status

    //        if (rand() % 100 == 0) {
    //            usleep(50000);
    //        }

            HugStereoFieldProcess(stereoField, leftData, rightData, inNumberFrames, userInfo->stereoBalance, userInfo->stereoWidth);
            HugLinearRamperProcess(preGainRamper, leftData, rightData, inNumberFrames, userInfo->preGain);

            if (willChangeUnits) {
                HugApplyFade(leftData,  inNumberFrames, 1.0, 0.0);
                HugApplyFade(rightData, inNumberFrames, 1.0, 0.0);
            }
        }

        if (willChangeUnits) {
            userInfo->inputBlock = userInfo->nextInputBlock;
            
            HugLinearRamperReset(preGainRamper, userInfo->preGain);
            HugLinearRamperReset(volumeRamper,  userInfo->volume);
            HugStereoFieldReset(stereoField, userInfo->stereoBalance, userInfo->stereoWidth);

            sMemoryBarrier();

            userInfo->inputID = userInfo->nextInputID;
        }

        if (timestamp->mFlags & kAudioTimeStampHostTimeValid) {
            PacketDataPlayback packet = { timestamp->mHostTime, PacketTypePlayback, info };
            sendStatusPacket(packet);
        }

        return noErr;
    }];

    double sampleRate = [[_outputSettings objectForKey:HugAudioSettingSampleRate] doubleValue];
    UInt32 frameSize  = [[_outputSettings objectForKey:HugAudioSettingFrameSize] unsignedIntValue];
    
    if (sampleRate && frameSize) {
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:2];
        
        [_outputSettings objectForKey:HugAudioSettingFrameSize];
        
        for (AUAudioUnit *unit in _effectAudioUnits) {
            NSError *error = nil;

            if (![unit renderResourcesAllocated]) {
                [unit setMaximumFramesToRender:frameSize];

                AUAudioUnitBus *inputBus  = [[unit inputBusses]  objectAtIndexedSubscript:0];
                AUAudioUnitBus *outputBus = [[unit outputBusses] objectAtIndexedSubscript:0];
                
                if (!error) [inputBus  setFormat:format error:&error];
                if (!error) [outputBus setFormat:format error:&error];
                if (!error) [unit allocateRenderResourcesAndReturnError:&error];
                
                [inputBus setEnabled:YES];
                [outputBus setEnabled:YES];
            }
            
            if (error) {
                NSLog(@"%@", error);
            } else  {
                [graph addAudioUnit:unit];
            }
        }
    }

    [graph addBlock:^(
        AudioUnitRenderActionFlags *ioActionFlags,
        const AudioTimeStamp *timestamp,
        AUAudioFrameCount inNumberFrames,
        NSInteger inputBusNumber,
        AudioBufferList *ioData
    ) {
        uint64_t currentTime = HugGetCurrentHostTime();

        MTSEscapePodSetIgnoredThread(mach_thread_self());
        
        size_t meterFrameCount = HugLevelMeterGetMaxFrameCount(_leftLevelMeter);
        
        NSInteger offset = 0;
        NSInteger framesRemaining = inNumberFrames;

        float *leftData  = ioData->mNumberBuffers > 0 ? ioData->mBuffers[0].mData : NULL;
        float *rightData = ioData->mNumberBuffers > 1 ? ioData->mBuffers[1].mData : NULL;

        float volume = userInfo->volume;
        HugLinearRamperProcess(volumeRamper, leftData, rightData, inNumberFrames, volume);
        
        while (framesRemaining > 0) {
            NSInteger framesToProcess = MIN(framesRemaining, meterFrameCount);

            PacketDataMeter packet = {0};
            packet.timestamp = currentTime;
            packet.type = PacketTypeMeter;

            if (leftData) {
                HugLevelMeterProcess(leftLevelMeter, leftData + offset, framesToProcess);

                packet.leftMeterData.peakLevel = HugLevelMeterGetPeakLevel(leftLevelMeter);
                packet.leftMeterData.heldLevel = HugLevelMeterGetHeldLevel(leftLevelMeter);
            }

            if (rightData) {
                HugLevelMeterProcess(rightLevelMeter, rightData + offset, framesToProcess);

                packet.rightMeterData.peakLevel = HugLevelMeterGetPeakLevel(rightLevelMeter);
                packet.rightMeterData.heldLevel = HugLevelMeterGetHeldLevel(rightLevelMeter);
            }

            HugLimiterProcess(limiter, leftData + offset, rightData + offset, framesToProcess);
            packet.leftMeterData.limiterActive = HugLimiterIsActive(limiter);
            packet.rightMeterData.limiterActive = packet.leftMeterData.limiterActive;

            sendStatusPacket(packet);

            framesRemaining -= meterFrameCount;
            offset += meterFrameCount;
        }
        
        // Calculate danger level and send packet
        {
            uint64_t renderTime = HugGetCurrentHostTime() - userInfo->renderStart;
            PacketDataDanger packet = { currentTime, PacketTypeDanger, inNumberFrames, renderTime };
            sendStatusPacket(packet);
        }
        
        return noErr;
    }];

    _graph = graph;
    _graphRenderBlock = [graph renderBlock];
}


- (BOOL) configureWithDeviceID:(AudioDeviceID)deviceID settings:(NSDictionary *)settings
{
    __block BOOL ok = YES;

    void (^checkError)(OSStatus, NSString *, NSString *) = ^(OSStatus error, NSString *formatString, NSString *unitString) {
        if (ok) {

            if (!sCheckError(error, [NSString stringWithFormat:formatString, unitString])) {
                ok = NO;
            }
        }
    };

    // Listen for kAudioDeviceProcessorOverload
    {
        AudioObjectPropertyAddress overloadAddress = { kAudioDeviceProcessorOverload, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster };

        if (_outputDeviceID) {
            AudioObjectRemovePropertyListener(_outputDeviceID, &overloadAddress, sHandleAudioDeviceOverload, (void *)_errorRingBuffer);
        }
        
        if (deviceID) {
            AudioObjectAddPropertyListener(deviceID, &overloadAddress, sHandleAudioDeviceOverload, (void *)_errorRingBuffer);
        }
    }

    UInt32 frames = [[settings objectForKey:HugAudioSettingFrameSize] unsignedIntValue];
    UInt32 framesSize = sizeof(frames);

    double sampleRate = [[settings objectForKey:HugAudioSettingSampleRate] doubleValue];

    AURenderCallbackStruct renderCallback = { &sOutputUnitRenderCallback, &_graphRenderBlock };

    checkError(AudioUnitSetProperty(_outputAudioUnit,
        kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0,
        &frames,
        sizeof(frames)
    ), @"AudioUnitSetProperty[ Output, kAudioDevicePropertyBufferFrameSize]", nil);
    
    checkError(AudioUnitSetProperty(_outputAudioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &deviceID, sizeof(deviceID)
    ), @"AudioUnitSetProperty[ Output, CurrentDevice]", nil);

    checkError(AudioUnitGetProperty(_outputAudioUnit,
        kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
        &frames, &framesSize
    ), @"AudioUnitGetProperty[ Output, MaximumFramesPerSlice ]", nil);

    checkError(AudioUnitSetProperty(_outputAudioUnit,
        kAudioUnitProperty_SampleRate, kAudioUnitScope_Input, 0,
        &sampleRate, sizeof(sampleRate)
    ), @"AudioUnitSetProperty[ Output, SampleRate, Input ]", nil);

    checkError(AudioUnitSetProperty(_outputAudioUnit,
        kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0,
        &renderCallback,
        sizeof(renderCallback)
    ), @"AudioUnitSetProperty[ Output, kAudioDevicePropertyBufferFrameSize]", nil);

    _outputDeviceID = deviceID;
    _outputSettings = settings;

    HugLog(@"HugAudioEngine", @"Configuring audio units with %lf sample rate, %ld frame size", sampleRate, (long)framesSize);

    checkError(AudioUnitInitialize(_outputAudioUnit), @"AudioUnitInitialize[ Output ]", nil);
    
/*
    [self _iterateGraphAudioUnits:^(AudioUnit unit, NSString *unitString) {
        Float64 inputSampleRate  = sampleRate;
        Float64 outputSampleRate = sampleRate;

//        if (unit == _inputAudioUnit) {
//            inputSampleRate = 0;

        if (unit == _outputAudioUnit) {
            outputSampleRate = 0;
        }
        
        if (inputSampleRate) {
            checkError(AudioUnitSetProperty(
                unit,
                kAudioUnitProperty_SampleRate, kAudioUnitScope_Input, 0,
                &inputSampleRate, sizeof(inputSampleRate)
            ), @"AudioUnitSetProperty[ %@, SampleRate, Input ]", unitString);
        }

        if (outputSampleRate) {
            checkError(AudioUnitSetProperty(
                unit,
                kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0,
                &outputSampleRate, sizeof(outputSampleRate)
            ), @"AudioUnitSetProperty[ %@, SampleRate, Output ]", unitString);
        }

        checkError(AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
            &frames, framesSize
        ), @"AudioUnitSetProperty[ %@, MaximumFramesPerSlice ]", unitString);

        checkError(AudioUnitInitialize(
            unit
        ), @"AudioUnitInitialize[ %@ ]", unitString);
    }];
    */


    HugLevelMeterSetSampleRate(_leftLevelMeter, sampleRate);
    HugLevelMeterSetSampleRate(_rightLevelMeter, sampleRate);
    HugLimiterSetSampleRate(_emergencyLimiter, sampleRate);

    HugLinearRamperSetMaxFrameCount(_preGainRamper, frames);
    HugLinearRamperSetMaxFrameCount(_volumeRamper, frames);
    HugStereoFieldSetMaxFrameCount(_stereoField, frames);

    size_t meterFrame = MIN(frames, 1024);
    HugLevelMeterSetMaxFrameCount(_leftLevelMeter, meterFrame);
    HugLevelMeterSetMaxFrameCount(_rightLevelMeter, meterFrame);

    return ok;
}


- (BOOL) playAudioFile: (HugAudioFile *) file
             startTime: (NSTimeInterval) startTime
              stopTime: (NSTimeInterval) stopTime
               padding: (NSTimeInterval) padding
{
    // Stop first, this should clear the playing HugAudioSource and
    // release the large HugProtectedBuffer objects for the current track.
    //
    [self stop];

    HugAudioSource *source = [[HugAudioSource alloc] initWithAudioFile:file settings:_outputSettings];
    
    if (![source prepareWithStartTime:startTime stopTime:stopTime padding:padding]) {
        HugLog(@"HugAudioEngine", @"Couldn't prepare %@", source);
        return NO;
    }
    
    [self _sendAudioSourceToRenderThread:source];

    EmbraceLog(@"Player", @"setup complete, starting graph");
    [self start];
    
    return YES;
}


#pragma mark - Update Methods

- (void) _reallyStop
{
    sCheckError(AudioOutputUnitStop(_outputAudioUnit), @"AudioOutputUnitStop");
}


- (void) start
{
    HugLogMethod();

    if (![self isRunning]) {
        sCheckError(AudioOutputUnitStart(_outputAudioUnit), @"AudioOutputUnitStart");
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reallyStop) object:nil];
}


- (void) stop
{
    if ([self isRunning]) {
        [self _sendAudioSourceToRenderThread:nil];
        [self performSelector:@selector(_reallyStop) withObject:nil afterDelay:30];
    }
    
    for (AUAudioUnit *unit in _effectAudioUnits) {
        [unit reset];
    }
}


- (void) updateStereoWidth:(float)stereoWidth
{
    _renderUserInfo.stereoWidth = stereoWidth;
}


- (void) updateStereoBalance:(float)stereoBalance
{
    _renderUserInfo.stereoBalance = stereoBalance;
}


- (void) updatePreGain:(float)preGain
{
    _renderUserInfo.preGain = preGain;
}


- (void) updateVolume:(float)volume
{
    _renderUserInfo.volume = volume;
}


- (void) updateEffectAudioUnits:(NSArray<AUAudioUnit *> *)effectAudioUnits
{
    if (_effectAudioUnits != effectAudioUnits || ![_effectAudioUnits isEqual:effectAudioUnits]) {
        _effectAudioUnits = effectAudioUnits;
        [self reconnectGraph];
    }
}


#pragma mark - Properties

- (BOOL) isRunning
{
    if (!_outputAudioUnit) return NO;

    Boolean isRunning = false;
    UInt32 size = sizeof(isRunning);
    sCheckError(
        AudioUnitGetProperty(_outputAudioUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &isRunning, &size),
        @"sIsOutputUnitRunning"
    );
    
    return isRunning ? YES : NO;
}


- (void) _readRingBuffers
{
    uint64_t current = HugGetCurrentHostTime();

    // Process status
    while (1) {
        PacketDataUnknown *unknown = HugRingBufferGetReadPtr(_statusRingBuffer, sizeof(PacketDataUnknown));
        if (!unknown) break;
        
        if (unknown->timestamp >= current) {
            break;
        }
        
        if (unknown->type == PacketTypePlayback) {
            PacketDataPlayback packet;
            if (!HugRingBufferRead(_statusRingBuffer, &packet, sizeof(PacketDataPlayback))) return;

            _playbackStatus = packet.info.status;
            _timeElapsed    = packet.info.timeElapsed;
            _timeRemaining  = packet.info.timeRemaining;

        } else if (unknown->type == PacketTypeMeter) {
            PacketDataMeter packet;
            if (!HugRingBufferRead(_statusRingBuffer, &packet, sizeof(PacketDataMeter))) return;
            
            _leftMeterData  = [[HugMeterData alloc] initWithStruct:packet.leftMeterData];
            _rightMeterData = [[HugMeterData alloc] initWithStruct:packet.rightMeterData];

        } else if (unknown->type == PacketTypeDanger) {
            PacketDataDanger packet;
            if (!HugRingBufferRead(_statusRingBuffer, &packet, sizeof(PacketDataDanger))) return;
            
            uint64_t renderTime = packet.renderTime;

            double outputSampleRate = [[_outputSettings objectForKey:HugAudioSettingSampleRate] doubleValue];
            
            double callbackDuration = packet.frameCount / outputSampleRate;
            double elapsedDuration  = HugGetSecondsWithHostTime(renderTime);
            
            _dangerLevel = elapsedDuration / callbackDuration;

        } else {
            NSAssert(NO, @"Unknown packet type: %ld", (long)unknown->type);
        }
    }
    
    // Process error buffer
    while (1) {
        PacketDataUnknown *unknown = HugRingBufferGetReadPtr(_errorRingBuffer, sizeof(PacketDataUnknown));
        if (!unknown) return;

        if (unknown->type == PacketTypeOverload) {
            PacketDataUnknown packet;
            if (!HugRingBufferRead(_errorRingBuffer, &packet, sizeof(PacketDataUnknown))) return;

            _lastOverloadTime = [NSDate timeIntervalSinceReferenceDate];

            HugLog(@"HugAudioEngine", @"kAudioDeviceProcessorOverload detected");
           
        } else if (unknown->type == PacketTypeStatusBufferFull) {
            PacketDataUnknown packet;
            if (!HugRingBufferRead(_errorRingBuffer, &packet, sizeof(PacketDataUnknown))) return;

            HugLog(@"HugAudioEngine", @"_statusRingBuffer is full");
            
        } else if (unknown->type == PacketTypeErrorMessage) {
        
        }
    }
}


#pragma mark - Accessors

- (HugPlaybackStatus) playbackStatus
{
    [self _readRingBuffers];
    return _playbackStatus;
}


- (NSTimeInterval) timeElapsed
{
    [self _readRingBuffers];
    return _timeElapsed;
}


- (NSTimeInterval) timeRemaining
{
    [self _readRingBuffers];
    return _timeRemaining;
}


- (HugMeterData *) leftMeterData
{
    [self _readRingBuffers];
    return _leftMeterData;
}


- (HugMeterData *) rightMeterData
{
    [self _readRingBuffers];
    return _rightMeterData;
}


- (float) dangerLevel
{
    [self _readRingBuffers];
    return _dangerLevel;
}


- (NSTimeInterval) lastOverloadTime
{
    [self _readRingBuffers];
    return _lastOverloadTime;
}


@end
