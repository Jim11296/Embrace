//
//  Track.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVAsset;

typedef NS_ENUM(NSInteger, TrackStatus) {
    TrackStatusQueued,  // Track is queued
    TrackStatusPadding, // Track is about to be played, and we are padding silence
    TrackStatusPlaying, // Track is active
    TrackStatusPlayed   // Track was played
};

typedef NS_ENUM(NSInteger, TrackType) {
    TrackTypeAudioFile,
    TrackTypeSilence
};


@interface Track : NSObject

+ (instancetype) silenceTrack;

+ (instancetype) trackWithStateDictionary:(NSDictionary *)state;
- (id) initWithStateDictionary:(NSDictionary *)state;

+ (instancetype) trackWithFileURL:(NSURL *)url;
- (id) initWithFileURL:(NSURL *)url;

- (NSDictionary *) stateDictionary;

- (void) updatePausesAfterPlaying:(BOOL)pausesAfterPlaying;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *artist;

@property (nonatomic, readonly) NSTimeInterval startTime;
@property (nonatomic, readonly) NSTimeInterval stopTime;
@property (nonatomic, readonly) NSTimeInterval totalDuration;

@property (nonatomic, readonly) NSTimeInterval padOffset;
@property (nonatomic, readonly) NSTimeInterval padDuration;
@property (nonatomic, readonly) NSTimeInterval padRemaining;

@property (nonatomic, readonly) NSTimeInterval playOffset;
@property (nonatomic, readonly) NSTimeInterval playDuration;
@property (nonatomic, readonly) NSTimeInterval playRemaining;

@property (nonatomic, readonly) NSURL *fileURL;

@property (nonatomic, readonly) TrackStatus trackStatus;
@property (nonatomic, readonly) TrackType trackType;

@property (nonatomic, readonly) NSString *padOffsetString;
@property (nonatomic, readonly) NSString *padDurationString;
@property (nonatomic, readonly) NSString *padRemainingString;

@property (nonatomic, readonly) NSString *playOffsetString;
@property (nonatomic, readonly) NSString *playDurationString;
@property (nonatomic, readonly) NSString *playRemainingString;

@property (nonatomic, readonly) BOOL pausesAfterPlaying;

@property (nonatomic, readonly) Float32 leftAveragePower;
@property (nonatomic, readonly) Float32 rightAveragePower;
@property (nonatomic, readonly) Float32 leftPeakPower;
@property (nonatomic, readonly) Float32 rightPeakPower;

// For trackType=TrackTypeSilence only
@property (nonatomic) NSTimeInterval silenceDuration;
@property (nonatomic, readonly) NSString *silenceDurationString;
@property (nonatomic, readonly, getter=isSilenceDurationEditable) BOOL silenceDurationEditable;

@end


@interface Track (CalledByPlayer)

- (void) updateTrackStatus: (TrackStatus) status
                 padOffset: (NSTimeInterval) padOffset
                playOffset: (NSTimeInterval) playOffset
          leftAveragePower: (Float32) leftAveragePower
         rightAveragePower: (Float32) rightAveragePower
             leftPeakPower: (Float32) leftPeakPower
            rightPeakPower: (Float32) rightPeakPower;

@end
