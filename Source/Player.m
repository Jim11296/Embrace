//
//  player.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Player.h"
#import "Track.h"
#import "Effect.h"
#import "AppDelegate.h"
#import "EffectType.h"
#import "AudioDevice.h"
#import "Preferences.h"
#import "WrappedAudioDevice.h"
#import "TrackScheduler.h"
#import "EmergencyLimiter.h"

#import <pthread.h>
#import <signal.h>
#import <Accelerate/Accelerate.h>
#import <PLCrashLogWriter.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

#define CHECK_RENDER_ERRORS_ON_TICK 0

static NSString * const sEffectsKey       = @"effects";
static NSString * const sPreAmpKey        = @"pre-amp";
static NSString * const sMatchLoudnessKey = @"match-loudness";
static NSString * const sVolumeKey        = @"volume";

static double sMaxVolume = 1.0 - (2.0 / 32767.0);

volatile NSInteger PlayerShouldUseCrashPad = 0;


static OSStatus sApplyEmergencyLimiter(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData
) {
    CrashLogWriterSetIgnoredThread(mach_thread_self());

    EmergencyLimiter *limiter = (EmergencyLimiter *)inRefCon;
    
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
        EmergencyLimiterProcess(limiter, inNumberFrames, ioData);
    }
    
    return noErr;
}


@interface Effect ()
- (void) _setAudioUnit:(AudioUnit)unit error:(OSStatus)error;
@end


@interface Player ()
@property (nonatomic, strong) Track *currentTrack;
@property (nonatomic) NSString *timeElapsedString;
@property (nonatomic) NSString *timeRemainingString;
@property (nonatomic) float percentage;
@property (nonatomic) PlayerIssue issue;
@end


typedef struct {
    volatile AudioUnit inputUnit;
    volatile NSInteger stopRequested;
    volatile NSInteger stopped;
} RenderUserInfo;

@implementation Player {
    Track         *_currentTrack;
    NSTimeInterval _currentPadding;

    TrackScheduler *_currentScheduler;

    RenderUserInfo _renderUserInfo;

    UInt64    _currentStartHostTime;

    AUGraph   _graph;

	AUNode    _generatorNode;
    AUNode    _converterNode;
	AUNode    _limiterNode;
    AUNode    _mixerNode;
	AUNode    _outputNode;

    AudioUnit _generatorAudioUnit;
    AudioUnit _converterAudioUnit;
    AudioUnit _limiterAudioUnit;
    AudioUnit _mixerAudioUnit;
    AudioUnit _outputAudioUnit;
    
    EmergencyLimiter *_emergencyLimiter;
    
    AudioDevice *_outputDevice;
    double       _outputSampleRate;
    UInt32       _outputFrames;
    BOOL         _outputHogMode;

    BOOL         _tookHogMode;
    BOOL         _hadErrorDuringReconfigure;

    IOPMAssertionID _powerAssertionID;
    
    NSMutableDictionary *_effectToNodeMap;
    NSHashTable *_listeners;
    
    NSTimer *_tickTimer;

    NSTimeInterval _roundedTimeElapsed;
    NSTimeInterval _roundedTimeRemaining;
    
    AUParameterListenerRef _parameterListener;
}


+ (id) sharedInstance
{
    static Player *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[Player alloc] init];
    });

    return sSharedInstance;
}


+ (NSSet *) keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    NSArray *affectingKeys = nil;
 
    if ([key isEqualToString:@"playing"]) {
        affectingKeys = @[ @"currentTrack" ];
    }

    if (affectingKeys) {
        keyPaths = [keyPaths setByAddingObjectsFromArray:affectingKeys];
    }
 
    return keyPaths;
}


- (id) init
{
    if ((self = [super init])) {
        _volume = -1;

        [self _buildTailGraph];
        [self _loadState];
        [self _reconnectGraph];
    }
    
    return self;
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _outputDevice) {
        if ([keyPath isEqualToString:@"connected"]) {
            [self _checkIssues];
            
            if (![_outputDevice isConnected]) {
                [self hardStop];
            }
        }
    }
}


#pragma mark - Private Methods

- (void) _loadState
{
    NSMutableArray *effects = [NSMutableArray array];

    NSArray *states = [[NSUserDefaults standardUserDefaults] objectForKey:sEffectsKey];
    if ([states isKindOfClass:[NSArray class]]) {
        for (NSDictionary *state in states) {
            Effect *effect = [Effect effectWithStateDictionary:state];
            if (effect) [effects addObject:effect];
        }
    }

    NSNumber *matchLoudnessNumber = [[NSUserDefaults standardUserDefaults] objectForKey:sMatchLoudnessKey];
    if ([matchLoudnessNumber isKindOfClass:[NSNumber class]]) {
        [self setMatchLoudnessLevel:[matchLoudnessNumber doubleValue]];
    } else {
        [self setMatchLoudnessLevel:0];
    }

    NSNumber *preAmpNumber = [[NSUserDefaults standardUserDefaults] objectForKey:sPreAmpKey];
    if ([preAmpNumber isKindOfClass:[NSNumber class]]) {
        [self setPreAmpLevel:[preAmpNumber doubleValue]];
    } else {
        [self setPreAmpLevel:0];
    }
    
    [self setEffects:effects];

    NSNumber *volume = [[NSUserDefaults standardUserDefaults] objectForKey:sVolumeKey];
    if (!volume) volume = @0.96;
    [self setVolume:[volume doubleValue]];
}


