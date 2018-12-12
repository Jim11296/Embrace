// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "Player.h"
#import "Track.h"
#import "Effect.h"
#import "AppDelegate.h"
#import "EffectType.h"
#import "AudioDevice.h"
#import "Preferences.h"
#import "WrappedAudioDevice.h"
#import "HugAudioEngine.h"
#import "HugAudioSettings.h"
#import "HugAudioSource.h"


#import <pthread.h>
#import <signal.h>
#import <Accelerate/Accelerate.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

#define CHECK_RENDER_ERRORS_ON_TICK 0

static NSString * const sEffectsKey       = @"effects";
static NSString * const sPreAmpKey        = @"pre-amp";
static NSString * const sMatchLoudnessKey = @"match-loudness";
static NSString * const sVolumeKey        = @"volume";
static NSString * const sStereoLevelKey   = @"stereo-level";
static NSString * const sStereoBalanceKey = @"stereo-balance";

static double sMaxVolume = 1.0 - (2.0 / 32767.0);

volatile NSInteger PlayerShouldUseCrashPad = 0;



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

    HugAudioEngine *_engine;
    
    AudioDevice *_outputDevice;
    double       _outputSampleRate;
    UInt32       _outputFrames;
    BOOL         _outputHogMode;
    BOOL         _outputResetsVolume;
    
    AudioDeviceID _listeningDeviceID;

    BOOL         _hadChangeDuringPlayback;

    NSInteger    _setupAndStartPlayback_failureCount;

    id<NSObject> _processActivityToken;
    IOPMAssertionID _pmAssertionID;

    NSHashTable *_listeners;
    
    NSTimer *_tickTimer;

    NSTimeInterval _roundedTimeElapsed;
    NSTimeInterval _roundedTimeRemaining;
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
        EmbraceLog(@"Player", @"-init");

        _volume = -1;
        _engine = [[HugAudioEngine alloc] init];
        
        [self _loadState];
    }
    
    return self;
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _outputDevice) {
        if ([keyPath isEqualToString:@"connected"]) {
            if (![_outputDevice isConnected]) {
                EmbraceLog(@"Player", @"Calling -hardStop due to %@ -isConnected returning false", _outputDevice);

                [self hardStop];
                [self _reconfigureOutput];

            } else {
                if (![self isPlaying]) {
                    [self _reconfigureOutput];
                }
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

    NSNumber *stereoLevel = [[NSUserDefaults standardUserDefaults] objectForKey:sStereoLevelKey];
    if ([stereoLevel isKindOfClass:[NSNumber class]]) {
        [self setStereoLevel:[stereoLevel doubleValue]];
    } else {
        [self setStereoLevel:1.0];
    }

    NSNumber *stereoBalance = [[NSUserDefaults standardUserDefaults] objectForKey:sStereoBalanceKey];
    if ([stereoBalance isKindOfClass:[NSNumber class]]) {
        [self setStereoBalance:[stereoBalance doubleValue]];
    } else {
        [self setStereoBalance:0.5];
    }
    
    [self setEffects:effects];

    NSNumber *volume = [[NSUserDefaults standardUserDefaults] objectForKey:sVolumeKey];
    if (!volume) volume = @0.96;
    [self setVolume:[volume doubleValue]];
}


- (void) _tick:(NSTimer *)timer
{
//    TrackScheduler *scheduler = [_engine scheduler];
//
//    if (!scheduler) {
//        return;
//    }
//    
    HugPlaybackStatus playbackStatus = [_engine playbackStatus];
    
    _timeElapsed      = [_engine timeElapsed];
    _timeRemaining    = [_engine timeRemaining];
    _leftMeterData    = [_engine leftMeterData];
    _rightMeterData   = [_engine rightMeterData];
    _dangerPeak       = [_engine dangerLevel];
    _lastOverloadTime = [_engine lastOverloadTime];

    BOOL done = NO;
    TrackStatus status = TrackStatusPlaying;

    NSTimeInterval roundedTimeElapsed   = floor(_timeElapsed);
    NSTimeInterval roundedTimeRemaining = round(_timeRemaining);

    if (playbackStatus == HugPlaybackStatusFinished) {
        done = YES;

        _timeElapsed = [_currentTrack playDuration];
        _timeRemaining = 0;

        roundedTimeElapsed = round([_currentTrack playDuration]);
        roundedTimeRemaining = 0;

        status = TrackStatusPlayed;

    } else if (playbackStatus == HugPlaybackStatusPreparing) {
        status = TrackStatusPreparing;

    } else {
        status = TrackStatusPlaying;
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

    [_currentTrack setTrackStatus:status];

    for (id<PlayerListener> listener in _listeners) {
        [listener playerDidTick:self];
    }

    if (done && !_preventNextTrack) {
        [self playNextTrack];
    }
}


- (void) _updateLoudnessAndPreAmp
{
    EmbraceLog(@"Player", @"-_updateLoudnessAndPreAmp");

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

    EmbraceLog(@"Player", @"updating preGain to %g, trackLoudness=%g, trackPeak=%g, replayGain=%g", preGain, trackLoudness, trackPeak, replayGain);


    // Convert from dB to linear
    preGain = pow(10, preGain / 20);
    
    [_engine updatePreGain:preGain];
}


- (void) _updateFermata
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.iccir.Fermata.Update" object:nil userInfo:nil options:NSDistributedNotificationDeliverImmediately];
    });
}


