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

enum {
    PacketTypeUnknown = 0,

    // Transmitted via _statusRingBuffer
    PacketTypeTiming = 1,
    PacketTypeMeter  = 2,
    PacketTypeDanger = 3,
    
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
    NSInteger sampleCount;
} PacketDataTiming;

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
    volatile SInt64    inputID;
    volatile AudioUnit inputUnit;

    volatile SInt64    nextInputID;
    volatile AudioUnit nextInputUnit;

    volatile float     stereoWidth;
    volatile float     stereoBalance;
    volatile float     volume;
    volatile float     preGain;

    volatile UInt64    renderStart;

    volatile UInt64    sampleTime;
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


@implementation HugAudioEngine {
    RenderUserInfo _renderUserInfo;

    TrackScheduler *_currentScheduler;

    AudioUnit _inputAudioUnit;
    AudioUnit _converterAudioUnit;
    AudioUnit _outputAudioUnit;

    HugSimpleGraph *_graph;
    AURenderPullInputBlock _graphRenderBlock;

    double       _outputSampleRate;
    UInt32       _outputFrames;

    HugLimiter      *_emergencyLimiter;
    HugStereoField  *_stereoField;
    HugLevelMeter   *_leftLevelMeter;
    HugLevelMeter   *_rightLevelMeter;
    HugLinearRamper *_preGainRamper;
    HugLinearRamper *_volumeRamper;

    HugRingBuffer   *_errorRingBuffer;
    HugRingBuffer   *_statusRingBuffer;

    HugMeterData    *_leftMeterData;
    HugMeterData    *_rightMeterData;
    float            _dangerLevel;
    NSTimeInterval   _lastOverloadTime;

    NSArray<AUAudioUnit *> *_effectAudioUnits;
}