- (void) _updateEffects:(NSArray *)effects
{
    NSMutableDictionary *effectToNodeMap = [NSMutableDictionary dictionary];

    for (Effect *effect in effects) {
        NSValue *key = [NSValue valueWithNonretainedObject:effect];
        AUNode node = 0;

        OSStatus err = noErr;

        AudioComponentDescription acd = [[effect type] AudioComponentDescription];

        NSNumber *nodeNumber = [_effectToNodeMap objectForKey:key];
        if (nodeNumber) {
            node = [nodeNumber intValue];

        } else {
            err = AUGraphAddNode(_graph, &acd, &node);
            
            if (err != noErr) {
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

            AudioComponentDescription unused;
            AudioUnit unit = NULL;

            err = AUGraphNodeInfo(_graph, node, &unused, &unit);
            
            if (err != noErr) {
                [effect _setAudioUnit:NULL error:err];
                continue;
            }

            err = AudioUnitSetProperty(
                unit,
                kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                &maxFrames, maxFramesSize
            );
            
            if (err != noErr) {
                [effect _setAudioUnit:NULL error:err];
                continue;
            }
        }
        
        AudioUnit audioUnit;
        err = AUGraphNodeInfo(_graph, node, &acd, &audioUnit);

        if (err != noErr) {
            [effect _setAudioUnit:NULL error:err];
            continue;
        }
        
        AudioUnitParameter changedUnit;
        changedUnit.mAudioUnit = audioUnit;
        changedUnit.mParameterID = kAUParameterListener_AnyParameter;
        AUParameterListenerNotify(NULL, NULL, &changedUnit);

        [effect _setAudioUnit:audioUnit error:noErr];

        [effectToNodeMap setObject:@(node) forKey:key];
    }


    for (NSValue *key in _effectToNodeMap) {
        if (![effectToNodeMap objectForKey:key]) {
            AUNode node = [[_effectToNodeMap objectForKey:key] intValue];
            AUGraphRemoveNode(_graph, node);
        }
    }

    _effectToNodeMap = effectToNodeMap;

    [self _reconnectGraph];
}


- (void) _tick:(NSTimer *)timer
{
    AudioTimeStamp timeStamp = {0};
    UInt32 timeStampSize = sizeof(timeStamp);

    TrackStatus status = TrackStatusPlaying;

    AudioUnitGetProperty(_generatorAudioUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, &timeStamp, &timeStampSize);
    Float64 currentPlayTime = timeStamp.mSampleTime;
    BOOL done = NO;
    
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostAveragePower,      kAudioUnitScope_Output, 0, &_leftAveragePower);
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostAveragePower + 1,  kAudioUnitScope_Output, 0, &_rightAveragePower);
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostPeakHoldLevel,     kAudioUnitScope_Output, 0, &_leftPeakPower);
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostPeakHoldLevel + 1, kAudioUnitScope_Output, 0, &_rightPeakPower);

    _limiterActive = EmergencyLimiterIsActive(_emergencyLimiter);
    
#if CHECK_RENDER_ERRORS_ON_TICK
    if (_converterAudioUnit) {
        OSStatus renderError;
        UInt32 renderErrorSize = sizeof(renderError);

        AudioUnitGetProperty(_converterAudioUnit, kAudioUnitProperty_LastRenderError, kAudioUnitScope_Global, 0, &renderError, &renderErrorSize);
        NSLog(@"%ld", (long)renderError);

        AudioUnitGetProperty(_generatorAudioUnit, kAudioUnitProperty_LastRenderError, kAudioUnitScope_Global, 0, &renderError, &renderErrorSize);
        NSLog(@"%ld", (long)renderError);

    }
