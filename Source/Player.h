//
//  player.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PlayerDelegate;
@class Track, Effect, AudioDevice;

typedef NS_ENUM(NSInteger, PlayerStatus) {
    PlayerStatusPaused = 0,
    PlayerStatusPlaying
};


@interface Player : NSObject

+ (instancetype) sharedInstance;

- (void) play;
- (void) softPause;
- (void) hardPause;

- (BOOL) isPlaying;

- (BOOL) canPlay;
- (BOOL) canPause;

@property (nonatomic) double volume;

@property (nonatomic, strong) NSArray *effects;
- (AudioUnit) audioUnitForEffect:(Effect *)effect;

@property (nonatomic, readonly) Track *currentTrack;

@property (nonatomic, weak) id<PlayerDelegate> delegate;

- (void) updateOutputDevice: (AudioDevice *) outputDevice
                 sampleRate: (double) sampleRate
                     frames: (UInt32) frames
                    hogMode: (BOOL) hogMode;

@property (nonatomic, readonly) AudioDevice *outputDevice;
@property (nonatomic, readonly) double sampleRate;
@property (nonatomic, readonly) UInt32 frames;
@property (nonatomic, readonly) BOOL hogMode;


@end


@protocol PlayerDelegate <NSObject>
- (void) playerDidUpdate:(Player *)player;
- (Track *) playerNextTrack:(Player *)player;
@end
