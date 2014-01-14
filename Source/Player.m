//
//  player.m
//  Terpsichore
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

#import <pthread.h>
#import <signal.h>


static NSString * const sEffectsKey = @"effects";

typedef struct AudioPlayerGraphContext {
    Float64 sampleTime;
} AudioPlayerGraphContext;


@interface Effect ()
- (void) _setAudioUnit:(AudioUnit)unit;
@end


static mach_port_t sAudioThread = 0;

static OSStatus sRenderNotify(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData
) {
    if (!sAudioThread) {
        sAudioThread = pthread_mach_thread_np(pthread_self());
    }
    
    return noErr;
}


@interface Player ()
@property (nonatomic, strong) Track *currentTrack;
@end


@implementation Player {
    Track    *_currentTrack;
    Float64   _currentFramesToPlay;
    Float64   _currentSampleRate;
    UInt64    _currentStartHostTime;

    AUGraph   _graph;
    AudioUnit _outputAudioUnit;
    AudioUnit _filePlayerAudioUnit;
    AudioUnit _mixerAudioUnit;

	AUNode    _filePlayerNode;
	AUNode    _outputNode;
    AUNode    _mixerNode;
    
    AudioDevice *_outputDevice;
    double _sampleRate;
    UInt32 _frames;
    BOOL _hogMode;
    
    AudioPlayerGraphContext *_graphContext;
    
    NSMutableDictionary *_effectToNodeMap;
    
    NSTimer *_tickTimer;
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


- (id) init
{
    if ((self = [super init])) {
        _graphContext = (AudioPlayerGraphContext *)calloc(1, sizeof(AudioPlayerGraphContext));
        _volume = 1.0;

        [self _buildGraph];
        [self _loadState];
    }
    
    return self;
}


- (void) dealloc
{
    free(_graphContext);
}


#pragma mark - Graph

- (void) _buildGraph
{
    CheckError(NewAUGraph(&_graph), "NewAUGraph failed");
	
    AudioComponentDescription filePlayerCD = {0};
    filePlayerCD.componentType = kAudioUnitType_Generator;
    filePlayerCD.componentSubType = kAudioUnitSubType_AudioFilePlayer;
    filePlayerCD.componentManufacturer = kAudioUnitManufacturer_Apple;

    AudioComponentDescription mixerCD = {0};
    mixerCD.componentType = kAudioUnitType_Mixer;
    mixerCD.componentSubType = kAudioUnitSubType_StereoMixer;
    mixerCD.componentManufacturer = kAudioUnitManufacturer_Apple;

    AudioComponentDescription outputCD = {0};
    outputCD.componentType = kAudioUnitType_Output;
    outputCD.componentSubType = kAudioUnitSubType_HALOutput;
    outputCD.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    CheckError(AUGraphAddNode(_graph, &filePlayerCD, &_filePlayerNode), "AUGraphAddNode[ AudioFilePlayer ]");
    CheckError(AUGraphAddNode(_graph, &mixerCD, &_mixerNode), "AUGraphAddNode[ Mixer ]");
    CheckError(AUGraphAddNode(_graph, &outputCD, &_outputNode), "AUGraphAddNode[ Output ]");

	CheckError(AUGraphOpen(_graph), "AUGraphOpen");

	CheckError(AUGraphNodeInfo(_graph, _filePlayerNode, NULL, &_filePlayerAudioUnit), "AUGraphNodeInfo[_filePlayerNode]");
	CheckError(AUGraphNodeInfo(_graph, _outputNode,     NULL, &_outputAudioUnit),     "AUGraphNodeInfo[_outputNode]");
	CheckError(AUGraphNodeInfo(_graph, _mixerNode,      NULL, &_mixerAudioUnit),      "AUGraphNodeInfo[_mixerNode]");

	CheckError(AUGraphConnectNodeInput(_graph, _filePlayerNode, 0, _mixerNode, 0),  "AUGraphConnectNodeInput");
	CheckError(AUGraphConnectNodeInput(_graph, _mixerNode,      0, _outputNode, 0), "AUGraphConnectNodeInput");
	CheckError(AUGraphInitialize(_graph), "AUGraphInitialize");

    UInt32 on = 1;
    CheckError(AudioUnitSetProperty(_mixerAudioUnit,
        kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0,
        &on,
        sizeof(on)
    ), "AudioUnitSetProperty[kAudioUnitProperty_MeteringMode]");

    AUGraphAddRenderNotify(_graph, sRenderNotify, NULL);
}


- (void) _iterateGraphNodes:(void (^)(AUNode))callback
{
    callback(_filePlayerNode);
    
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
            CheckError(AUGraphConnectNodeInput(_graph, lastNode, 0, node, 0), "AUGraphConnectNodeInput 1");
        }

        lastNode = node;
    }];
    
    Boolean updated;
    AUGraphUpdate(_graph, &updated);
}


