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


typedef NS_ENUM(NSInteger, PlayerStatus) {
    PlayerStatusPaused = 0,
    PlayerStatusPlaying
};


@interface Player : NSObject

+ (instancetype) sharedInstance;

- (void) playOrSoftPause;

- (void) play;
- (void) softPause;
- (void) hardSkip;
- (void) hardPause;

@property (nonatomic) double volume;

@property (nonatomic, strong) NSArray *effects;
- (AudioUnit) audioUnitForEffect:(Effect *)effect;

- (void) updateOutputDevice: (AudioDevice *) outputDevice
                 sampleRate: (double) sampleRate
                     frames: (UInt32) frames
                    hogMode: (BOOL) hogMode;

@property (nonatomic, readonly) AudioDevice *outputDevice;
@property (nonatomic, readonly) double sampleRate;
@property (nonatomic, readonly) UInt32 frames;
@property (nonatomic, readonly) BOOL hogMode;


// KVO-Observable
@property (nonatomic, readonly) Track *currentTrack;
@property (nonatomic, readonly) NSString *timeElapsedString;
@property (nonatomic, readonly) NSString *timeRemainingString;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) float percentage;

// Playback properties
@property (nonatomic, readonly) NSTimeInterval timeElapsed;
@property (nonatomic, readonly) NSTimeInterval timeRemaining;
@property (nonatomic, readonly) Float32 leftAveragePower;
@property (nonatomic, readonly) Float32 rightAveragePower;
@property (nonatomic, readonly) Float32 leftPeakPower;
@property (nonatomic, readonly) Float32 rightPeakPower;

- (void) addListener:(id<PlayerListener>)listener;
- (void) removeListener:(id<PlayerListener>)listener;

@property (nonatomic, weak) id<PlayerTrackProvider> trackProvider;

@end

@protocol PlayerListener <NSObject>
- (void) player:(Player *)player didUpdatePlaying:(BOOL)playing;
- (void) playerDidTick:(Player *)player;
@end

@protocol PlayerTrackProvider <NSObject>
- (void) player:(Player *)player getNextTrack:(Track **)outNextTrack getPadding:(NSTimeInterval *)outPadding;
@end