#endif

    _timeElapsed = 0;

    NSTimeInterval roundedTimeElapsed;
    NSTimeInterval roundedTimeRemaining;

    if (timeStamp.mSampleTime < 0) {
        _timeElapsed   = GetDeltaInSecondsForHostTimes(GetCurrentHostTime(), _currentStartHostTime);
        _timeRemaining = [_currentTrack playDuration];
        
        roundedTimeElapsed = floor(_timeElapsed);
        roundedTimeRemaining = round([_currentTrack playDuration]);

    } else {
        Float64 sampleRate = [_currentScheduler clientFormat].mSampleRate;
        
        _timeElapsed = sampleRate ? currentPlayTime / sampleRate : 0;
        _timeRemaining = [_currentTrack playDuration] - _timeElapsed;
        
        roundedTimeElapsed = floor(_timeElapsed);
        roundedTimeRemaining = round([_currentTrack playDuration]) - roundedTimeElapsed;
    }

    if (_timeRemaining < 0 || [_currentTrack trackError]) {
        done = YES;

        status = TrackStatusPlayed;
        _timeElapsed = [_currentTrack playDuration];
        _timeRemaining = 0;
        
        roundedTimeElapsed = round([_currentTrack playDuration]);
        roundedTimeRemaining = 0;
    }
    
    if (!_timeElapsedString || (roundedTimeElapsed != _roundedTimeElapsed)) {
        _roundedTimeElapsed = roundedTimeElapsed;
        [self setTimeElapsedString:GetStringForTime(_roundedTimeElapsed)];
    }

    if (!_timeRemainingString || (roundedTimeRemaining != _roundedTimeRemaining)) {
        _roundedTimeRemaining = roundedTimeRemaining;
        [self setTimeRemainingString:GetStringForTime(_roundedTimeRemaining)];
    }

    // Waiting for analysis
    if (![_currentTrack didAnalyzeLoudness]) {
        [self setTimeElapsedString:@""];
    }


    NSTimeInterval duration = _timeElapsed + _timeRemaining;
    if (!duration) duration = 1;
    
    double percentage = 0;
    if (_timeElapsed > 0) {
        percentage = _timeElapsed / duration;
    }

    [self setPercentage:percentage];

    [_currentTrack setTrackStatus: status];

    for (id<PlayerListener> listener in _listeners) {
        [listener playerDidTick:self];
    }

    if (done) {
        [self playNextTrack];
    }
}


- (void) _updateLoudnessAndPreAmp
{
    if (![_currentTrack didAnalyzeLoudness]) {
        return;
    }

    double trackLoudness = [_currentTrack trackLoudness];
    double trackPeak     = [_currentTrack trackPeak];

    double preamp     = _preAmpLevel;
    double replayGain = (-18.0 - trackLoudness);

    if (replayGain < -51.0) {
        replayGain = -51.0;
    } else if (replayGain > 51.0) {
        replayGain = 51.0;
    }
    
    replayGain *= _matchLoudnessLevel;

    double	multiplier	= pow(10, (replayGain + preamp) / 20);
    double	sample		= trackPeak * multiplier;
    double	magnitude	= fabs(sample);

    if (magnitude >= sMaxVolume) {
        preamp = (20 * log10f(1.0 / trackPeak)) - replayGain;
    }

    double preGain = preamp + replayGain;

    AudioUnitParameter parameter = {
        _limiterAudioUnit,
        kLimiterParam_PreGain,
        kAudioUnitScope_Global,
        0
    };
    
    CheckError(AUParameterSet(NULL, NULL, &parameter, preGain, 0), "AUParameterSet");
}


#pragma mark - Graph

static OSStatus sInputRenderCallback(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData)
{
    RenderUserInfo *userInfo = (RenderUserInfo *)inRefCon;
    
    AudioUnit unit = userInfo->inputUnit;
    
    OSStatus result = AudioUnitRender(unit, ioActionFlags, inTimeStamp, 0, inNumberFrames, ioData);

    if (userInfo->stopRequested) {
        for (NSInteger i = 0; i < ioData->mNumberBuffers; i++) {
            AudioBuffer buffer = ioData->mBuffers[i];
            
            float *frames = (float *)buffer.mData;
            
            float start = 1.0;
            float step  = -(1.0 / (float)inNumberFrames);
            vDSP_vrampmul(frames, 1, &start, &step, frames, 1, inNumberFrames);
        }

        userInfo->stopped = 1;
    }

    return result;
}