- (void) _reconfigureOutput
{
    Boolean isRunning = 0;
    AUGraphIsRunning(_graph, &isRunning);
    
    if (isRunning) AUGraphStop(_graph);
    
    CheckError(AUGraphUninitialize(_graph), "AUGraphUninitialize");

    for (AudioDevice *device in [AudioDevice outputAudioDevices]) {
        if ([device isHoggedByMe]) {
            [device releaseHogMode];
        }
    }
    
    if (_outputDevice) {
        AudioDeviceID deviceID = [_outputDevice objectID];
        
        [_outputDevice setNominalSampleRate:_sampleRate];
        [_outputDevice setIOBufferSize:_frames];

        if (_hogMode) {
            [_outputDevice takeHogMode];

        CheckError(AudioUnitSetProperty(_outputAudioUnit,
            kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0,
            &_frames,
            sizeof(_frames)
        ), "AudioUnitSetProperty[kAudioDevicePropertyBufferFrameSize]");
        }

        CheckError(AudioUnitSetProperty(_outputAudioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID, sizeof(deviceID)
        ), "AudioUnitSetProperty[CurrentDevice]");
    }

    [self _reconnectGraph];

    UInt32 maxFrames;
    UInt32 maxFramesSize = sizeof(maxFrames);
    CheckError(AudioUnitGetProperty(
        _outputAudioUnit,
        kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
        &maxFrames, &maxFramesSize
    ), "AudioUnitGetProperty[MaximumFramesPerSlice]");

    [self _iterateGraphAudioUnits:^(AudioUnit unit) {
        CheckError(AudioUnitSetProperty(
            unit,
            kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
            &maxFrames, maxFramesSize
        ), "AudioUnitSetProperty[MaximumFramesPerSlice]");
    }];

    CheckError(AUGraphInitialize(_graph), "AUGraphInitialize");

    if (isRunning) AUGraphStart(_graph);
}


- (BOOL) _openFileForTrack:(Track *)track
{
    NSURL *fileURL = [track fileURL];
    if (!fileURL) return NO;
    
    AudioFileID audioFile;
	AudioStreamBasicDescription inputFormat;

	if (!CheckError(AudioFileOpenURL((__bridge CFURLRef)fileURL, kAudioFileReadPermission, 0, &audioFile), "AudioFileOpenURL")) {
        return NO;
    }
	
	UInt32 propSize = sizeof(inputFormat);
	if (!CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propSize, &inputFormat), "AudioFileGetProperty")) {
        return NO;
    }
    
	// tell the file player unit to load the file we want to play
	if (!CheckError(AudioUnitSetProperty(
        _filePlayerAudioUnit,
        kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0,
        &audioFile, sizeof(audioFile)
    ), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIDs]")) {
        return NO;
    }
	
	UInt64 nPackets;
	UInt32 propsize = sizeof(nPackets);
	if (!CheckError(AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets), "AudioFileGetProperty")) {
        return NO;
    }
	
	ScheduledAudioFileRegion region = {0};

	region.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
	region.mTimeStamp.mSampleTime = 0;
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
        _filePlayerAudioUnit,
        kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0,
        &region, sizeof(region)
    ), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion]");
	
	UInt32 prime = 0;
	CheckError(AudioUnitSetProperty(
        _filePlayerAudioUnit,
        kAudioUnitProperty_ScheduledFilePrime, kAudioUnitScope_Global, 0,
        &prime, sizeof(prime)
    ), "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFilePrime]");
	
	AudioTimeStamp startTime = {0};
    FillAudioTimeStampWithFutureSeconds(&startTime, [track padDuration]);

	CheckError(AudioUnitSetProperty(
        _filePlayerAudioUnit,
        kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0,
        &startTime, sizeof(startTime)
    ), "AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]");

    _currentStartHostTime = GetCurrentHostTime();
    _currentFramesToPlay  = framesToPlay;
    _currentSampleRate    = inputFormat.mSampleRate;
    
    return YES;
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
    
    [self setEffects:effects];
}


