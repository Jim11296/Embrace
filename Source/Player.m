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

#import <pthread.h>
#import <signal.h>

#define USE_SCHEDULER 1

static NSString * const sEffectsKey = @"effects";
static NSString * const sPreAmpKey  = @"pre-amp";
static NSString * const sMatchLoudnessKey = @"match-loudness";

static double sMaxVolume = 1.0 - (2.0 / 32767.0);


@interface Effect ()
- (void) _setAudioUnit:(AudioUnit)unit;
@end


@interface Player ()
@property (nonatomic, strong) Track *currentTrack;
@property (nonatomic) NSString *timeElapsedString;
@property (nonatomic) NSString *timeRemainingString;
@property (nonatomic) float percentage;
@property (nonatomic) PlayerIssue issue;
@end


@implementation Player {
    Track         *_currentTrack;
    NSTimeInterval _currentPadding;

    TrackScheduler *_currentScheduler;

    UInt64    _currentStartHostTime;

    AUGraph   _graph;
    AudioUnit _generatorAudioUnit;
    AudioUnit _limiterAudioUnit;
    AudioUnit _mixerAudioUnit;
    AudioUnit _postLimiterAudioUnit;
    AudioUnit _outputAudioUnit;

	AUNode    _generatorNode;
	AUNode    _limiterNode;
    AUNode    _mixerNode;
	AUNode    _outputNode;
    
    AudioDevice *_outputDevice;
    double       _outputSampleRate;
    UInt32       _outputFrames;
    BOOL         _outputHogMode;

    BOOL         _tookHogMode;
    BOOL         _hadErrorDuringReconfigure;
    
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
        [self _buildGraph];
        [self _loadState];
        [self _reconnectGraph];

        [self setVolume:0.95];
    }
    
    return self;
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _outputDevice) {
        if ([keyPath isEqualToString:@"connected"]) {
            [self _checkIssues];
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
}


- (void) _updateEffects:(NSArray *)effects
{
    NSMutableDictionary *effectToNodeMap = [NSMutableDictionary dictionary];

    for (Effect *effect in effects) {
        NSValue *key = [NSValue valueWithNonretainedObject:effect];
        AUNode node;

        AudioComponentDescription acd = [[effect type] AudioComponentDescription];

        NSNumber *nodeNumber = [_effectToNodeMap objectForKey:key];
        if (nodeNumber) {
            node = [nodeNumber intValue];
        } else {
            AUGraphAddNode(_graph, &acd, &node);

            UInt32 maxFrames;
            UInt32 maxFramesSize = sizeof(maxFrames);
            CheckError(AudioUnitGetProperty(
                _outputAudioUnit,
                kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                &maxFrames, &maxFramesSize
            ), "AudioUnitGetProperty[MaximumFramesPerSlice]");

            AudioComponentDescription acd;
            AudioUnit unit = NULL;
            AUGraphNodeInfo(_graph, node, &acd, &unit);

            CheckError(AudioUnitSetProperty(
                unit,
                kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                &maxFrames, maxFramesSize
            ), "AudioUnitSetProperty[MaximumFramesPerSlice]");
        }
        
        AudioUnit audioUnit;
        CheckError(AUGraphNodeInfo(_graph, node, &acd, &audioUnit), "AUGraphNodeInfo");
        
        AudioUnitParameter changedUnit;
        changedUnit.mAudioUnit = audioUnit;
        changedUnit.mParameterID = kAUParameterListener_AnyParameter;
        AUParameterListenerNotify(NULL, NULL, &changedUnit);

        [effect _setAudioUnit:audioUnit];

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
    
    _timeElapsed = 0;

    NSTimeInterval roundedTimeElapsed;
    NSTimeInterval roundedTimeRemaining;

    if (timeStamp.mSampleTime < 0) {
        _timeElapsed   = GetDeltaInSecondsForHostTimes(GetCurrentHostTime(), _currentStartHostTime);
        _timeRemaining = [_currentTrack playDuration];
        
        roundedTimeElapsed = floor(_timeElapsed);
        roundedTimeRemaining = round([_currentTrack playDuration]);

    } else {
        _timeElapsed = currentPlayTime / _outputSampleRate;
        _timeRemaining = [_currentTrack playDuration] - _timeElapsed;
        
        roundedTimeElapsed = floor(_timeElapsed);
        roundedTimeRemaining = round([_currentTrack playDuration]) - roundedTimeElapsed;
    }

    if (_timeRemaining < 0) {
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

- (void) _buildGraph
{
    CheckError(NewAUGraph(&_graph), "NewAUGraph failed");
	
    AudioComponentDescription generatorCD = {0};
    generatorCD.componentType = kAudioUnitType_Generator;
    generatorCD.componentManufacturer = kAudioUnitManufacturer_Apple;
    generatorCD.componentFlags = kAudioComponentFlag_SandboxSafe;

#if USE_SCHEDULER
    generatorCD.componentSubType = kAudioUnitSubType_ScheduledSoundPlayer;
#else
    generatorCD.componentSubType = kAudioUnitSubType_AudioFilePlayer;
#endif

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

    CheckError(AUGraphAddNode(_graph, &generatorCD,  &_generatorNode),  "AUGraphAddNode[ Generator ]");
    CheckError(AUGraphAddNode(_graph, &limiterCD,    &_limiterNode),    "AUGraphAddNode[ Limiter ]");
    CheckError(AUGraphAddNode(_graph, &mixerCD,      &_mixerNode),      "AUGraphAddNode[ Mixer ]");
    CheckError(AUGraphAddNode(_graph, &outputCD,     &_outputNode),     "AUGraphAddNode[ Output ]");

	CheckError(AUGraphOpen(_graph), "AUGraphOpen");

	CheckError(AUGraphNodeInfo(_graph, _generatorNode,  NULL, &_generatorAudioUnit),  "AUGraphNodeInfo[ Player ]");
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
}


- (void) _iterateGraphNodes:(void (^)(AUNode))callback
{
    callback(_generatorNode);
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
    [self _iterateGraphNodes:^(AUNode node) {
        if (lastNode) {
            CheckError(AUGraphConnectNodeInput(_graph, lastNode, 0, node, 0), "AUGraphConnectNodeInput");
        }

        lastNode = node;
    }];
    
    Boolean updated;
    if (!CheckError(AUGraphUpdate(_graph, &updated), "AUGraphUpdate")) {
    
    }
}


- (void) _checkIssues
{
    PlayerIssue issue = PlayerIssueNone;
    
    if (![_outputDevice isConnected]) {
        issue = PlayerIssueDeviceMissing;
    } else if (_outputHogMode && !_tookHogMode) {
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

    for (AudioDevice *device in [AudioDevice outputAudioDevices]) {
        WrappedAudioDevice *controller = [device controller];
        
        if ([controller isHoggedByMe]) {
            [controller releaseHogMode];
        }
    }
    
    if ([_outputDevice isConnected]) {
        WrappedAudioDevice *controller = [_outputDevice controller];

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

    [self _reconnectGraph];

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

    if (isRunning) AUGraphStart(_graph);
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reconfigureOutput) object:nil];
    
    [self _checkIssues];
    
    if (_issue != PlayerIssueNone) {
        [self performSelector:@selector(_reconfigureOutput) withObject:nil afterDelay:1];
    }
}


- (void) _setupAndStartPlayback
{
    Track *track = _currentTrack;
    NSTimeInterval padding = _currentPadding;

    if (![track didAnalyzeLoudness]) {
        [track startPriorityAnalysis];
        [self performSelector:@selector(_setupAndStartPlayback) withObject:nil afterDelay:0.1];
        return;
    }

    NSURL *fileURL = [track fileURL];
    if (!fileURL) {
        [self hardStop];
        return;
    }

#if USE_SCHEDULER
    [_currentScheduler stopScheduling:_generatorAudioUnit];
    
    AudioStreamBasicDescription streamDescription;
    UInt32 streamDescriptionSize = sizeof(streamDescription);

    CheckError(AudioUnitGetProperty(
        _outputAudioUnit,
        kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
        &streamDescription, &streamDescriptionSize
    ), "AudioUnitGetProperty[MaximumFramesPerSlice]");

	AudioTimeStamp timestamp = {0};
    timestamp.mFlags = kAudioTimeStampSampleHostTimeValid;
    timestamp.mHostTime = 0;
    
    _currentScheduler = [[TrackScheduler alloc] initWithTrack:_currentTrack streamDescription:streamDescription];
    [_currentScheduler startSchedulingWithAudioUnit:_generatorAudioUnit timeStamp:timestamp];
    
	AudioTimeStamp startTime = {0};
    NSTimeInterval additional = _outputFrames / _outputSampleRate;

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
    
    
#else
    AudioFileID audioFile;
	AudioStreamBasicDescription inputFormat;

	if (!CheckError(AudioFileOpenURL((__bridge CFURLRef)fileURL, kAudioFileReadPermission, 0, &audioFile), "AudioFileOpenURL")) {
        return;
    }
	
	UInt32 propSize = sizeof(inputFormat);
	if (!CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propSize, &inputFormat), "AudioFileGetProperty")) {
        [self hardStop];
        return;
    }
    
	// tell the file player unit to load the file we want to play
	if (!CheckError(AudioUnitSetProperty(
        _generatorAudioUnit,
        kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0,
        &audioFile, sizeof(audioFile)
    ), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIDs]")) {
        [self hardStop];
        return;
    }

    [self _updateLoudnessAndPreAmp];
	
	UInt64 nPackets;
	UInt32 propsize = sizeof(nPackets);
	if (!CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets), "AudioFileGetProperty")) {
        [self hardStop];
        return;
    }
	
	ScheduledAudioFileRegion region = {0};

	region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
	region.mTimeStamp.mSampleTime = -1;
	region.mCompletionProc = NULL;
	region.mCompletionProcUserData = 0;
    region.mAudioFile = audioFile;
    region.mLoopCount = 0;
    
    Float64 totalFrames  = ((UInt32)nPackets * inputFormat.mFramesPerPacket);
    Float64 startFrame   = [track startTime] * inputFormat.mSampleRate;

    if ([track stopTime]) {
        totalFrames = [track stopTime] * inputFormat.mSampleRate;
    }

    UInt32 framesToPlay = totalFrames - startFrame;

    region.mStartFrame   = startFrame;
	region.mFramesToPlay = framesToPlay;
    
	CheckError(AudioUnitSetProperty(
        _generatorAudioUnit,
        kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0,
        &region, sizeof(region)
    ), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion]");
	
	AudioTimeStamp startTime = {0};
    NSTimeInterval additional = _outputFrames / _outputSampleRate;

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
    
	UInt32 prime = 0;
	CheckError(AudioUnitSetProperty(
        _generatorAudioUnit,
        kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, _outputFrames,
        &prime, sizeof(prime)
    ), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFilePrime]");
	
    if (startTime.mHostTime) {
        _currentStartHostTime = startTime.mHostTime;
    } else {
        FillAudioTimeStampWithFutureSeconds(&startTime, 0);
        _currentStartHostTime = startTime.mHostTime;
    }
#endif

    Boolean isRunning = 0;
    AUGraphIsRunning(_graph, &isRunning);

    if (!isRunning) {
        CheckError(AUGraphStart(_graph), "AUGraphStart");
    }
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
        [effectsStateArray addObject:[effect stateDictionary]];
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
    [self playNextTrack];
    
    if (_currentTrack) {
        _tickTimer = [NSTimer timerWithTimeInterval:(1/60.0) target:self selector:@selector(_tick:) userInfo:nil repeats:YES];

        [[NSRunLoop mainRunLoop] addTimer:_tickTimer forMode:NSRunLoopCommonModes];
        [[NSRunLoop mainRunLoop] addTimer:_tickTimer forMode:NSEventTrackingRunLoopMode];

        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didUpdatePlaying:YES];
        }
    }
}