- (void) uninitializeAll
{
    [self _iterateGraphAudioUnits:^(AudioUnit unit, NSString *unitString) {
        CheckError(AudioUnitUninitialize(unit), "AudioUnitUninitialize");
    }];
    
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

    CheckError( AudioComponentInstanceNew(outputComponent, &_outputAudioUnit), "AudioComponentInstanceNew[ Output ]" );

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


- (void) from_Player_setupAndStartPlayback_1
{
    [self _sendHeadUnitToRenderThread:NULL];

    [_currentScheduler stopScheduling:_inputAudioUnit];
    _currentScheduler = nil;
}

- (BOOL) from_Player_setupAndStartPlayback_2_withTrack:(Track *)track
{
    return [self _buildGraphHeadAndTrackScheduler_withTrack:track];
}

- (BOOL) from_Player_setupAndStartPlayback_3_withPadding:(NSTimeInterval)padding
{
    HugLog(@"Calling startSchedulingWithAudioUnit. audioUnit=%p, padding=%lf", _inputAudioUnit, padding);

    BOOL didScheldule = [_currentScheduler startSchedulingWithAudioUnit:_inputAudioUnit paddingInSeconds:padding];
    if (!didScheldule) {
        HugLog(@"startSchedulingWithAudioUnit failed: %ld", (long)[_currentScheduler audioFileError]);
        return NO;
    }
    
    return YES;
}


- (void) _sendHeadUnitToRenderThread:(AudioUnit)audioUnit
{
    HugLog(@"Sending %p to render thread", audioUnit);

    if ([self isRunning]) {
        _renderUserInfo.nextInputUnit = audioUnit;
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
                HugLog(@"_sendHeadUnitToRenderThread timed out");
                break;
            }

            usleep(1000);
            loopGuard++;
        }
    } else {
        _renderUserInfo.inputUnit = NULL;
        _renderUserInfo.nextInputUnit = audioUnit;
        sMemoryBarrier();

        sAtomicIncrement64Barrier(&_renderUserInfo.nextInputID);
    }
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

        AudioUnit unit  = userInfo->inputUnit;
        OSStatus result = noErr;
        
        BOOL willChangeUnits = (userInfo->nextInputID != userInfo->inputID);

        float *leftData  = ioData->mNumberBuffers > 0 ? ioData->mBuffers[0].mData : NULL;
        float *rightData = ioData->mNumberBuffers > 1 ? ioData->mBuffers[1].mData : NULL;

        if (!unit) {
            *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
            HugApplySilence(leftData, inNumberFrames);
            HugApplySilence(rightData, inNumberFrames);

        } else {
            AudioTimeStamp timestampToUse = {0};
            timestampToUse.mSampleTime = userInfo->sampleTime;
            timestampToUse.mHostTime   = HugGetCurrentHostTime();
            timestampToUse.mFlags      = kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid;

            result = AudioUnitRender(unit, ioActionFlags, &timestampToUse, 0, inNumberFrames, ioData);

            userInfo->sampleTime += inNumberFrames;

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
            userInfo->inputUnit = userInfo->nextInputUnit;
            
            HugLinearRamperReset(preGainRamper, userInfo->preGain);
            HugLinearRamperReset(volumeRamper,  userInfo->volume);
            HugStereoFieldReset(stereoField, userInfo->stereoBalance, userInfo->stereoWidth);

            userInfo->sampleTime = 0;
            sMemoryBarrier();

            userInfo->inputID = userInfo->nextInputID;
        }

        return result;
    }];
    
    if (_outputSampleRate && _outputFrames) {
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:_outputSampleRate channels:2];
        
        for (AUAudioUnit *unit in _effectAudioUnits) {
            NSError *error = nil;

            if (![unit renderResourcesAllocated]) {
                [unit setMaximumFramesToRender:_outputFrames];

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


- (BOOL) configureWithDeviceID: (AudioDeviceID) deviceID
                    sampleRate: (double) sampleRate
                        frames: (UInt32) inFrames
{
    __block BOOL ok = YES;

    void (^checkError)(OSStatus, NSString *, NSString *) = ^(OSStatus error, NSString *formatString, NSString *unitString) {
        if (ok) {
            const char *errorString = NULL;

            if (error != noErr) {
                errorString = [[NSString stringWithFormat:formatString, unitString] UTF8String];
            }

            if (!CheckError(error, errorString)) {
                ok = NO;
            }
        }
    };

    UInt32 frames = inFrames;
    UInt32 framesSize = sizeof(frames);

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

    checkError(AudioUnitGetProperty(
        _outputAudioUnit,
        kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
        &frames, &framesSize
    ), @"AudioUnitGetProperty[ Output, MaximumFramesPerSlice ]", nil);

    checkError(AudioUnitSetProperty(_outputAudioUnit,
        kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0,
        &renderCallback,
        sizeof(renderCallback)
    ), @"AudioUnitSetProperty[ Output, kAudioDevicePropertyBufferFrameSize]", nil);

    _outputSampleRate = sampleRate;
    _outputFrames = frames;

    HugLog(@"Configuring audio units with %lf sample rate, %ld frame size", sampleRate, (long)framesSize);
    
    [self _iterateGraphAudioUnits:^(AudioUnit unit, NSString *unitString) {
        Float64 inputSampleRate  = sampleRate;
        Float64 outputSampleRate = sampleRate;

        if (unit == _inputAudioUnit) {
            inputSampleRate = 0;

        } else if (unit == _outputAudioUnit) {
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


- (BOOL) _buildGraphHeadAndTrackScheduler_withTrack:(Track *)track
{
    HugLogMethod();

    [self _teardownGraphHead];

    BOOL ok = CheckErrorGroup(^{
        UInt32 (^getPropertyUInt32)(AudioUnit, AudioUnitPropertyID, AudioUnitScope) = ^(AudioUnit unit, AudioUnitPropertyID propertyID, AudioUnitScope scope) {
            UInt32 result = 0;
            UInt32 resultSize = sizeof(result);

            CheckError(
                AudioUnitGetProperty(unit, propertyID, scope, 0, &result, &resultSize),
                "AudioUnitGetProperty UInt32"
            );
            
            return result;
        };

        void (^setPropertyUInt32)(AudioUnit, AudioUnitPropertyID, AudioUnitScope, UInt32) = ^(AudioUnit unit, AudioUnitPropertyID propertyID, AudioUnitScope scope, UInt32 value) {
            CheckError(
                AudioUnitSetProperty(unit, propertyID, scope, 0, &value, sizeof(value)),
                "AudioUnitSetProperty Float64"
            );
        };

        void (^setPropertyFloat64)(AudioUnit, AudioUnitPropertyID, AudioUnitScope, Float64) = ^(AudioUnit unit, AudioUnitPropertyID propertyID, AudioUnitScope scope, Float64 value) {
            CheckError(
                AudioUnitSetProperty(unit, propertyID, scope, 0, &value, sizeof(value)),
                "AudioUnitSetProperty Float64"
            );
        };

        void (^getPropertyStream)(AudioUnit, AudioUnitPropertyID, AudioUnitScope, AudioStreamBasicDescription *) = ^(AudioUnit unit, AudioUnitPropertyID propertyID, AudioUnitScope scope, AudioStreamBasicDescription *value) {
            UInt32 size = sizeof(AudioStreamBasicDescription);

            CheckError(
                AudioUnitGetProperty(unit, propertyID, scope, 0, value, &size),
                "AudioUnitGetProperty Stream"
            );
        };
        
        void (^setPropertyStream)(AudioUnit, AudioUnitPropertyID, AudioUnitScope, AudioStreamBasicDescription *) = ^(AudioUnit unit, AudioUnitPropertyID propertyID, AudioUnitScope scope, AudioStreamBasicDescription *value) {
            AudioUnitSetProperty(unit, propertyID, scope, 0, value, sizeof(*value));

            CheckError(
                AudioUnitSetProperty(unit, propertyID, scope, 0, value, sizeof(*value)),
                "AudioUnitSetProperty Stream"
            );
        };

        _currentScheduler = [[TrackScheduler alloc] initWithTrack:track];
        
        if (![_currentScheduler setup]) {
            HugLog(@"TrackScheduler setup failed: %ld", (long)[_currentScheduler audioFileError]);
            [track setTrackError:(TrackError)[_currentScheduler audioFileError]];
            return;
        }

        UInt32 maxFrames = getPropertyUInt32(_outputAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global);
        UInt32 maxFramesForInput = maxFrames;

        AudioStreamBasicDescription outputFormat;
        getPropertyStream(_outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, &outputFormat);
        
        AudioStreamBasicDescription fileFormat = [_currentScheduler clientFormat];

        AudioStreamBasicDescription inputFormat = outputFormat;
        inputFormat.mSampleRate = fileFormat.mSampleRate;

        AudioUnit inputUnit     = 0;
        AudioUnit converterUnit = NULL;

        if (fileFormat.mSampleRate != _outputSampleRate) {
            AudioComponentDescription converterCD = {0};
            converterCD.componentType = kAudioUnitType_FormatConverter;
            converterCD.componentSubType = kAudioUnitSubType_AUConverter;
            converterCD.componentManufacturer = kAudioUnitManufacturer_Apple;
            converterCD.componentFlags = kAudioComponentFlag_SandboxSafe;

            AudioComponent converterComponent = AudioComponentFindNext(NULL, &converterCD);
            CheckError( AudioComponentInstanceNew(converterComponent, &converterUnit), "AudioComponentInstanceNew[ Converter ]" );

            UInt32 complexity = [[Preferences sharedInstance] usesMasteringComplexitySRC] ?
                kAudioUnitSampleRateConverterComplexity_Mastering :
                kAudioUnitSampleRateConverterComplexity_Normal;

            setPropertyUInt32(converterUnit, kAudioUnitProperty_SampleRateConverterComplexity, kAudioUnitScope_Global, complexity);
            setPropertyUInt32(converterUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, maxFrames);

            setPropertyFloat64(converterUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Input,  inputFormat.mSampleRate);
            setPropertyFloat64(converterUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, _outputSampleRate);

            AudioStreamBasicDescription unitFormat = inputFormat;
            unitFormat.mSampleRate = _outputSampleRate;

            setPropertyStream(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,  &inputFormat);
            setPropertyStream(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, &unitFormat);

            CheckError(AudioUnitInitialize(converterUnit), "AudioUnitInitialize[ Converter ]");

            // maxFrames will be different when going through a SRC
            maxFramesForInput = getPropertyUInt32(converterUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global);

            _converterAudioUnit = converterUnit;
        }

        // Make input node
        {
            AudioComponentDescription inputCD = {0};
            inputCD.componentType = kAudioUnitType_Mixer;
            inputCD.componentSubType = kAudioUnitSubType_StereoMixer;
            inputCD.componentManufacturer = kAudioUnitManufacturer_Apple;
            inputCD.componentFlags = kAudioComponentFlag_SandboxSafe;

            AudioComponent inputComponent = AudioComponentFindNext(NULL, &inputCD);
            CheckError( AudioComponentInstanceNew(inputComponent, &inputUnit), "AudioComponentInstanceNew[ Input ]" );

            setPropertyUInt32( inputUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, maxFramesForInput);

            setPropertyStream(inputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,  &fileFormat);
            setPropertyStream(inputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, &inputFormat);
            
            CheckError(AudioUnitInitialize(inputUnit), "AudioUnitInitialize[ Input ]");

            _inputAudioUnit = inputUnit;
        }

        if (_converterAudioUnit) {
            AudioUnitConnection connection = { _inputAudioUnit, 0, 0 };
   
            CheckError(
                AudioUnitSetProperty(_converterAudioUnit, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input, 0, &connection, sizeof(connection)),
                "kAudioUnitProperty_MakeConnection"
            );
        }   

        [self _sendHeadUnitToRenderThread:(converterUnit ? converterUnit : inputUnit)];
    });
    
    if (ok) {
        [self reconnectGraph];
    }

    return ok;
}


- (void) _iterateGraphAudioUnits:(void (^)(AudioUnit, NSString *))callback
{
    if (_inputAudioUnit)     callback(_inputAudioUnit,     @"Input");
    if (_converterAudioUnit) callback(_converterAudioUnit, @"Converter");
    
    callback(_outputAudioUnit, @"Output");
}


- (void) _teardownGraphHead
{
    HugLogMethod();

    if (_inputAudioUnit) {
        CheckError(AudioUnitUninitialize(_inputAudioUnit), "AudioUnitUninitialize[ Input ]");
        CheckError(AudioComponentInstanceDispose(_inputAudioUnit), "AudioComponentInstanceDispose[ Input ]");

        _inputAudioUnit = NULL;
    }

    if (_converterAudioUnit) {
        CheckError(AudioUnitUninitialize(_converterAudioUnit), "AudioUnitUninitialize[ Converter ]");
        CheckError(AudioComponentInstanceDispose(_converterAudioUnit), "AudioComponentInstanceDispose[ Converter ]");

        _converterAudioUnit = NULL;
    }
}


#pragma mark - Update Methods

- (void) _reallyStop
{
    CheckError(AudioOutputUnitStop(_outputAudioUnit), "AudioOutputUnitStop");
}


- (void) start
{
    HugLogMethod();

    if (![self isRunning]) {
        CheckError(AudioOutputUnitStart(_outputAudioUnit), "AudioOutputUnitStart");
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reallyStop) object:nil];
}


- (void) stop
{
    if ([self isRunning]) {
        [self _sendHeadUnitToRenderThread:NULL];
        [self performSelector:@selector(_reallyStop) withObject:nil afterDelay:30];
    }
    
    for (AUAudioUnit *unit in _effectAudioUnits) {
        [unit reset];
    }

    [_currentScheduler stopScheduling:_inputAudioUnit];
    _currentScheduler = nil;
    
    [self _teardownGraphHead];
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

- (TrackScheduler *) scheduler
{
    return _currentScheduler;
}


- (BOOL) isRunning
{
    if (!_outputAudioUnit) return NO;

    Boolean isRunning = false;
    UInt32 size = sizeof(isRunning);
    CheckError(AudioUnitGetProperty( _outputAudioUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &isRunning, &size ), "sIsOutputUnitRunning");
    
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
        
        if (unknown->type == PacketTypeTiming) {
            PacketDataTiming packet;
            if (!HugRingBufferRead(_statusRingBuffer, &packet, sizeof(PacketDataTiming))) return;

        } else if (unknown->type == PacketTypeMeter) {
            PacketDataMeter packet;
            if (!HugRingBufferRead(_statusRingBuffer, &packet, sizeof(PacketDataMeter))) return;
            
            _leftMeterData  = [[HugMeterData alloc] initWithStruct:packet.leftMeterData];
            _rightMeterData = [[HugMeterData alloc] initWithStruct:packet.rightMeterData];

        } else if (unknown->type == PacketTypeDanger) {
            PacketDataDanger packet;
            if (!HugRingBufferRead(_statusRingBuffer, &packet, sizeof(PacketDataDanger))) return;
            
            uint64_t renderTime = packet.renderTime;
            
            double callbackDuration = packet.frameCount / _outputSampleRate;
            double elapsedDuration  = HugGetSecondsWithHostTime(renderTime);
            
            _dangerLevel = elapsedDuration / callbackDuration;

        } else {
            NSAssert(NO, @"Unknown packet type");
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

            HugLog(@"kAudioDeviceProcessorOverload detected");
           
        } else if (unknown->type == PacketTypeStatusBufferFull) {
            PacketDataUnknown packet;
            if (!HugRingBufferRead(_errorRingBuffer, &packet, sizeof(PacketDataUnknown))) return;

            HugLog(@"_statusRingBuffer is full");
            
        } else if (unknown->type == PacketTypeErrorMessage) {
        
        }
    }
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