- (void) setEffects:(NSArray *)effects
{
    if (_effects != effects) {
        _effects = effects;

        [self _updateEffects:effects];

        NSMutableArray *effectsStateArray = [NSMutableArray array];

        for (Effect *effect in _effects) {
            [effectsStateArray addObject:[effect stateDictionary]];
        }

        [[NSUserDefaults standardUserDefaults] setObject:effectsStateArray forKey:sEffectsKey];
    }
}


- (void) _updateEffects:(NSArray *)effects
{
    AUNode fromNode = _filePlayerNode;

    NSMutableDictionary *effectToNodeMap = [NSMutableDictionary dictionary];

    for (Effect *effect in effects) {
        NSValue *key = [NSValue valueWithNonretainedObject:effect];
        AUNode node;

        AudioComponentDescription acd = [[effect type] AudioComponentDescription];

        NSNumber *nodeNumber = [_effectToNodeMap objectForKey:key];
        if (nodeNumber) {
            node = [nodeNumber intValue];
                NSLog(@"existing effect %ld", (long)node);
            
        } else {
            AUGraphAddNode(_graph, &acd, &node);
                NSLog(@"new effect %ld", (long)node);

        }
        
        AudioUnit audioUnit;
        CheckError(AUGraphNodeInfo(_graph, node, &acd, &audioUnit), "AUGraphNodeInfo");
        
        CheckError(AUGraphConnectNodeInput(_graph, fromNode, 0, node, 0), "AUGraphConnectNodeInput 1");
        fromNode = node;

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

    [self _reconnectGraph];

    _effectToNodeMap = effectToNodeMap;
}


- (void) _tick:(NSTimer *)timer
{
    AudioTimeStamp timeStamp = {0};
    UInt32 timeStampSize = sizeof(timeStamp);

    TrackStatus status = TrackStatusPlaying;

    AudioUnitGetProperty(_filePlayerAudioUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, &timeStamp, &timeStampSize);
    Float64 currentPlayTime = timeStamp.mSampleTime;
    Float64 padOffset  = 0;
    Float64 playOffset = 0;
    BOOL done = NO;
    
    Float32 postAverageLeft;
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostAveragePower, kAudioUnitScope_Output, 0, &postAverageLeft);

    Float32 postAverageRight;
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostAveragePower + 1, kAudioUnitScope_Output, 0, &postAverageRight);

    Float32 postPeakHoldLevelLeft;
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostPeakHoldLevel, kAudioUnitScope_Output, 0, &postPeakHoldLevelLeft);

    Float32 postPeakHoldLevelRight;
    AudioUnitGetParameter(_mixerAudioUnit, kMultiChannelMixerParam_PostPeakHoldLevel + 1, kAudioUnitScope_Output, 0, &postPeakHoldLevelRight);
    
    if (timeStamp.mSampleTime < 0) {
        UInt64 currentHostTime = GetCurrentHostTime();
        padOffset  = GetDeltaInSecondsForHostTimes(currentHostTime, _currentStartHostTime);
        playOffset = 0;
        status = TrackStatusPadding;

    } else {
        padOffset  = [_currentTrack padDuration];
        playOffset = currentPlayTime / _currentSampleRate;
        status = TrackStatusPlaying;
    }

    if (currentPlayTime > _currentFramesToPlay) {
        done = YES;
        playOffset = [_currentTrack playDuration];
        status = TrackStatusPlayed;
    }

    [_currentTrack updateTrackStatus: status
                           padOffset: padOffset
                          playOffset: playOffset
                    leftAveragePower: postAverageLeft
                   rightAveragePower: postAverageRight
                       leftPeakPower: postPeakHoldLevelLeft
                      rightPeakPower: postPeakHoldLevelRight];

    [_delegate playerDidUpdate:self];

    if (done) {
        [self hardPause];
        [self play];
    }
}


