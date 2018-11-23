//
//  AudioGraph.m
//  Embrace
//
//  Created by Ricci Adams on 2018-11-21.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "AudioGraph.h"

#import "EmergencyLimiter.h"
#import "StereoField.h"
#import "FastUtils.h"
#import "TrackScheduler.h"
#import "MTSEscapePod.h"
#import "Preferences.h"

//!graph: Awkward
#import "Player.h"
#import "Effect.h"
#import "EffectType.h"


@interface Effect ()
- (void) _setAudioUnit:(AudioUnit)unit error:(OSStatus)error;
@end


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


static OSStatus sApplyEmergencyLimiter(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData
) {
    MTSEscapePodSetIgnoredThread(mach_thread_self());

    EmergencyLimiter *limiter = (EmergencyLimiter *)inRefCon;
    
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
        EmergencyLimiterProcess(limiter, inNumberFrames, ioData);
    }
    
    return noErr;
}

typedef struct {
    volatile SInt64    inputID;
    volatile AudioUnit inputUnit;

    volatile SInt64    nextInputID;
    volatile AudioUnit nextInputUnit;

    volatile float     stereoLevel;
    volatile float     previousStereoLevel;

    volatile UInt64    sampleTime;
    
    // Worker Thread -> Main Thread
    volatile SInt32    overloadCount;
    volatile SInt32    nextOverloadCount;
} RenderUserInfo;


static OSStatus sInputRenderCallback(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData)
{
    RenderUserInfo *userInfo = (RenderUserInfo *)inRefCon;
    
    AudioUnit unit  = userInfo->inputUnit;
    OSStatus result = noErr;
    
    BOOL willChangeUnits = (userInfo->nextInputID != userInfo->inputID);

    if (!unit) {
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
        ApplySilenceToAudioBuffer(inNumberFrames, ioData);

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

        // Process stereo field
        {
            BOOL canSkipStereoField = (userInfo->previousStereoLevel) == 1.0 && (userInfo->stereoLevel == 1.0);

            if (!canSkipStereoField) {
                ApplyStereoField(inNumberFrames, ioData, userInfo->previousStereoLevel, userInfo->stereoLevel);
                userInfo->previousStereoLevel = userInfo->stereoLevel;
            }
        }

        if (willChangeUnits) {
            ApplyFadeToAudioBuffer(inNumberFrames, ioData, 1.0, 0.0);
        }
    }

    if (willChangeUnits) {
        userInfo->inputUnit = userInfo->nextInputUnit;
        userInfo->previousStereoLevel = userInfo->stereoLevel;
        userInfo->sampleTime = 0;
        sMemoryBarrier();

        userInfo->inputID = userInfo->nextInputID;
    }

    return result;
}


@implementation AudioGraph {
    RenderUserInfo _renderUserInfo;

    TrackScheduler *_currentScheduler;

    AudioUnit _inputAudioUnit;
    AudioUnit _converterAudioUnit;
    AudioUnit _limiterAudioUnit;
    AudioUnit _mixerAudioUnit;
    AudioUnit _outputAudioUnit;

    double       _outputSampleRate;
    UInt32       _outputFrames;

    EmergencyLimiter *_emergencyLimiter;

    NSArray<Effect *> *_effects;
    NSMutableDictionary *_effectToAudioUnitMap;

    NSInteger    _reconnectGraph_failureCount;


}