- (void) _sendDistributedNotification
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.iccir.Embrace.playerUpdate" object:nil userInfo:nil options:NSDistributedNotificationDeliverImmediately];
    });
}


- (void) _takePowerAssertions
{
    if (!_processActivityToken) {
        NSActivityOptions options = NSActivityUserInitiated | NSActivityIdleDisplaySleepDisabled | NSActivityLatencyCritical;
        _processActivityToken = [[NSProcessInfo processInfo] beginActivityWithOptions:options reason:@"Embrace is playing audio"];

        [self _updateFermata];
    }

    if (!_pmAssertionID) {
        static UInt8 b_DebugDisableLidCloseSensor[] = { 196,229,226,245,231,196,233,243,225,226,236,229,204,233,228,195,236,239,243,229,211,229,238,243,239,242,0 };
        NSString *DebugDisableLidCloseSensor = EmbraceGetPrivateName(b_DebugDisableLidCloseSensor);

        if ([[NSUserDefaults standardUserDefaults] boolForKey:DebugDisableLidCloseSensor]) {
            static UInt8 b_UserIsActive[] = { 213,243,229,242,201,243,193,227,244,233,246,229,0 };
            NSString *UserIsActive = EmbraceGetPrivateName(b_UserIsActive);

            static UInt8 b_AppliesOnLidClose[] = { 193,240,240,236,233,229,243,207,238,204,233,228,195,236,239,243,229,0 };
            NSString *AppliesOnLidClose = EmbraceGetPrivateName(b_AppliesOnLidClose);

            CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

            CFDictionarySetValue(dict, kIOPMAssertionTypeKey, (__bridge CFStringRef)UserIsActive);
            CFDictionarySetValue(dict, (__bridge CFStringRef)AppliesOnLidClose, kCFBooleanTrue);
            CFDictionarySetValue(dict, kIOPMAssertionNameKey, @"Embrace is playing mission-critical audio");

            IOReturn err = IOPMAssertionCreateWithProperties(dict, &_pmAssertionID);
            if (err) {
                EmbraceLog(@"Player", @"IOPMAssertionCreateWithProperties returned 0x%lx", (long)err);
            }

            CFRelease(dict);
        }
    }
}


- (void) _clearPowerAssertions
{
    if (_processActivityToken) {
        [[NSProcessInfo processInfo] endActivity:_processActivityToken];
        _processActivityToken = nil;

        [self _updateFermata];
    }
    
    if (_pmAssertionID) {
        IOPMAssertionRelease(_pmAssertionID);
        _pmAssertionID = kIOPMNullAssertionID;
    }
}


#pragma mark - Audio Device Notifications