- (AudioUnit) audioUnitForEffect:(Effect *)effect
{
    NSValue *key = [NSValue valueWithNonretainedObject:effect];
    AUNode node = [[_effectToNodeMap objectForKey:key] intValue];

    AudioUnit audioUnit;
    AudioComponentDescription acd;

    CheckError(AUGraphNodeInfo(_graph, node, &acd, &audioUnit), "AUGraphNodeInfo");

    return audioUnit;
}


- (void) play
{
    if (_currentTrack) return;
    
    Track *track = [_delegate playerNextTrack:self];

    [self setCurrentTrack:nil];

    if ([self _openFileForTrack:track]) {
        [self setCurrentTrack:track];

        CheckError(AUGraphStart(_graph), "AUGraphStart");
        _tickTimer = [NSTimer timerWithTimeInterval:(1/60.0) target:self selector:@selector(_tick:) userInfo:nil repeats:YES];

        [[NSRunLoop mainRunLoop] addTimer:_tickTimer forMode:NSRunLoopCommonModes];
        [[NSRunLoop mainRunLoop] addTimer:_tickTimer forMode:NSEventTrackingRunLoopMode];

        [_delegate playerDidUpdate:self];
    }
}


- (void) softPause
{
    if (_currentTrack) {
        TrackStatus trackStatus = [_currentTrack trackStatus];
        
        if (trackStatus == TrackStatusQueued || trackStatus == TrackStatusPadding) {
            [self hardPause];

        } else if (trackStatus == TrackStatusPlaying) {
            [_currentTrack updatePausesAfterPlaying:![_currentTrack pausesAfterPlaying]];
        
        // This shouldn't happen, if it does advance to next song
        } else if (trackStatus == TrackStatusPlayed) {
            [self hardPause];
            [self play];
        }
        
    } else {
        [self hardPause];
    }
}


- (void) hardPause
{
    if (!_currentTrack) return;
    
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
    
    [_delegate playerDidUpdate:self];
}


- (BOOL) isPlaying
{
    return _currentTrack != nil;
}


- (BOOL) canPlay
{
    if ([self isPlaying]) {
        return NO;
    }
    
    BOOL trackOK = [_delegate playerNextTrack:self] != nil;
    BOOL hardwareOK = YES;

    return trackOK && hardwareOK;
}


- (BOOL) canPause
{
    if (![self isPlaying]) {
        return NO;
    }
    
    //
    if ([self volume] == 0) {
        return YES;
    }
    
    if (0 /* in silence in track */) {
        return YES;
    }
    
    return NO;
}


- (void) updateOutputDevice: (AudioDevice *) outputDevice
                 sampleRate: (double) sampleRate
                     frames: (UInt32) frames
                    hogMode: (BOOL) hogMode
{
    if (!sampleRate) sampleRate = 44100;
    if (!frames)     frames = 512;

    if (_outputDevice != outputDevice ||
        _sampleRate   != sampleRate   ||
        _frames       != frames       ||
        _hogMode      != hogMode)
    {
        _outputDevice = outputDevice;
        _sampleRate = sampleRate;
        _frames = frames;
        _hogMode = hogMode;

        [self _reconfigureOutput];
    }
}


- (void) setVolume:(double)volume
{
    if (volume < 0) volume = 0;
    if (volume > 1) volume = 1;

    if (_volume != volume) {
        _volume = volume;
        
        CheckError(AudioUnitSetParameter(_mixerAudioUnit,
            kStereoMixerParam_Volume, kAudioUnitScope_Output, 0,
            volume, 0
        ), "AudioUnitSetParameter[Volume]");
    }
}

@end