- (void) _buildGraphHeadAndTrackScheduler
{
    [self _teardownGraphHead];

    AudioComponentDescription generatorCD = {0};
    generatorCD.componentType = kAudioUnitType_Generator;
    generatorCD.componentSubType = kAudioUnitSubType_ScheduledSoundPlayer;
    generatorCD.componentManufacturer = kAudioUnitManufacturer_Apple;
    generatorCD.componentFlags = kAudioComponentFlag_SandboxSafe;

    AUNode    generatorNode = 0;
    AudioUnit generatorUnit = 0;

    CheckError(AUGraphAddNode(_graph, &generatorCD,  &generatorNode), "AUGraphAddNode[ Generator ]");
	CheckError(AUGraphNodeInfo(_graph, generatorNode,  NULL, &generatorUnit), "AUGraphNodeInfo[ Player ]");

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
    
    UInt32 maxFrames = getPropertyUInt32(_outputAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global);
    
    AudioStreamBasicDescription outputStream;
    getPropertyStream(_outputAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, &outputStream);
    
    _currentScheduler = [[TrackScheduler alloc] initWithTrack:_currentTrack outputFormat:outputStream];
    
    if (![_currentScheduler setup]) {
        [_currentTrack setTrackError:(TrackError)[_currentScheduler audioFileError]];
        return;
    }
    
    AudioStreamBasicDescription generatorFormat = [_currentScheduler clientFormat];
    
    if (generatorFormat.mSampleRate != _outputSampleRate) {
        AudioComponentDescription converterCD = {0};
        converterCD.componentType = kAudioUnitType_FormatConverter;
        converterCD.componentSubType = kAudioUnitSubType_AUConverter;
        converterCD.componentManufacturer = kAudioUnitManufacturer_Apple;
        converterCD.componentFlags = kAudioComponentFlag_SandboxSafe;

        AUNode converterNode = 0;
        CheckError(AUGraphAddNode( _graph, &converterCD,  &converterNode),  "AUGraphAddNode[ Converter ]");

        AudioUnit converterUnit = 0;
        CheckError(AUGraphNodeInfo(_graph, converterNode,  NULL, &converterUnit),  "AUGraphNodeInfo[ Converter ]");


        UInt32 complexity = kAudioUnitSampleRateConverterComplexity_Mastering;

        setPropertyUInt32(converterUnit, kAudioUnitProperty_SampleRateConverterComplexity, kAudioUnitScope_Global, complexity);
        setPropertyUInt32(converterUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, maxFrames);

        setPropertyFloat64(converterUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Input,  generatorFormat.mSampleRate);
        setPropertyFloat64(converterUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, _outputSampleRate);

        setPropertyStream(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,  &generatorFormat);
        setPropertyStream(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, &outputStream);

        CheckError(AudioUnitInitialize(converterUnit), "AudioUnitInitialize[ Converter ]");

        // maxFrames will be different when going through a SRC
        maxFrames = getPropertyUInt32(converterUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global);

        _converterNode = converterNode;
        _converterAudioUnit = converterUnit;
    }

    setPropertyUInt32( generatorUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, maxFrames);
    setPropertyFloat64(generatorUnit, kAudioUnitProperty_SampleRate,            kAudioUnitScope_Output, generatorFormat.mSampleRate);
    setPropertyStream( generatorUnit, kAudioUnitProperty_StreamFormat,          kAudioUnitScope_Output, &generatorFormat);

    AudioUnitInitialize(generatorUnit);

    _generatorNode = generatorNode;
    _generatorAudioUnit = generatorUnit;

    _renderUserInfo.stopped = 0;
    _renderUserInfo.stopRequested = 0;
    _renderUserInfo.inputUnit = _converterAudioUnit ? _converterAudioUnit : _generatorAudioUnit;

    [self _reconnectGraph];
}


- (void) _teardownGraphHead
{
    if (_generatorAudioUnit) {
        CheckError(AudioUnitUninitialize(_generatorAudioUnit), "AudioUnitUninitialize[ Generator ]");
        CheckError(AUGraphRemoveNode(_graph, _generatorNode), "AUGraphRemoveNode[ Generator ]" );

        _generatorAudioUnit = NULL;
        _generatorNode = 0;
    }

    if (_converterAudioUnit) {
        CheckError(AudioUnitUninitialize(_converterAudioUnit), "AudioUnitUninitialize[ Converter ]");
        CheckError(AUGraphRemoveNode(_graph, _converterNode), "AUGraphRemoveNode[ Converter ]" );
        
        _converterAudioUnit = NULL;
        _converterNode = 0;
    }
}


- (void) _buildTailGraph
{
    CheckError(NewAUGraph(&_graph), "NewAUGraph");
	
    AudioComponentDescription limiterCD = {0};
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

    CheckError(AUGraphAddNode(_graph, &limiterCD,    &_limiterNode),    "AUGraphAddNode[ Limiter ]");
    CheckError(AUGraphAddNode(_graph, &mixerCD,      &_mixerNode),      "AUGraphAddNode[ Mixer ]");
    CheckError(AUGraphAddNode(_graph, &outputCD,     &_outputNode),     "AUGraphAddNode[ Output ]");

	CheckError(AUGraphOpen(_graph), "AUGraphOpen");

    CheckError(AUGraphNodeInfo(_graph, _limiterNode,    NULL, &_limiterAudioUnit),    "AUGraphNodeInfo[ Limiter ]");
	CheckError(AUGraphNodeInfo(_graph, _mixerNode,      NULL, &_mixerAudioUnit),      "AUGraphNodeInfo[ Mixer ]");
	CheckError(AUGraphNodeInfo(_graph, _outputNode,     NULL, &_outputAudioUnit),     "AUGraphNodeInfo[ Output ]");

	CheckError(AUGraphInitialize(_graph), "AUGraphInitialize");

    UInt32 on = 1;
    CheckError(AudioUnitSetProperty(_mixerAudioUnit,
        kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0,
        &on,
        sizeof(on)
    ), "AudioUnitSetProperty[kAudioUnitProperty_MeteringMode]");

    _emergencyLimiter = EmergencyLimiterCreate();

    AUGraphAddRenderNotify(_graph, sApplyEmergencyLimiter, _emergencyLimiter);
}