- (void) uninitializeAll
{
    [self _iterateGraphAudioUnits:^(AudioUnit unit, NSString *unitString) {
        CheckError(AudioUnitUninitialize(unit), "AudioUnitUninitialize");
    }];

}
- (void) buildTail
{
    EmbraceLogMethod();

    AudioComponentDescription limiterCD = { 0};
    limiterCD.componentType = kAudioUnitType_Effect;
    limiterCD.componentSubType = kAudioUnitSubType_PeakLimiter;
    limiterCD.componentManufacturer = kAudioUnitManufacturer_Apple;
    limiterCD.componentFlags = kAudioComponentFlag_SandboxSafe;

    AudioComponentDescription mixerCD = {0};
    mixerCD.componentType = kAudioUnitType_Mixer;
    mixerCD.componentSubType = kAudioUnitSubType_StereoMixer;
    mixerCD.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerCD.componentFlags = kAudioComponentFlag_SandboxSafe;

    AudioComponentDescription outputCD = {0};
    outputCD.componentType = kAudioUnitType_Output;
    outputCD.componentSubType = kAudioUnitSubType_HALOutput;
    outputCD.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputCD.componentFlags = kAudioComponentFlag_SandboxSafe;

    AudioComponent limiterComponent = AudioComponentFindNext(NULL, &limiterCD);
    AudioComponent mixerComponent   = AudioComponentFindNext(NULL, &mixerCD);
    AudioComponent outputComponent  = AudioComponentFindNext(NULL, &outputCD);

    CheckError( AudioComponentInstanceNew(limiterComponent, &_limiterAudioUnit), "AudioComponentInstanceNew[ Limiter ]" );
    CheckError( AudioComponentInstanceNew(mixerComponent,   &_mixerAudioUnit),   "AudioComponentInstanceNew[ Mixer ]" );
    CheckError( AudioComponentInstanceNew(outputComponent,  &_outputAudioUnit),  "AudioComponentInstanceNew[ Output ]" );

    UInt32 on = 1;
    CheckError(AudioUnitSetProperty(_mixerAudioUnit,
        kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0,
        &on,
        sizeof(on)
    ), "AudioUnitSetProperty[kAudioUnitProperty_MeteringMode]");

    [self updateVolume:0];
    [self updateStereoBalance:0];

    _emergencyLimiter = EmergencyLimiterCreate();




//!graph:
//    AUGraphAddRenderNotify(_graph, sApplyEmergencyLimiter, _emergencyLimiter);
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





- (void) _reconnectGraph_attempt
{
    BOOL (^doReconnect)() = ^{
        __block AudioUnit lastUnit = NULL;
        __block NSInteger index = 0;
        __block BOOL didConnectAll = YES;

        AURenderCallbackStruct headRenderCallback = { &sInputRenderCallback, &_renderUserInfo };
        UInt32 callbackSize = sizeof(headRenderCallback);

        if (!CheckError(
            AudioUnitSetProperty(_limiterAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &headRenderCallback, callbackSize),
            "AUGraphSetNodeInputCallback"
        )) {
            return NO;
        }
        
        [self _iterateGraphAudioUnits:^(AudioUnit unit, NSString *unitString) {
            if (lastUnit && (unit != _limiterAudioUnit)) {
                AudioUnitConnection connection = { lastUnit, 0, 0 };

                if (!CheckError(
                    AudioUnitSetProperty(unit, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input, 0, &connection, sizeof(connection)),
                    "AUGraphConnectNodeInput"
                )) {
                    didConnectAll = NO;
                }
            }

            lastUnit = unit;
            index++;
        }];

        [self _iterateGraphAudioUnits:^(AudioUnit unit, NSString *unitString) {
            AudioUnitInitialize(unit);
        }];

        if (!didConnectAll) {
            return NO;
        }
                
        return YES;
    };
    
    if (!doReconnect()) {
        _reconnectGraph_failureCount++;
        
        if (_reconnectGraph_failureCount > 200) {
            EmbraceLog(@"Player", @"doReconnect() still failing after 1 second.  Stopping.");
            //!graph: Awkward
            [[Player sharedInstance] hardStop];
        }

        EmbraceLog(@"Player", @"doReconnect() failed, calling again in 5ms");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [self _reconnectGraph_attempt];
        });
    }
}


- (void) reconnectGraph
{
    EmbraceLogMethod();

    _reconnectGraph_failureCount = 0;
    [self _reconnectGraph_attempt];
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

    _outputSampleRate = sampleRate;
    _outputFrames = framesSize;

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

    EmergencyLimiterSetSampleRate(_emergencyLimiter, sampleRate);

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
    callback(_limiterAudioUnit, @"Limiter");
    
    for (Effect *effect in _effects) {
        NSValue  *key       = [NSValue valueWithNonretainedObject:effect];
        NSValue  *unitValue = [_effectToAudioUnitMap objectForKey:key];

        if (!unitValue) continue;
        callback([unitValue pointerValue], [[effect type] name]);
    }

    callback(_mixerAudioUnit,  @"Mixer");
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

    [self _iterateGraphAudioUnits:^(AudioUnit unit, NSString *unitString) {
        OSStatus err = AudioUnitReset(unit, kAudioUnitScope_Global, 0);
        
        if (err != noErr) {
            CheckError(err, [[NSString stringWithFormat:@"%@, AudioUnitReset", unitString] UTF8String]);
        }
    }];

    [_currentScheduler stopScheduling:_inputAudioUnit];
    _currentScheduler = nil;
    
    [self _teardownGraphHead];
}


- (void) updateStereoLevel:(float)stereoLevel
{
    _renderUserInfo.stereoLevel = stereoLevel;
}