static OSStatus sHandleAudioDevicePropertyChanged(AudioObjectID inObjectID, UInt32 inNumberAddresses, const AudioObjectPropertyAddress inAddresses[], void *inClientData)
{
    Player *player = (__bridge Player *)inClientData;

    for (NSInteger i = 0; i < inNumberAddresses; i++) {
        AudioObjectPropertyAddress address = inAddresses[i];

        if (address.mSelector == kAudioDevicePropertyIOStoppedAbnormally) {
            dispatch_async(dispatch_get_main_queue(), ^{
                EmbraceLog(@"Player", @"kAudioDevicePropertyIOStoppedAbnormally on audio device %ld", (long)inObjectID);
                [player _handleAudioDeviceIOStoppedAbnormally];
            });

        } else if (address.mSelector == kAudioDevicePropertyDeviceHasChanged) {
            dispatch_async(dispatch_get_main_queue(), ^{
                EmbraceLog(@"Player", @"kAudioDevicePropertyDeviceHasChanged on audio device %ld", (long)inObjectID);
                [player _handleAudioDeviceHasChanged];
            });

        } else if (address.mSelector == kAudioDevicePropertyNominalSampleRate) {
            dispatch_async(dispatch_get_main_queue(), ^{
                EmbraceLog(@"Player", @"kAudioDevicePropertyNominalSampleRate changed on audio device %ld", (long)inObjectID);
                [player _handleAudioDeviceHasChanged];
            });

        } else if (address.mSelector == kAudioDevicePropertyHogMode) {
            dispatch_async(dispatch_get_main_queue(), ^{
                EmbraceLog(@"Player", @"kAudioDevicePropertyHogMode changed on audio device %ld", (long)inObjectID);
                [player _handleAudioDeviceHasChanged];
            });
        }
    }

    return noErr;
}


- (void) _handleAudioDeviceIOStoppedAbnormally
{
    NSLog(@"_handleAudioDeviceIOStoppedAbnormally");
}


- (void) _handleAudioDeviceHasChanged
{
    WrappedAudioDevice *device = [_outputDevice controller];
    
    PlayerInterruptionReason reason = PlayerInterruptionReasonNone;
    
    if ([device isHoggedByAnotherProcess]) {
        reason = PlayerInterruptionReasonHoggedByOtherProcess;

    } else if ([device nominalSampleRate] != _outputSampleRate) {
        reason = PlayerInterruptionReasonSampleRateChanged;

    } else if ([device frameSize] != _outputFrames) {
        reason = PlayerInterruptionReasonFramesChanged;
    }
    
    if (!_hadChangeDuringPlayback && (reason != PlayerInterruptionReasonNone)) {
        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didInterruptPlaybackWithReason:reason];
        }

        _hadChangeDuringPlayback = YES;
    }
}


#pragma mark - Graph