- (void) _iterateGraphNodes:(void (^)(AUNode))callback
{
    if (_generatorNode) callback(_generatorNode);
    if (_converterNode) callback(_converterNode);
    callback(_limiterNode);
    
    for (Effect *effect in _effects) {
        NSValue  *key        = [NSValue valueWithNonretainedObject:effect];
        NSNumber *nodeNumber = [_effectToNodeMap objectForKey:key];

        if (!nodeNumber) continue;
        callback([nodeNumber intValue]);
    }

    callback(_mixerNode);
    callback(_outputNode);
}


- (void) _iterateGraphAudioUnits:(void (^)(AudioUnit))callback
{
    [self _iterateGraphNodes:^(AUNode node) {
        AudioComponentDescription acd;
        AudioUnit audioUnit;

        AUGraphNodeInfo(_graph, node, &acd, &audioUnit);

        callback(audioUnit);
    }];
}


- (void) _reconnectGraph
{
    AUGraphClearConnections(_graph);
    
    __block AUNode lastNode = 0;
    __block NSInteger index = 0;

    AURenderCallbackStruct inputCallbackStruct;
    inputCallbackStruct.inputProc        = &sInputRenderCallback;
    inputCallbackStruct.inputProcRefCon  = &_renderUserInfo;

    CheckError(
        AUGraphSetNodeInputCallback(_graph, _limiterNode, 0, &inputCallbackStruct),
        "AUGraphSetNodeInputCallback"
    );

    [self _iterateGraphNodes:^(AUNode node) {
        if (lastNode && (node != _limiterNode)) {
            if (!CheckError(AUGraphConnectNodeInput(_graph, lastNode, 0, node, 0), "AUGraphConnectNodeInput")) {

            }
        }

        lastNode = node;
        index++;
    }];
    
    Boolean updated;
    if (!CheckError(AUGraphUpdate(_graph, &updated), "AUGraphUpdate")) {
    
    }
}


- (void) _checkIssues
{
    PlayerIssue issue = PlayerIssueNone;
    
    BOOL isHogged = [[_outputDevice controller] isHoggedByAnotherProcess];
    
    if (![_outputDevice isConnected]) {
        issue = PlayerIssueDeviceMissing;
    } else if (isHogged || (_outputHogMode && !_tookHogMode)) {
        issue = PlayerIssueDeviceHoggedByOtherProcess;
    } else if (_hadErrorDuringReconfigure) {
        issue = PlayerIssueErrorConfiguringOutputDevice;
    }

    if (issue != _issue) {
        [self setIssue:issue];

        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didUpdateIssue:issue];
        }
    }
}