- (void) updateStereoBalance:(float)stereoBalance
{
    Float32 value = stereoBalance;

    CheckError(AudioUnitSetParameter(_mixerAudioUnit,
        kStereoMixerParam_Pan, kAudioUnitScope_Input, 0,
        value, 0
    ), "AudioUnitSetParameter[Volume]");
}


- (void) updatePreGain:(float)preGain
{
    AudioUnitParameter parameter = {
        _limiterAudioUnit,
        kLimiterParam_PreGain,
        kAudioUnitScope_Global,
        0
    };
    
    CheckError(AUParameterSet(NULL, NULL, &parameter, preGain, 0), "AUParameterSet");
}


- (void) updateVolume:(float)volume
{
    CheckError(AudioUnitSetParameter(_mixerAudioUnit,
        kStereoMixerParam_Volume, kAudioUnitScope_Output, 0,
        volume, 0
    ), "AudioUnitSetParameter[Volume]");
}


- (void) updateEffects:(NSArray<Effect *> *)effects
{
    _effects = effects;

    NSMutableDictionary *effectToAudioUnitMap = [NSMutableDictionary dictionary];

    for (Effect *effect in effects) {
        NSValue *key = [NSValue valueWithNonretainedObject:effect];
        AudioUnit audioUnit = NULL;

        OSStatus err = noErr;

        NSValue *unitValue = [_effectToAudioUnitMap objectForKey:key];
        if (unitValue) {
            audioUnit = [unitValue pointerValue];

        } else {
            AudioComponentDescription acd = [[effect type] AudioComponentDescription];

            AudioComponent component = AudioComponentFindNext(NULL, &acd);
            
            if (!component) {
                [effect _setAudioUnit:NULL error:err];
                continue;
            }

            UInt32 maxFrames;
            UInt32 maxFramesSize = sizeof(maxFrames);
            
            err = AudioUnitGetProperty(
                _outputAudioUnit,
                kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                &maxFrames, &maxFramesSize
            );
            
            if (err != noErr) {
                [effect _setAudioUnit:NULL error:err];
                continue;
            }

            err = AudioComponentInstanceNew(component, &audioUnit);
            
            if (err != noErr) {
                [effect _setAudioUnit:NULL error:err];
                continue;
            }

            err = AudioUnitSetProperty(
                audioUnit,
                kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                &maxFrames, maxFramesSize
            );
            
            if (err != noErr) {
                [effect _setAudioUnit:NULL error:err];
                continue;
            }
        }
        
        AudioUnitParameter changedUnit;
        changedUnit.mAudioUnit = audioUnit;
        changedUnit.mParameterID = kAUParameterListener_AnyParameter;
        AUParameterListenerNotify(NULL, NULL, &changedUnit);

        [effect _setAudioUnit:audioUnit error:noErr];

        [effectToAudioUnitMap setObject:[NSValue valueWithPointer:audioUnit] forKey:key];
    }


    for (NSValue *key in _effectToAudioUnitMap) {
        if (![effectToAudioUnitMap objectForKey:key]) {
            AudioUnit unit = [[_effectToAudioUnitMap objectForKey:key] pointerValue];
            AudioComponentInstanceDispose(unit);
        }
    }

    _effectToAudioUnitMap = effectToAudioUnitMap;

    [self reconnectGraph];
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


- (float) leftAveragePower
{
    AudioUnitParameterValue value = 0;
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostAveragePower, kAudioUnitScope_Output, 0, &value);
    return value;
}


- (float) rightAveragePower
{
    AudioUnitParameterValue value = 0;
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostAveragePower + 1, kAudioUnitScope_Output, 0, &value);
    return value;
}


- (float) leftPeakPower
{
    AudioUnitParameterValue value = 0;
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostPeakHoldLevel, kAudioUnitScope_Output, 0, &value);
    return value;
}


- (float) rightPeakPower
{
    AudioUnitParameterValue value = 0;
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostPeakHoldLevel + 1, kAudioUnitScope_Output, 0, &value);
    return value;
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

- (BOOL) isLimiterActive
{
    return EmergencyLimiterIsActive(_emergencyLimiter);
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



    
#if CHECK_RENDER_ERRORS_ON_TICK
    if (_converterAudioUnit) {
        OSStatus renderError;
        UInt32 renderErrorSize = sizeof(renderError);

        AudioUnitGetProperty(_converterAudioUnit, kAudioUnitProperty_LastRenderError, kAudioUnitScope_Global, 0, &renderError, &renderErrorSize);
        NSLog(@"%ld", (long)renderError);
    }
#endif


@end