- (void) softPause
{
    if (_currentTrack) {
        TrackStatus trackStatus = [_currentTrack trackStatus];
        BOOL isEndSilence   = _timeRemaining <= [_currentTrack silenceAtEnd];
        BOOL isStartSilence = _timeElapsed   <  [_currentTrack silenceAtStart];

        if (isEndSilence) {
            [_currentTrack setTrackStatus:TrackStatusPlayed];
            [self hardStop];
            
        } else if (isStartSilence) {
            [self hardStop];

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
        AUGraphStop(_graph);
    }
    
    for (id<PlayerListener> listener in _listeners) {
        [listener player:self didUpdatePlaying:NO];
    }
}


- (void) updateOutputDevice: (AudioDevice *) outputDevice
                 sampleRate: (double) sampleRate
                     frames: (UInt32) frames
                    hogMode: (BOOL) hogMode
{
    if (!sampleRate) sampleRate = 44100;
    if (!frames)     frames = 512;

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
    [_listeners addObject:listener];
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
        
        CheckError(AudioUnitSetParameter(_mixerAudioUnit,
            kStereoMixerParam_Volume, kAudioUnitScope_Output, 0,
            volume, 0
        ), "AudioUnitSetParameter[Volume]");
    }
}


- (BOOL) isPlaying
{
    return _currentTrack != nil;
}


- (NSArray *) debugInternalEffects
{
    Effect *effect = [[Effect alloc] initWithEffectType:nil];
    
    [effect _setAudioUnit:_limiterAudioUnit];
    
    return @[ effect ];
}



@end


