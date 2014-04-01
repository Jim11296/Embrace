//
//  player.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PlayerListener, PlayerTrackProvider;
@class Player, Track, Effect, AudioDevice;

typedef NS_ENUM(NSInteger, PlayerIssue) {
    PlayerIssueNone = 0,
    PlayerIssueDeviceMissing,
    PlayerIssueDeviceHoggedByOtherProcess,
    PlayerIssueErrorConfiguringOutputDevice
};

typedef NS_ENUM(NSInteger, PlayerInterruptionReason) {
    PlayerInterruptionReasonNone = 0,
    PlayerInterruptionReasonFramesChanged,
    PlayerInterruptionReasonSampleRateChanged,
    PlayerInterruptionReasonChannelLayoutChanged,
    PlayerInterruptionReasonHoggedByOtherProcess
};



typedef NS_ENUM(NSInteger, PlayerStatus) {
    PlayerStatusPaused = 0,
    PlayerStatusPlaying
};


extern volatile NSInteger PlayerShouldUseCrashPad;

@interface Player : NSObject

+ (instancetype) sharedInstance;

- (void) play;
- (void) hardSkip;
- (void) hardStop;

- (BOOL) isAtBeginningOfSong;

@property (nonatomic) double volume;

@property (nonatomic, strong) NSArray *effects;
- (AudioUnit) audioUnitForEffect:(Effect *)effect;
- (void) saveEffectState;

@property (nonatomic) double matchLoudnessLevel;
@property (nonatomic) double preAmpLevel;

@property (nonatomic) float stereoLevel;   // -1.0 = Reverse, 0.0 = Mono, +1.0 = Stereo
@property (nonatomic) float stereoBalance; // -1.0 = Left,                +1.0 = Right


- (void) updateOutputDevice: (AudioDevice *) outputDevice
                 sampleRate: (double) sampleRate
                     frames: (UInt32) frames
                    hogMode: (BOOL) hogMode;

@property (nonatomic, readonly) AudioDevice *outputDevice;
@property (nonatomic, readonly) double outputSampleRate;
@property (nonatomic, readonly) UInt32 outputFrames;
@property (nonatomic, readonly) BOOL outputHogMode;

// KVO-Observable
@property (nonatomic, readonly) Track *currentTrack;
@property (nonatomic, readonly) NSString *timeElapsedString;
@property (nonatomic, readonly) NSString *timeRemainingString;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) float percentage;
@property (nonatomic, readonly) PlayerIssue issue;

// Playback properties
@property (nonatomic, readonly) NSTimeInterval timeElapsed;
@property (nonatomic, readonly) NSTimeInterval timeRemaining;
@property (nonatomic, readonly) Float32 leftAveragePower;
@property (nonatomic, readonly) Float32 rightAveragePower;
@property (nonatomic, readonly) Float32 leftPeakPower;
@property (nonatomic, readonly) Float32 rightPeakPower;
@property (nonatomic, readonly, getter=isLimiterActive) BOOL limiterActive;

- (void) addListener:(id<PlayerListener>)listener;
- (void) removeListener:(id<PlayerListener>)listener;

@property (nonatomic, weak) id<PlayerTrackProvider> trackProvider;

@end

@protocol PlayerListener <NSObject>
- (void) player:(Player *)player didUpdatePlaying:(BOOL)playing;
- (void) player:(Player *)player didUpdateIssue:(PlayerIssue)issue;
- (void) player:(Player *)player didUpdateVolume:(double)volume;
- (void) player:(Player *)player didInterruptPlaybackWithReason:(PlayerInterruptionReason)reason;
- (void) playerDidTick:(Player *)player;
@end

@protocol PlayerTrackProvider <NSObject>
- (void) player:(Player *)player getNextTrack:(Track **)outNextTrack getPadding:(NSTimeInterval *)outPadding;
@end