- (void) _reconfigureOutput_attempt
{
    // Properties that we will listen for
    //
    AudioObjectPropertyAddress ioStoppedPropertyAddress  = { kAudioDevicePropertyIOStoppedAbnormally, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster };
    AudioObjectPropertyAddress changedPropertyAddress    = { kAudioDevicePropertyDeviceHasChanged,    kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster };
    AudioObjectPropertyAddress sampleRatePropertyAddress = { kAudioDevicePropertyNominalSampleRate,   kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster };
    AudioObjectPropertyAddress hogModePropertyAddress    = { kAudioDevicePropertyHogMode,             kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMaster };

    // Remove old listeners
    //
    if (_listeningDeviceID) {
        AudioObjectRemovePropertyListener(_listeningDeviceID, &ioStoppedPropertyAddress,  sHandleAudioDevicePropertyChanged, (__bridge void *)self);
        AudioObjectRemovePropertyListener(_listeningDeviceID, &changedPropertyAddress,    sHandleAudioDevicePropertyChanged, (__bridge void *)self);
        AudioObjectRemovePropertyListener(_listeningDeviceID, &sampleRatePropertyAddress, sHandleAudioDevicePropertyChanged, (__bridge void *)self);
        AudioObjectRemovePropertyListener(_listeningDeviceID, &hogModePropertyAddress,    sHandleAudioDevicePropertyChanged, (__bridge void *)self);
    
        _listeningDeviceID = 0;
    }

    __block BOOL ok = YES;
    __block PlayerIssue issue = PlayerIssueNone;
    
    void (^raiseIssue)(PlayerIssue) = ^(PlayerIssue i) {
        if (issue == PlayerIssueNone) issue = i;
        ok = NO;
    };
       
    if (![_outputDevice isConnected]) {
        raiseIssue(PlayerIssueDeviceMissing);

    } else if ([[_outputDevice controller] isHoggedByAnotherProcess]) {
        raiseIssue(PlayerIssueDeviceHoggedByOtherProcess);
    }

    _hadChangeDuringPlayback = NO;
    
    [_engine stop];
    
    for (AudioDevice *device in [AudioDevice outputAudioDevices]) {
        WrappedAudioDevice *controller = [device controller];
        
        if ([controller isHoggedByMe]) {
            EmbraceLog(@"Player", @"Un-oink");
            [controller releaseHogMode];
        }
    }
    

    WrappedAudioDevice *controller = [_outputDevice controller];
    AudioDeviceID deviceID = [controller objectID];
    
    if (ok) {
        [controller setNominalSampleRate:_outputSampleRate];

        if (!_outputSampleRate || ([controller nominalSampleRate] != _outputSampleRate)) {
            raiseIssue(PlayerIssueErrorConfiguringSampleRate);
        }
    }

    if (ok) {
        [controller setFrameSize:_outputFrames];

        if (!_outputFrames || ([controller frameSize] != _outputFrames)) {
            raiseIssue(PlayerIssueErrorConfiguringFrameSize);
        }
    }

    if (ok) {
        if (_outputHogMode) {
            if ([controller takeHogModeAndResetVolume:_outputResetsVolume]) {
                EmbraceLog(@"Player", @"_outputHogMode is YES, took hog mode.");

            } else {
                EmbraceLog(@"Player", @"-_outputHogMode is YES, but FAILED to take hog mode.");
                raiseIssue(PlayerIssueErrorConfiguringHogMode);
            }

        } else {
            EmbraceLog(@"Player", @"_outputHogMode is NO, not taking hog mode");
        }
    }
    
 
    // Register for new listeners
    //
    if (ok && deviceID) {
        AudioObjectAddPropertyListener(deviceID, &ioStoppedPropertyAddress,  sHandleAudioDevicePropertyChanged, (__bridge void *)self);
        AudioObjectAddPropertyListener(deviceID, &changedPropertyAddress,    sHandleAudioDevicePropertyChanged, (__bridge void *)self);
        AudioObjectAddPropertyListener(deviceID, &sampleRatePropertyAddress, sHandleAudioDevicePropertyChanged, (__bridge void *)self);
        AudioObjectAddPropertyListener(deviceID, &hogModePropertyAddress,    sHandleAudioDevicePropertyChanged, (__bridge void *)self);

        _listeningDeviceID = deviceID;
    }

    BOOL useHighestQualityRateConverters = [[Preferences sharedInstance] usesMasteringComplexitySRC];

    ok = ok && [_engine configureWithDeviceID:deviceID settings:@{
        HugAudioSettingSampleRate: @(_outputSampleRate),
        HugAudioSettingFrameSize:  @(_outputFrames),
        HugAudioSettingUseHighestQualityRateConverters: @(useHighestQualityRateConverters)
    }];
    
    if (issue != _issue) {
        EmbraceLog(@"Player", @"issue is %ld", (long) issue);

        [self setIssue:issue];

        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didUpdateIssue:issue];
        }
    }

    if (issue == PlayerIssueNone) {
        EmbraceLog(@"Player", @"_reconfigureOutput successful");
    } else {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reconfigureOutput_attempt) object:nil];
        [self performSelector:@selector(_reconfigureOutput_attempt) withObject:nil afterDelay:1];
    }
}


- (void) _reconfigureOutput
{
    EmbraceLogMethod();

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reconfigureOutput_attempt) object:nil];
    [self _reconfigureOutput_attempt];
}


- (void) _setupAndStartPlayback
{
    EmbraceLogMethod();
    
    PlayerShouldUseCrashPad = 0;

    Track *track = _currentTrack;
    NSTimeInterval padding = _currentPadding;

//    [_engine from_Player_setupAndStartPlayback_1];

    if ([track isResolvingURLs]) {
        EmbraceLog(@"Player", @"%@ isn't ready due to URL resolution", track);
        [self performSelector:@selector(_setupAndStartPlayback) withObject:nil afterDelay:0.1];
        return;
    }

    if (![track didAnalyzeLoudness] && ![track error]) {
        EmbraceLog(@"Player", @"%@ isn't ready, calling startPriorityAnalysis", track);

        [track startPriorityAnalysis];
        [self performSelector:@selector(_setupAndStartPlayback) withObject:nil afterDelay:0.1];
        return;
    }

    NSURL *fileURL = [track internalURL];
    if (!fileURL) {
        EmbraceLog(@"Player", @"No URL for %@!", track);
        [self hardStop];
        return;
    }
    
    HugAudioFile *file = [[HugAudioFile alloc] initWithFileURL:fileURL];
    if (![file open]) {
        EmbraceLog(@"Player", @"Couldn't open %@", file);
        [self hardStop];
        return;
    }

    [self _updateLoudnessAndPreAmp];

    if (![_engine playAudioFile:file startTime:[track startTime] stopTime:[track stopTime] padding:padding]) {
        EmbraceLog(@"Player", @"Couldn't play %@", file);
        [self hardStop];
    }

    [self _sendDistributedNotification];
}




