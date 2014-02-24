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


typedef NS_ENUM(NSInteger, PlayerStatus) {
    PlayerStatusPaused = 0,
    PlayerStatusPlaying
};


extern volatile NSInteger PlayerShouldUseCrashPad;

@interface Player : NSObject

+ (instancetype) sharedInstance;

- (void) playOrSoftPause;

- (void) play;
- (void) softPause;
- (void) hardSkip;
- (void) hardStop;

@property (nonatomic) double volume;

@property (nonatomic, strong) NSArray *effects;
- (AudioUnit) audioUnitForEffect:(Effect *)effect;
- (void) saveEffectState;

@property (nonatomic, strong) NSArray *debugInternalEffects;

@property (nonatomic) double matchLoudnessLevel;
@property (nonatomic) double preAmpLevel;

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
- (void) playerDidTick:(Player *)player;
@end

@protocol PlayerTrackProvider <NSObject>

- (void) player:(Player *)player getNextTrack:(Track **)outNextTrack getPadding:(NSTimeInterval *)outPadding;
@end

