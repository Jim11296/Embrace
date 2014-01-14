//
//  Track.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Track.h"
#import "iTunesManager.h"

#import <AVFoundation/AVFoundation.h>

static NSString * const sStatusKey      = @"status";
static NSString * const sBookmarkKey    = @"bookmark";
static NSString * const sArtistKey      = @"artist";
static NSString * const sTitleKey       = @"title";
static NSString * const sStartTimeKey   = @"start-time";
static NSString * const sStopTimeKey    = @"stop-time";
static NSString * const sDurationKey    = @"duration";
static NSString * const sPlayOffsetKey  = @"play-offset";
static NSString * const sPadOffsetKey   = @"pad-offset";
static NSString * const sPadDurationKey = @"pad-duration";
static NSString * const sPausesKey      = @"pauses";
static NSString * const sTypeKey        = @"type";


@interface Track ()
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *artist;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval playOffset;
@property (nonatomic) NSTimeInterval padOffset;
@property (nonatomic) NSTimeInterval padDuration;
@property (nonatomic) Float32 leftAveragePower;
@property (nonatomic) Float32 rightAveragePower;
@property (nonatomic) Float32 leftPeakPower;
@property (nonatomic) Float32 rightPeakPower;
@property (nonatomic) TrackStatus trackStatus;
@property (nonatomic) TrackType trackType;
@property (nonatomic) BOOL pausesAfterPlaying;
@end


@implementation Track {
    NSData *_bookmark;
    AVAsset *_asset;
}

@dynamic padRemaining, playRemaining, playDuration;
@dynamic padOffsetString, padDurationString, padRemainingString;
@dynamic playOffsetString, playDurationString, playRemainingString;
@dynamic silenceDuration;

+ (NSSet *) keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    NSArray *affectingKeys = nil;
 
    if ([key isEqualToString:@"playDurationString"]) {
        affectingKeys = @[ @"playDuration", @"playOffset", @"trackStatus" ];

    } else if ([key isEqualToString:@"playDuration"]) {
        affectingKeys = @[ @"duration", @"stopTime", @"startTime" ];

    } else if ([key isEqualToString:@"silenceDurationEditable"]) {
        affectingKeys = @[ @"trackStatus", @"trackType" ];

    } else if ([key isEqualToString:@"silenceDurationString"]) {
        affectingKeys = @[ @"silenceDuration" ];

    } else if ([key isEqualToString:@"silenceDuration"]) {
        affectingKeys = @[ @"duration" ];
    }

    if (affectingKeys) {
        keyPaths = [keyPaths setByAddingObjectsFromArray:affectingKeys];
    }
 
    return keyPaths;
}


+ (instancetype) trackWithStateDictionary:(NSDictionary *)state
{
    return [[self alloc] initWithStateDictionary:state];
}


+ (instancetype) trackWithFileURL:(NSURL *)url
{
    return [[self alloc] initWithFileURL:url];
}


+ (instancetype) silenceTrack
{
    return [[self alloc] _initAsSilence];
}


- (id) _initWithFileURL:(NSURL *)url bookmark:(NSData *)bookmark
{
    if ((self = [super init])) {
        [self setTrackType:TrackTypeAudioFile];

        if (!bookmark) {
            NSError *error = nil;
            bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
        }

        _fileURL = url;
        _bookmark = bookmark;

        [self _startLoadingMetadata];
    }

    return self;
}


- (id) _initAsSilence
{
    if ((self = [super init])) {
        [self setTrackType:TrackTypeSilence];
        [self setTitle:NSLocalizedString(@"Silence", nil)];
        [self setDuration:5];
    }
    
    return self;
}


- (id) initWithStateDictionary:(NSDictionary *)state
{
    TrackType type = [[state objectForKey:sTypeKey] integerValue];
    
    if (type == TrackTypeAudioFile) {
        NSData *bookmark = [state objectForKey:sBookmarkKey];
        
        NSURLBookmarkResolutionOptions options = NSURLBookmarkResolutionWithoutUI|NSURLBookmarkResolutionWithSecurityScope;
        
        BOOL isStale = NO;
        NSError *error = nil;
        NSURL *url = [NSURL URLByResolvingBookmarkData: bookmark
                                               options: options
                                         relativeToURL: nil
                                   bookmarkDataIsStale: &isStale
                                                 error: &error];

        if (!url) {
            self = nil;
            return nil;
        }

        if (isStale) {
            [url startAccessingSecurityScopedResource];
            bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
            [url stopAccessingSecurityScopedResource];
        }

        self = [self _initWithFileURL:url bookmark:bookmark];

    } else if (type == TrackTypeSilence) {
        self = [self _initAsSilence];

    } else {
        self = nil;
        return nil;
    }
    
    if (self) {
        [self _loadState:state];
    }
    
    return self;
}