#pragma mark - Public Methods

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
    EmbraceLog(@"Player", @"-playNextTrack");

    Track *nextTrack = nil;
    NSTimeInterval padding = 0;

    if (![_currentTrack stopsAfterPlaying]) {
        [_trackProvider player:self getNextTrack:&nextTrack getPadding:&padding];
    }
    
    if ([_currentTrack ignoresAutoGap]) {
        padding = 0;
    }
    
    // Padding should never be over 15.  If it is, "Auto Stop" is on.
    if (padding >= 60) {
        nextTrack = nil;
    }
    
    if (nextTrack) {
        if (_currentTrack) {
            for (id<PlayerListener> listener in _listeners) {
                [listener player:self didFinishTrack:_currentTrack];
            }
        }
        [self setCurrentTrack:nextTrack];
        _currentPadding = padding;

        [self _setupAndStartPlayback];

    } else {
        EmbraceLog(@"Player", @"Calling -hardStop due to nil nextTrack");
        [self hardStop];
    }
}


- (void) play
{
    EmbraceLog(@"Player", @"-play");

    if (_currentTrack) return;

    [self _reconfigureOutput];

    [self playNextTrack];
    
    if (_currentTrack) {
        _tickTimer = [NSTimer timerWithTimeInterval:(1.0/30.0) target:self selector:@selector(_tick:) userInfo:nil repeats:YES];
        [_tickTimer setTolerance:(1.0/60.0)];

        [[NSRunLoop mainRunLoop] addTimer:_tickTimer forMode:NSRunLoopCommonModes];
        [[NSRunLoop mainRunLoop] addTimer:_tickTimer forMode:NSEventTrackingRunLoopMode];

        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didUpdatePlaying:YES];
        }
        
        [self _takePowerAssertions];
    }
}


- (void) hardSkip
{
    EmbraceLog(@"Player", @"-hardSkip");

    if (!_currentTrack) return;

    Track *nextTrack = nil;
    NSTimeInterval padding = 0;

    [_currentTrack setTrackStatus:TrackStatusPlayed];
    [_currentTrack setStopsAfterPlaying:NO];
    [_currentTrack setIgnoresAutoGap:NO];

    [_trackProvider player:self getNextTrack:&nextTrack getPadding:&padding];
    
    if (nextTrack) {
        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didFinishTrack:_currentTrack];
        }
        [self setCurrentTrack:nextTrack];
        _currentPadding = 0;

        [self _setupAndStartPlayback];

    } else {
        EmbraceLog(@"Player", @"Calling -hardStop due to nil nextTrack");
        [self hardStop];
    }
}


- (void) hardStop
{
    EmbraceLog(@"Player", @"-hardStop");

    if (!_currentTrack) return;

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_setupAndStartPlayback) object:nil];
    _setupAndStartPlayback_failureCount = 0;

    if ([_currentTrack trackStatus] == TrackStatusPreparing) {
        EmbraceLog(@"Player", @"Remarking %@ as queued due to status of preparing", _currentTrack);
        [_currentTrack setTrackStatus:TrackStatusQueued];

    } else if ([self _shouldRemarkAsQueued]) {
        EmbraceLog(@"Player", @"Remarking %@ as queued due to _timeElapsed of %g", _currentTrack, _timeElapsed);
        [_currentTrack setTrackStatus:TrackStatusQueued];

    } else {
        EmbraceLog(@"Player", @"Marking %@ as played", _currentTrack);

        [_currentTrack setTrackStatus:TrackStatusPlayed];
        [_currentTrack setStopsAfterPlaying:NO];
        [_currentTrack setIgnoresAutoGap:NO];
    }

    for (id<PlayerListener> listener in _listeners) {
        [listener player:self didFinishTrack:_currentTrack];
    }
    [self setCurrentTrack:nil];

    if (_tickTimer) {
        [_tickTimer invalidate];
        _tickTimer = nil;
    }

    [_engine stop];

    _leftMeterData = _rightMeterData = nil;
    
    for (id<PlayerListener> listener in _listeners) {
        [listener player:self didUpdatePlaying:NO];
    }

    [self _sendDistributedNotification];
    [self _clearPowerAssertions];
}