- (void) _reconfigureOutput
{
    Boolean isRunning = 0;
    AUGraphIsRunning(_graph, &isRunning);
    
    _hadErrorDuringReconfigure = NO;
    
    if (isRunning) AUGraphStop(_graph);
    
    CheckError(AUGraphUninitialize(_graph), "AUGraphUninitialize");

    AUGraphClearConnections(_graph);

    for (AudioDevice *device in [AudioDevice outputAudioDevices]) {
        WrappedAudioDevice *controller = [device controller];
        
        if ([controller isHoggedByMe]) {
            [controller releaseHogMode];
        }
    }
    

    WrappedAudioDevice *controller = [_outputDevice controller];
    
    if ([_outputDevice isConnected] && ![controller isHoggedByAnotherProcess]) {
        AudioDeviceID deviceID = [controller objectID];
        
        [controller setNominalSampleRate:_outputSampleRate];
        [controller setFrameSize:_outputFrames];

        if (_outputHogMode) {
            _tookHogMode = [controller takeHogMode];
        }

        if (!CheckError(AudioUnitSetProperty(_outputAudioUnit,
            kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0,
            &_outputFrames,
            sizeof(_outputFrames)
        ), "AudioUnitSetProperty[kAudioDevicePropertyBufferFrameSize]")) {
            _hadErrorDuringReconfigure = YES;
        }

        if (!CheckError(AudioUnitSetProperty(_outputAudioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID, sizeof(deviceID)
        ), "AudioUnitSetProperty[CurrentDevice]")) {
            _hadErrorDuringReconfigure = YES;
        }
    }

    UInt32 maxFrames;
    UInt32 maxFramesSize = sizeof(maxFrames);
    
    if (!CheckError(AudioUnitGetProperty(
        _outputAudioUnit,
        kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
        &maxFrames, &maxFramesSize
    ), "AudioUnitGetProperty[MaximumFramesPerSlice]")) {
        _hadErrorDuringReconfigure = YES;
    }
    
    [self _iterateGraphAudioUnits:^(AudioUnit unit) {
        Float64 inputSampleRate  = _outputSampleRate;
        Float64 outputSampleRate = _outputSampleRate;

//        if (unit == _generatorAudioUnit) {
//            inputSampleRate = 0;
//            outputSampleRate = 0;
//            
//        } else if (unit == _converterAudioUnit) {
//            inputSampleRate = 0;
//            
        if (unit == _outputAudioUnit) {
            outputSampleRate = 0;
        }
        
        if (inputSampleRate) {
            if (!CheckError(AudioUnitSetProperty(
                unit,
                kAudioUnitProperty_SampleRate, kAudioUnitScope_Input, 0,
                &inputSampleRate, sizeof(inputSampleRate)
            ), "AudioUnitSetProperty[ SampleRate, Input ]")) {
                _hadErrorDuringReconfigure = YES;
            }
        }

        if (outputSampleRate) {
            if (!CheckError(AudioUnitSetProperty(
                unit,
                kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0,
                &outputSampleRate, sizeof(outputSampleRate)
            ), "AudioUnitSetProperty[ SampleRate, Output ]")) {
                _hadErrorDuringReconfigure = YES;
            }
        }

        if (!CheckError(AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
            &maxFrames, maxFramesSize
        ), "AudioUnitSetProperty[MaximumFramesPerSlice]")) {
            _hadErrorDuringReconfigure = YES;
        }
    }];

    if (!CheckError(AUGraphInitialize(_graph), "AUGraphInitialize")) {
        _hadErrorDuringReconfigure = YES;
    }

    [self _reconnectGraph];

    if (isRunning) {
        [self _startGraph];
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reconfigureOutput) object:nil];
    
    [self _checkIssues];
    
    if (_issue != PlayerIssueNone) {
        [self performSelector:@selector(_reconfigureOutput) withObject:nil afterDelay:1];
    }
}


- (void) _setupAndStartPlayback
{
    PlayerShouldUseCrashPad = 0;

    Track *track = _currentTrack;
    NSTimeInterval padding = _currentPadding;

    if (![track didAnalyzeLoudness] && ![track trackError]) {
        [track startPriorityAnalysis];
        [self performSelector:@selector(_setupAndStartPlayback) withObject:nil afterDelay:0.1];
        return;
    }

    NSURL *fileURL = [track fileURL];
    if (!fileURL) {
        [self hardStop];
        return;
    }

    [_currentScheduler stopScheduling:_generatorAudioUnit];
    _currentScheduler = nil;

    PlayerShouldUseCrashPad = 0;

    [self _buildGraphHeadAndTrackScheduler];
    [self _updateLoudnessAndPreAmp];

	AudioTimeStamp timestamp = {0};
    timestamp.mFlags = kAudioTimeStampSampleTimeValid;
    timestamp.mSampleTime = -1;

    BOOL didScheldule = [_currentScheduler startSchedulingWithAudioUnit:_generatorAudioUnit timeStamp:timestamp];
    if (!didScheldule) {
        [_currentTrack setTrackError:(TrackError)[_currentScheduler audioFileError]];
        return;
    }

	AudioTimeStamp startTime = {0};
    NSTimeInterval additional = _outputFrames / _outputSampleRate;

    EmergencyLimiterSetSampleRate(_emergencyLimiter, _outputSampleRate);

    if (padding == 0) {
        startTime.mFlags = kAudioTimeStampHostTimeValid;
        startTime.mHostTime = 0;
    
    } else {
        FillAudioTimeStampWithFutureSeconds(&startTime, padding + additional);
    }

	CheckError(AudioUnitSetProperty(
        _generatorAudioUnit,
        kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0,
        &startTime, sizeof(startTime)
    ), "AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]");
    
	
    if (startTime.mHostTime) {
        _currentStartHostTime = startTime.mHostTime;
    } else {
        FillAudioTimeStampWithFutureSeconds(&startTime, 0);
        _currentStartHostTime = startTime.mHostTime;
    }

    [self _startGraph];
}


- (void) _startGraph
{
    Boolean isRunning = 0;
    AUGraphIsRunning(_graph, &isRunning);

    if (!isRunning) {
        CheckError(AUGraphStart(_graph), "AUGraphStart");
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_stopGraph) object:nil];
}