- (id) initWithFileURL:(NSURL *)url
{
    return [self _initWithFileURL:url bookmark:nil];
}


- (void) _loadState:(NSDictionary *)state
{
    NSString *artist      = [state objectForKey:sArtistKey];
    NSString *title       = [state objectForKey:sTitleKey];
    NSNumber *startTime   = [state objectForKey:sStartTimeKey];
    NSNumber *stopTime    = [state objectForKey:sStopTimeKey];
    NSNumber *duration    = [state objectForKey:sDurationKey];
    NSNumber *trackStatus = [state objectForKey:sStatusKey];
    NSNumber *playOffset  = [state objectForKey:sPlayOffsetKey];
    NSNumber *padOffset   = [state objectForKey:sPadOffsetKey];
    NSNumber *padDuration = [state objectForKey:sPadDurationKey];
    NSNumber *pauses      = [state objectForKey:sPausesKey];

    if (artist)      [self setArtist:artist];
    if (title)       [self setTitle:title];
    if (startTime)   [self setStartTime:  [startTime   doubleValue]];
    if (stopTime)    [self setStopTime:   [stopTime    doubleValue]];
    if (duration)    [self setDuration:   [duration    doubleValue]];
    if (trackStatus) [self setTrackStatus:[trackStatus integerValue]];
    if (playOffset)  [self setPlayOffset: [playOffset  doubleValue]];
    if (padOffset)   [self setPadOffset:  [padOffset   doubleValue]];
    if (padDuration) [self setPadDuration:[padDuration doubleValue]];
    if (pauses)      [self setPausesAfterPlaying:[pauses boolValue]];
}


- (void) _stopLoadingMetadata
{
    if (_asset) {
        _asset = nil;
        [_fileURL stopAccessingSecurityScopedResource];
    }
}


- (void) _startLoadingMetadata
{
    __weak id weakSelf = self;

    NSString *fallbackTitle = [[_fileURL lastPathComponent] stringByDeletingPathExtension];

    _asset = _fileURL ? [[AVURLAsset alloc] initWithURL:_fileURL options:@{
        AVURLAssetPreferPreciseDurationAndTimingKey: @YES
    }] : nil;

    if (_asset) {
        [_fileURL startAccessingSecurityScopedResource];
    }

    __weak AVAsset *weakAsset = _asset;
    [_asset loadValuesAsynchronouslyForKeys:@[ @"commonMetadata" ] completionHandler:^{
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

        NSError *error;
        AVKeyValueStatus metadataStatus = [weakAsset statusOfValueForKey:@"commonMetadata" error:&error];
        AVKeyValueStatus durationStatus = [weakAsset statusOfValueForKey:@"duration"       error:&error];

        if (metadataStatus == AVKeyValueStatusLoaded) {
            NSArray *metadata = [weakAsset commonMetadata];

            for (AVMetadataItem *item in metadata) {
                NSString *key   = [item commonKey];
              
                if ([key isEqualToString:@"artist"]) {
                    [dictionary setObject:[item stringValue] forKey:sArtistKey];
                } else if ([key isEqualToString:@"title"]) {
                    [dictionary setObject:[item stringValue] forKey:sTitleKey];
                }
            }

            if (![dictionary objectForKey:sTitleKey]) {
                [dictionary setObject:fallbackTitle forKey:sTitleKey];
            }
        }

        if (durationStatus == AVKeyValueStatusLoaded) {
            NSTimeInterval duration = CMTimeGetSeconds([weakAsset duration]);
            [dictionary setObject:@(duration) forKey:sDurationKey];
        }
        
        [weakSelf _loadState:dictionary];
        
        if (metadataStatus == AVKeyValueStatusLoaded && durationStatus == AVKeyValueStatusLoaded) {
            [self _stopLoadingMetadata];
        }
    }];
    
    iTunesManager *manager = [iTunesManager sharedInstance];

    void (^callback)() = ^{
        NSInteger trackID = [manager trackIDForURL:_fileURL];
    
        NSTimeInterval startTime = 0;
        [manager getStartTime:&startTime forTrack:trackID];
        [self setStartTime:startTime];

        NSTimeInterval stopTime = 0;
        [manager getStopTime:&stopTime forTrack:trackID];
        [self setStopTime:stopTime];
    };

    if ([manager isReady]) {
        callback();
    } else {
        [manager addReadyCallback:callback];
    }
}