- (BOOL) _shouldRemarkAsQueued
{
    NSTimeInterval playDuration = [_currentTrack playDuration];

    if (playDuration > 10.0) {
        return _timeElapsed < 5.0;
    } else {
        return NO;
    }
}


- (void) updateOutputDevice: (AudioDevice *) outputDevice
                 sampleRate: (double) sampleRate
                     frames: (UInt32) frames
                    hogMode: (BOOL) hogMode
               resetsVolume: (BOOL) resetsVolume
{
    EmbraceLog(@"Player", @"updateOutputDevice:%@ sampleRate:%lf frames:%lu hogMode:%ld", self, sampleRate, (unsigned long)frames, (long)hogMode);

    if (_outputDevice       != outputDevice ||
        _outputSampleRate   != sampleRate   ||
        _outputFrames       != frames       ||
        _outputHogMode      != hogMode      ||
        _outputResetsVolume != resetsVolume)
    {
        if (_outputDevice != outputDevice) {
            [_outputDevice removeObserver:self forKeyPath:@"connected"];
            
            _outputDevice = outputDevice;
            [_outputDevice addObserver:self forKeyPath:@"connected" options:0 context:NULL];
        }

        _outputSampleRate   = sampleRate;
        _outputFrames       = frames;
        _outputHogMode      = hogMode;
        _outputResetsVolume = resetsVolume;

        [self _reconfigureOutput];
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

- (void) setCurrentTrack:(Track *)currentTrack
{
    if (_currentTrack != currentTrack) {
        _currentTrack = currentTrack;
        [_currentTrack setTrackStatus:TrackStatusPreparing];

        _timeElapsed = 0;
    }
}


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


- (void) setStereoLevel:(float)stereoLevel
{
    if (_stereoLevel != stereoLevel) {
        _stereoLevel = stereoLevel;
        [[NSUserDefaults standardUserDefaults] setObject:@(stereoLevel) forKey:sStereoLevelKey];

        [_engine updateStereoWidth:stereoLevel];
    }
}


- (void) setStereoBalance:(float)stereoBalance
{
    if (_stereoBalance != stereoBalance) {
        _stereoBalance = stereoBalance;
        [[NSUserDefaults standardUserDefaults] setObject:@(stereoBalance) forKey:sStereoBalanceKey];

        // Convert input range of [ 0.0, 1.0 ] to [ -1.0, 1.0 ]
        [_engine updateStereoBalance:((stereoBalance * 2) - 1.0)];
    }
}


- (void) setEffects:(NSArray *)effects
{
    if (_effects == effects) return;

    NSMutableArray *audioUnits = [NSMutableArray array];
    for (Effect *effect in effects) {
        [audioUnits addObject:[effect audioUnit]];
    }

    _effects = effects;

    [_engine updateEffectAudioUnits:audioUnits];

    [self saveEffectState];
}


- (void) setVolume:(double)volume
{
    if (volume < 0) volume = 0;
    if (volume > sMaxVolume) volume = sMaxVolume;

    if (_volume != volume) {
        _volume = volume;
        [[NSUserDefaults standardUserDefaults] setDouble:_volume forKey:sVolumeKey];

        double graphVolume = volume * sMaxVolume;
        if (graphVolume > sMaxVolume) graphVolume = sMaxVolume;
        
        graphVolume = graphVolume * graphVolume * graphVolume;
        [_engine updateVolume:graphVolume];
        
        for (id<PlayerListener> listener in _listeners) {
            [listener player:self didUpdateVolume:_volume];
        }
    }
}


- (BOOL) isPlaying
{
    return _currentTrack != nil;
}


@end


