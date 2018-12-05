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
#import "TrackScheduler.h"
#import "MTSEscapePod.h"
#import "HugLevelMeter.h"
#import "Preferences.h"
#import "HugMeterData.h"
#import "HugSimpleGraph.h"

//!graph: Awkward
#import "Player.h"

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


typedef struct {
    volatile SInt64    inputID;
    volatile AudioUnit inputUnit;

    volatile SInt64    nextInputID;
    volatile AudioUnit nextInputUnit;

    volatile float     stereoWidth;
    volatile float     stereoBalance;
    volatile float     volume;
    volatile float     preGain;

    volatile UInt64    sampleTime;
    
    volatile AURenderPullInputBlock outputPullBlock;
    
    // Worker Thread -> Main Thread
    volatile SInt32    overloadCount;
    volatile SInt32    nextOverloadCount;
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
    EmbraceLogMethod();

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
    EmbraceLog(@"Player", @"Calling startSchedulingWithAudioUnit. audioUnit=%p, padding=%lf", _inputAudioUnit, padding);

    BOOL didScheldule = [_currentScheduler startSchedulingWithAudioUnit:_inputAudioUnit paddingInSeconds:padding];
    if (!didScheldule) {
        EmbraceLog(@"Player", @"startSchedulingWithAudioUnit failed: %ld", (long)[_currentScheduler audioFileError]);
        return NO;
    }
    
    return YES;
}


- (void) _sendHeadUnitToRenderThread:(AudioUnit)audioUnit
{
    EmbraceLog(@"Player", @"Sending %p to render thread", audioUnit);

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
                EmbraceLog(@"Player", @"_sendHeadUnitToRenderThread timed out");
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
    EmbraceLogMethod();

    HugLimiter      *limiter         = _emergencyLimiter;
    HugStereoField  *stereoField     = _stereoField;
    HugLevelMeter   *leftLevelMeter  = _leftLevelMeter;
    HugLevelMeter   *rightLevelMeter = _rightLevelMeter;
    HugLinearRamper *preGainRamper   = _preGainRamper;
    HugLinearRamper *volumeRamper    = _volumeRamper;

    RenderUserInfo *userInfo = &_renderUserInfo;

    HugSimpleGraph *graph = [[HugSimpleGraph alloc] init];
    
    [graph addBlock:^(
        AudioUnitRenderActionFlags *ioActionFlags,
        const AudioTimeStamp *timestamp,
        AUAudioFrameCount inNumberFrames,
        NSInteger inputBusNumber,
        AudioBufferList *ioData
    ) {
        AudioUnit unit  = userInfo->inputUnit;
        OSStatus result = noErr;
        
        BOOL willChangeUnits = (userInfo->nextInputID != userInfo->inputID);

        if (!unit) {
            *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
            HugApplySilenceToAudioBuffer(inNumberFrames, ioData);

        } else {
            AudioTimeStamp timestampToUse = {0};
            timestampToUse.mSampleTime = userInfo->sampleTime;
            timestampToUse.mHostTime   = GetCurrentHostTime();
            timestampToUse.mFlags      = kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid;

            result = AudioUnitRender(unit, ioActionFlags, &timestampToUse, 0, inNumberFrames, ioData);

            userInfo->sampleTime += inNumberFrames;

    //        if (rand() % 100 == 0) {
    //            usleep(50000);
    //        }

            HugStereoFieldProcess(stereoField, ioData, userInfo->stereoBalance, userInfo->stereoWidth);
            HugLinearRamperProcess(preGainRamper, ioData, userInfo->preGain);

            if (willChangeUnits) {
                HugApplyFadeToAudioBuffer(inNumberFrames, ioData, 1.0, 0.0);
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
        MTSEscapePodSetIgnoredThread(mach_thread_self());

        float volume = userInfo->volume;
        HugLinearRamperProcess(volumeRamper, ioData, volume);

        if (ioData->mNumberBuffers > 0) {
            HugLevelMeterProcess(leftLevelMeter, ioData->mBuffers[0].mData);
        }

        if (ioData->mNumberBuffers > 1) {
            HugLevelMeterProcess(rightLevelMeter, ioData->mBuffers[1].mData);
        }
    
        HugLimiterProcess(limiter, inNumberFrames, ioData);
        
        return noErr;
    }];

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

    EmbraceLog(@"Player", @"Configuring audio units with %lf sample rate, %ld frame size", sampleRate, (long)framesSize);
    
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

    HugLimiterSetSampleRate(_emergencyLimiter, sampleRate);

    HugLevelMeterSetSampleRate(_leftLevelMeter, sampleRate);
    HugLevelMeterSetSampleRate(_rightLevelMeter, sampleRate);

    HugLinearRamperSetFrameCount(_preGainRamper, frames);
    HugStereoFieldSetFrameCount(_stereoField, frames);
    HugLevelMeterSetFrameCount(_leftLevelMeter, frames);
    HugLevelMeterSetFrameCount(_rightLevelMeter, frames);
    HugLinearRamperSetFrameCount(_volumeRamper, frames);

    return ok;
}


- (BOOL) _buildGraphHeadAndTrackScheduler_withTrack:(Track *)track
{
    EmbraceLogMethod();

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
            EmbraceLog(@"Player", @"TrackScheduler setup failed: %ld", (long)[_currentScheduler audioFileError]);
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
    EmbraceLogMethod();

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
    EmbraceLogMethod();

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


- (HugMeterData *) leftMeterData
{
    HugMeterDataStruct s = {0};

    s.peakLevel = HugLevelMeterGetPeakLevel(_leftLevelMeter);
    s.heldLevel = HugLevelMeterGetHeldLevel(_leftLevelMeter);
    s.limiterActive = HugLimiterIsActive(_emergencyLimiter);
    
    return [[HugMeterData alloc] initWithStruct:s];
}


- (HugMeterData *) rightMeterData
{
    HugMeterDataStruct s = {0};

    s.peakLevel = HugLevelMeterGetPeakLevel(_rightLevelMeter);
    s.heldLevel = HugLevelMeterGetHeldLevel(_rightLevelMeter);
    s.limiterActive = HugLimiterIsActive(_emergencyLimiter);
    
    return [[HugMeterData alloc] initWithStruct:s];
}



- (float) dangerPeak
{
//!graph: Re-add this
//    AUGraphGetCPULoad(_graph, &_dangerAverage);
//    
//    Float32 dangerPeak = 0;
//    AUGraphGetMaxCPULoad(_graph, &_dangerPeak);
//
//    if (dangerPeak) {
//        _dangerPeak = dangerPeak;
//    } else if (_dangerAverage == 0) {
//        _dangerPeak = 0;
//    }

    return 0;
}


- (BOOL) didOverload
{
    BOOL result = NO;

    if (_renderUserInfo.nextOverloadCount != _renderUserInfo.overloadCount) {
        _renderUserInfo.overloadCount = _renderUserInfo.nextOverloadCount;
        result = YES;
    }

    return result;
}


@end