- (NSString *) _stringForTime:(NSTimeInterval)time minus:(BOOL)minus
{
    double seconds = round(fmod(time, 60.0));
    double minutes = floor(time / 60.0);

    return [NSString stringWithFormat:@"%s%g:%02g", minus ? "-" : "", minutes, seconds];
}


- (void) updateTrackStatus: (TrackStatus) status
                 padOffset: (NSTimeInterval) padOffset
                playOffset: (NSTimeInterval) playOffset
          leftAveragePower: (Float32) leftAveragePower
         rightAveragePower: (Float32) rightAveragePower
             leftPeakPower: (Float32) leftPeakPower
            rightPeakPower: (Float32) rightPeakPower
{
    NSTimeInterval playDuration = [self playDuration];

    if (padOffset  > _padDuration) padOffset  = _padDuration;
    if (playOffset > playDuration) playOffset = playDuration;

    [self setPadOffset:padOffset];
    [self setPlayOffset:playOffset];   
    [self setTrackStatus:status];
    
    [self setLeftAveragePower:leftAveragePower];
    [self setRightAveragePower:rightAveragePower];
    [self setLeftPeakPower:leftPeakPower];
    [self setRightPeakPower:rightPeakPower];
}


- (NSDictionary *) stateDictionary
{
    NSMutableDictionary *state = [NSMutableDictionary dictionary];

    if (_bookmark)    [state setObject:_bookmark       forKey:sBookmarkKey];
    if (_artist)      [state setObject:_artist         forKey:sArtistKey];
    if (_title)       [state setObject:_title          forKey:sTitleKey];
    if (_trackStatus) [state setObject:@(_trackStatus) forKey:sStatusKey];
    if (_startTime)   [state setObject:@(_startTime)   forKey:sStartTimeKey];
    if (_stopTime)    [state setObject:@(_stopTime)    forKey:sStopTimeKey];
    if (_duration)    [state setObject:@(_duration)    forKey:sDurationKey];
    if (_playOffset)  [state setObject:@(_playOffset)  forKey:sPlayOffsetKey];
    if (_padOffset)   [state setObject:@(_padOffset)   forKey:sPadOffsetKey];
    if (_padDuration) [state setObject:@(_padDuration) forKey:sPadDurationKey];
    if (_trackType)   [state setObject:@(_trackType)   forKey:sTypeKey];

    if (_pausesAfterPlaying) {
        [state setObject:@YES forKey:sPausesKey];
    }

    return state;
}

#pragma mark - Accessors

- (void) updateDuration:(NSTimeInterval)duration
{
    if (_trackType == TrackTypeSilence) {
        [self setDuration:duration];
    }
}


- (void) updatePausesAfterPlaying:(BOOL)pausesAfterPlaying
{
    [self setPausesAfterPlaying:pausesAfterPlaying];
}


- (NSTimeInterval) padRemaining
{
    return [self padDuration] - _padOffset;
}


- (NSTimeInterval) playRemaining
{
    return [self playDuration] - _playOffset;
}


- (NSTimeInterval) playDuration
{
    NSTimeInterval stopTime = _stopTime ? _stopTime : _duration;
    return stopTime - _startTime;
}


- (void) setSilenceDuration:(NSTimeInterval)silenceDuration
{
    [self setDuration:silenceDuration];
}


- (NSTimeInterval) silenceDuration
{
    return [self duration];
}


- (BOOL) isSilenceDurationEditable
{
    return [self trackStatus] == TrackStatusQueued &&
           [self trackType] == TrackTypeSilence;
}


- (NSString *) playOffsetString    { return [self _stringForTime:[self playOffset]    minus:NO ]; }
- (NSString *) playDurationString  { return [self _stringForTime:[self playDuration]  minus:NO ]; }
- (NSString *) playRemainingString { return [self _stringForTime:[self playRemaining] minus:YES]; }

- (NSString *) padOffsetString     { return [self _stringForTime:[self padOffset]     minus:NO ]; }
- (NSString *) padDurationString   { return [self _stringForTime:[self padDuration]   minus:NO ]; }
- (NSString *) padRemainingString  { return [self _stringForTime:[self padRemaining]  minus:YES]; }

- (NSString *) silenceDurationString { return [self _stringForTime:[self silenceDuration]  minus:NO]; }


@end
