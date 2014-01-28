//
//  Track.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TrackData;

typedef NS_ENUM(NSInteger, TrackStatus) {
    TrackStatusQueued,  // Track is queued
    TrackStatusPlaying, // Track is active
    TrackStatusPlayed   // Track was played
};


typedef NS_ENUM(NSInteger, TrackType) {
    TrackTypeAudioFile,
    TrackTypeSilence
};


@interface Track : NSObject

+ (instancetype) trackWithStateDictionary:(NSDictionary *)state;

+ (instancetype) trackWithFileURL:(NSURL *)url;
- (id) initWithFileURL:(NSURL *)url;

- (NSDictionary *) stateDictionary;
- (TrackData *) trackData;

- (BOOL) isSilentAtOffset:(NSTimeInterval)offset;

@property (nonatomic, readonly) TrackType trackType;
@property (nonatomic, readonly) NSURL *fileURL;

// Read/Write
@property (nonatomic) TrackStatus trackStatus;
@property (nonatomic) BOOL pausesAfterPlaying;

// Metadata
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *artist;
@property (nonatomic, readonly) NSTimeInterval startTime;
@property (nonatomic, readonly) NSTimeInterval stopTime;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval playDuration;
@property (nonatomic, readonly) NSTimeInterval silenceAtStart;
@property (nonatomic, readonly) NSTimeInterval silenceAtEnd;
@property (nonatomic, readonly) Tonality tonality;

@end


@interface SilentTrack : Track
+ (instancetype) silenceTrack;
@property (nonatomic) NSTimeInterval duration;
@end