- (void) _stopGraph
{
    CheckError(AUGraphStop(_graph), "AUGraphStop");
}


#pragma mark - Public Methods

- (AudioUnit) audioUnitForEffect:(Effect *)effect
{
    NSValue *key = [NSValue valueWithNonretainedObject:effect];
    AUNode node = [[_effectToNodeMap objectForKey:key] intValue];

    AudioUnit audioUnit;
    AudioComponentDescription acd;

    CheckError(AUGraphNodeInfo(_graph, node, &acd, &audioUnit), "AUGraphNodeInfo");

    return audioUnit;
}


- (void) saveEffectState
{
    NSMutableArray *effectsStateArray = [NSMutableArray arrayWithCapacity:[_effects count]];
    
    for (Effect *effect in _effects) {
        NSDictionary *dictionary = [effect stateDictionary];
        if (dictionary) [effectsStateArray addObject:dictionary];
    }

    [[NSUserDefaults standardUserDefaults] setObject:effectsStateArray forKey:sEffectsKey];
}


- (void) playNextTrack
{
    Track *nextTrack = nil;
    NSTimeInterval padding = 0;

    if (![_currentTrack pausesAfterPlaying]) {
        [_trackProvider player:self getNextTrack:&nextTrack getPadding:&padding];
    }
    
    if (nextTrack) {
        [self setCurrentTrack:nextTrack];
        _currentPadding = padding;

        [self _setupAndStartPlayback];

    } else {
        [self hardStop];
    }
}


- (void) playOrSoftPause
{
    if (_currentTrack) {
        [self softPause];
    } else {
        [self play];
    }
}


- (void) play
{
    if (_currentTrack) return;

    [self _reconfigureOutput];

    [self playNextTrack];
    
    if (_currentTrack) {
        _tickTimer = [NSTimer timerWithTimeInterval:(1/60.0) target:self selector:@selector(_tick:) userInfo:nil repeats:YES];

        [[NSRunLoop mainRunLoop] addTimer:_tickTimer forMode:NSRunLoopCommonModes];
        [[NSRunLoop mainRunLoop] addTimer:_tickTimer forMode:NSEventTrackingRunLoopMode];

        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didUpdatePlaying:YES];
        }
        
        if (_powerAssertionID) {
            IOPMAssertionRelease(_powerAssertionID);
            _powerAssertionID = 0;
        }
        
        
        
        BOOL preventDisplaySleep = [[NSUserDefaults standardUserDefaults] boolForKey:@"PreventDisplaySleepWhenPlaying"];
        CFStringRef name = preventDisplaySleep ? kIOPMAssertPreventUserIdleDisplaySleep : kIOPMAssertPreventUserIdleSystemSleep;
        
        IOPMAssertionCreateWithName(
            name,
            kIOPMAssertionLevelOn,
            CFSTR("Embrace is playing audio"),
            &_powerAssertionID
        );
    }
}


- (void) softPause
{
    if (_currentTrack) {
        TrackStatus trackStatus = [_currentTrack trackStatus];
        BOOL isEndSilence   = _timeRemaining <= [_currentTrack silenceAtEnd];
        BOOL isStartSilence = _timeElapsed   <  [_currentTrack silenceAtStart];

        if (_volume == 0) {
            [self hardStop];
        
        } else if (isEndSilence) {
            [_currentTrack setTrackStatus:TrackStatusPlayed];
            [self hardStop];
            
        } else if (isStartSilence) {
            Track *track = _currentTrack;
            [self hardStop];
            [track setTrackStatus:TrackStatusQueued];

        } else if (trackStatus == TrackStatusQueued) {
            [self hardStop];

        } else if (trackStatus == TrackStatusPlaying) {
            [_currentTrack setPausesAfterPlaying:![_currentTrack pausesAfterPlaying]];
        
        // This shouldn't happen, if it does advance to next song
        } else if (trackStatus == TrackStatusPlayed) {
            [self playNextTrack];
        }
        
    } else {
        [self hardStop];
    }
}


- (void) hardSkip
{
    if (!_currentTrack) return;

    Track *nextTrack = nil;
    NSTimeInterval padding = 0;

    [_currentTrack setTrackStatus:TrackStatusPlayed];
    [_currentTrack setPausesAfterPlaying:NO];

    [_trackProvider player:self getNextTrack:&nextTrack getPadding:&padding];
    
    if (nextTrack) {
        [self setCurrentTrack:nextTrack];
        _currentPadding = 0;

        [self _setupAndStartPlayback];

    } else {
        [self hardStop];
    }
}


