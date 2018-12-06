//
//  AudioGraph.h
//  Embrace
//
//  Created by Ricci Adams on 2018-11-21.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>


@class TrackScheduler, HugMeterData;

@interface HugAudioEngine : NSObject

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

// Full-scale, linear, 1.0 = 0dBFS
- (void) updatePreGain:(float)preGain;

// Full-scale, linear, 1.0 = 0dBFS
- (void) updateVolume:(float)volume;

// -1.0 = reverse, 0.0 = mono, 1.0 = normal stereo
- (void) updateStereoWidth:(float)stereoWidth;

// -1.0 = left, 0.0 = center, 1.0 = right
- (void) updateStereoBalance:(float)stereoBalance;

- (void) updateEffectAudioUnits:(NSArray<AUAudioUnit *> *)effectAudioUnits;

// Graph -> Player

@property (nonatomic, readonly) TrackScheduler *scheduler;

@property (nonatomic, readonly, getter=isRunning) BOOL running;

@property (nonatomic, readonly) HugMeterData *leftMeterData;
@property (nonatomic, readonly) HugMeterData *rightMeterData;

@property (nonatomic, readonly) float dangerLevel;

@property (nonatomic, readonly) NSTimeInterval lastOverloadTime;

@end


