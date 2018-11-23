//
//  AudioGraph.h
//  Embrace
//
//  Created by Ricci Adams on 2018-11-21.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class Effect, TrackScheduler;

@interface AudioGraph : NSObject

- (void) uninitializeAll;

- (void) from_Player_setupAndStartPlayback_1;
- (BOOL) from_Player_setupAndStartPlayback_2_withTrack:(Track *)track;
- (BOOL) from_Player_setupAndStartPlayback_3_withPadding:(NSTimeInterval)padding;


- (void) start;
- (void) stop;

- (void) buildTail;
- (void) reconnectGraph;


- (BOOL) configureWithDeviceID: (AudioDeviceID) deviceID
                    sampleRate: (double) sampleRate
                        frames: (UInt32) inFrames;

// Player -> Graph
- (void) updatePreGain:(float)preGain;
- (void) updateVolume:(float)volume;
- (void) updateStereoLevel:(float)stereoLevel;
- (void) updateStereoBalance:(float)stereoBalance;



- (void) updateEffects:(NSArray<Effect *> *)effects;

// Graph -> Player

@property (nonatomic, readonly) TrackScheduler *scheduler;

@property (nonatomic, readonly, getter=isRunning) BOOL running;

@property (nonatomic, readonly, getter=isLimiterActive) BOOL limiterActive;

@property (nonatomic, readonly) float leftAveragePower;
@property (nonatomic, readonly) float rightAveragePower;

@property (nonatomic, readonly) float leftPeakPower;
@property (nonatomic, readonly) float rightPeakPower;

@property (nonatomic, readonly) float dangerPeak;

@property (nonatomic, readonly) BOOL didOverload;

@end

NS_ASSUME_NONNULL_END