- (void) hardStop
{
    if (!_currentTrack) return;

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_setupAndStartPlayback) object:nil];

    [_currentTrack setTrackStatus:TrackStatusPlayed];
    [_currentTrack setPausesAfterPlaying:NO];
    
    [self setCurrentTrack:nil];

    if (_tickTimer) {
        [_tickTimer invalidate];
        _tickTimer = nil;
    }

    Boolean isRunning = 0;
    AUGraphIsRunning(_graph, &isRunning);
    
    if (isRunning) {
        _renderUserInfo.stopRequested = 1;
        
        NSInteger loopGuard = 0;
        while ((_renderUserInfo.stopped == 0) && (loopGuard < 1000)) {
            usleep(1000);
            loopGuard++;
        }
        
        _renderUserInfo.stopRequested = 0;
        _renderUserInfo.stopped = 0;

//      To ensure the meter is actually cleared, let the graph run for 10 seconds
        [self performSelector:@selector(_stopGraph) withObject:nil afterDelay:10];
    }

    [self _iterateGraphAudioUnits:^(AudioUnit unit) {
        CheckError(
            AudioUnitReset(unit, kAudioUnitScope_Global, 0),
            "AudioUnitReset"
        );
    }];

    [_currentScheduler stopScheduling:_generatorAudioUnit];
    _currentScheduler = nil;
    
    _leftAveragePower = _rightAveragePower = _leftPeakPower = _rightPeakPower = -INFINITY;
    _limiterActive = NO;

    [self _teardownGraphHead];
    
    for (id<PlayerListener> listener in _listeners) {
        [listener player:self didUpdatePlaying:NO];
    }

    if (_powerAssertionID) {
        IOPMAssertionRelease(_powerAssertionID);
        _powerAssertionID = 0;
    }
}


- (void) updateOutputDevice: (AudioDevice *) outputDevice
                 sampleRate: (double) sampleRate
                     frames: (UInt32) frames
                    hogMode: (BOOL) hogMode
{
    if (!sampleRate) {
        sampleRate = [[[[outputDevice controller] availableSampleRates] firstObject] doubleValue];
    }

    if (!frames) {
        frames = [[[[outputDevice controller] availableFrameSizes] firstObject] doubleValue];
    }

    if (_outputDevice     != outputDevice ||
        _outputSampleRate != sampleRate   ||
        _outputFrames     != frames       ||
        _outputHogMode    != hogMode)
    {
        if (_outputDevice != outputDevice) {
            [_outputDevice removeObserver:self forKeyPath:@"connected"];
            _outputDevice = outputDevice;
            [_outputDevice addObserver:self forKeyPath:@"connected" options:0 context:NULL];
        }

        _outputSampleRate = sampleRate;
        _outputFrames = frames;
        _outputHogMode = hogMode;

        [self _reconfigureOutput];
        [self _checkIssues];
    }
}


- (void) addListener:(id<PlayerListener>)listener
{
    if (!_listeners) _listeners = [NSHashTable weakObjectsHashTable];
    if (listener) [_listeners addObject:listener];
}


- (void) removeListener:(id<PlayerListener>)listener
{
    [_listeners removeObject:listener];
}


#pragma mark - Accessors

- (void) setPreAmpLevel:(double)preAmpLevel
{
    if (_preAmpLevel != preAmpLevel) {
        _preAmpLevel = preAmpLevel;
        [[NSUserDefaults standardUserDefaults] setObject:@(preAmpLevel) forKey:sPreAmpKey];
        [self _updateLoudnessAndPreAmp];
    }
}


- (void) setMatchLoudnessLevel:(double)matchLoudnessLevel
{
    if (_matchLoudnessLevel != matchLoudnessLevel) {
        _matchLoudnessLevel = matchLoudnessLevel;
        [[NSUserDefaults standardUserDefaults] setObject:@(matchLoudnessLevel) forKey:sMatchLoudnessKey];
        [self _updateLoudnessAndPreAmp];
    }
}


- (void) setEffects:(NSArray *)effects
{
    if (_effects != effects) {
        _effects = effects;

        [self _updateEffects:effects];
        [self saveEffectState];
    }
}


- (void) setVolume:(double)volume
{
    if (volume < 0) volume = 0;
    if (volume > sMaxVolume) volume = sMaxVolume;

    if (_volume != volume) {
        _volume = volume;

        [[NSUserDefaults standardUserDefaults] setDouble:_volume forKey:sVolumeKey];
        
        CheckError(AudioUnitSetParameter(_mixerAudioUnit,
            kStereoMixerParam_Volume, kAudioUnitScope_Output, 0,
            volume, 0
        ), "AudioUnitSetParameter[Volume]");
        
        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didUpdateVolume:_volume];
        }
    }
}


- (BOOL) isPlaying
{
    return _currentTrack != nil;
}


- (NSArray *) debugInternalEffects
{
    Effect *effect = [[Effect alloc] initWithEffectType:nil];
    
//    [effect _setAudioUnit:_limiterAudioUnit];
    
    return @[ effect ];
}


@end


