//
//  Track.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Track.h"
#import "iTunesManager.h"
#import "TrackData.h"

#import <AVFoundation/AVFoundation.h>

static NSString * const sTypeKey         = @"type";
static NSString * const sStatusKey       = @"status";
static NSString * const sBookmarkKey     = @"bookmark";
static NSString * const sPausesKey       = @"pauses";
static NSString * const sTitleKey        = @"title";
static NSString * const sArtistKey       = @"artist";
static NSString * const sStartTimeKey    = @"start-time";
static NSString * const sStopTimeKey     = @"stop-time";
static NSString * const sDurationKey     = @"duration";
static NSString * const sStartSilenceKey = @"silence-start";
static NSString * const sEndSilenceKey   = @"silence-end";
static NSString * const sTonalityKey     = @"tonality";

@interface Track ()
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *artist;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval silenceAtStart;
@property (nonatomic) NSTimeInterval silenceAtEnd;
@property (nonatomic) Tonality tonality;
@end


@interface TrackData (Private)
- (id) initWithFileURL:(NSURL *)url mixdown:(BOOL)mixdown;
@end


@implementation Track {
    NSData *_bookmark;
    NSData *_contents;
    TrackData *_trackDataForAnalysis;
}

@dynamic playDuration;


+ (NSSet *) keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    NSArray *affectingKeys = nil;
 
    if ([key isEqualToString:@"playDuration"]) {
        affectingKeys = @[ @"duration", @"stopTime", @"startTime" ];
    }

    if (affectingKeys) {
        keyPaths = [keyPaths setByAddingObjectsFromArray:affectingKeys];
    }
 
    return keyPaths;
}


+ (instancetype) trackWithStateDictionary:(NSDictionary *)state
{
    TrackType type = [[state objectForKey:sTypeKey] integerValue];
    Track *track = nil;

    if (type == TrackTypeAudioFile) {
        NSData *bookmark = [state objectForKey:sBookmarkKey];
        
        track = [[Track alloc] _initWithFileURL:nil bookmark:bookmark];

    } else if (type == TrackTypeSilence) {
        track = [[SilentTrack alloc] init];

    } else {
        return nil;
    }
    
    [track _loadState:state];

    return track;
}


+ (instancetype) trackWithFileURL:(NSURL *)url
{
    return [[self alloc] initWithFileURL:url];
}


- (id) _initWithFileURL:(NSURL *)url bookmark:(NSData *)bookmark
{
    if ((self = [super init])) {
        if (!bookmark) {
            NSError *error = nil;
            bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
        }

        NSURLBookmarkResolutionOptions options = NSURLBookmarkResolutionWithoutUI|NSURLBookmarkResolutionWithSecurityScope;
        
        BOOL isStale = NO;
        NSError *error = nil;
        url = [NSURL URLByResolvingBookmarkData: bookmark
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

        _fileURL = url;
        [_fileURL startAccessingSecurityScopedResource];

        _bookmark = bookmark;
        _contents = [NSData dataWithContentsOfURL:_fileURL options:NSDataReadingMappedAlways error:&error];
        
        [self _loadMetadataViaManager];
        [self _loadMetadataViaAsset];
        
        __weak id weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _loadMetadataViaAnalysisIfNeeded];
        });
    }

    return self;
}


- (id) initWithFileURL:(NSURL *)url
{
    return [self _initWithFileURL:url bookmark:nil];
}


- (void) dealloc
{
    [_fileURL stopAccessingSecurityScopedResource];
    _fileURL = nil;
}


- (void) _loadState:(NSDictionary *)state
{
    NSString *artist       = [state objectForKey:sArtistKey];
    NSString *title        = [state objectForKey:sTitleKey];
    NSNumber *startTime    = [state objectForKey:sStartTimeKey];
    NSNumber *stopTime     = [state objectForKey:sStopTimeKey];
    NSNumber *duration     = [state objectForKey:sDurationKey];
    NSNumber *trackStatus  = [state objectForKey:sStatusKey];
    NSNumber *startSilence = [state objectForKey:sStartSilenceKey];
    NSNumber *endSilence   = [state objectForKey:sEndSilenceKey];
    NSNumber *tonality     = [state objectForKey:sTonalityKey];
    NSNumber *pauses       = [state objectForKey:sPausesKey];

    if (artist)       [self setArtist:artist];
    if (title)        [self setTitle:title];
    if (startTime)    [self setStartTime:  [startTime   doubleValue]];
    if (stopTime)     [self setStopTime:   [stopTime    doubleValue]];
    if (duration)     [self setDuration:   [duration    doubleValue]];
    if (trackStatus)  [self setTrackStatus:[trackStatus integerValue]];

    if (startSilence) [self setSilenceAtStart:[startSilence doubleValue]];
    if (endSilence)   [self setSilenceAtEnd:  [endSilence   doubleValue]];
    if (tonality)     [self setTonality:[tonality integerValue]];

    if (pauses)       [self setPausesAfterPlaying:[pauses boolValue]];
}


#pragma mark - Metadata

- (void) _clearTrackDataForAnalysis
{
    _trackDataForAnalysis = nil;
}


- (void) _loadMetadataViaAnalysisIfNeeded
{
    if (_silenceAtEnd || _silenceAtStart) {
        return;
    }

    double threshold  = 0.03125; // -30dB
    
    _trackDataForAnalysis = [[TrackData alloc] initWithFileURL:_fileURL mixdown:YES];
    
    __weak id weakSelf = self;
    [_trackDataForAnalysis addReadyCallback:^(TrackData *trackData) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSData *data = [trackData data];

            float     *buffer = (float *)[data bytes];
            NSUInteger length = [data length] / sizeof(float);
            
            NSInteger samplesAtStart = 0;
            NSInteger samplesAtEnd   = 0;
            
            for (NSInteger i = 0; i < length; i++) {
                if (fabs(buffer[i]) > threshold) {
                    break;
                }
                
                samplesAtStart++;
            }

            for (NSInteger i = (length - 1); i >= 0; i--) {
                if (fabs(buffer[i]) > threshold) {
                    break;
                }

                samplesAtEnd++;
            }

            
            double sampleRate = [trackData streamDescription].mSampleRate;
            
            
            NSTimeInterval silenceAtStart = samplesAtStart / sampleRate;
            NSTimeInterval silenceAtEnd   = samplesAtEnd   / sampleRate;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf _loadState:@{
                    sStartSilenceKey: @(silenceAtStart),
                    sEndSilenceKey:   @(silenceAtEnd)
                }];
                
                [weakSelf _clearTrackDataForAnalysis];
            });
        });
    }];
}


- (void) _loadMetadataViaManager
{
    if (!_fileURL) {
        return;
    }

    iTunesMetadata *metadata = [[iTunesManager sharedInstance] metadataForFileURL:_fileURL];
    
    if (metadata) {
        if (!_title)    [self setTitle:[metadata title]];
        if (!_artist)   [self setArtist:[metadata artist]];
        if (!_duration) [self setDuration:[metadata duration]];
    }
    
    __weak id weakSelf = self;

    [[iTunesManager sharedInstance] addMetadataReadyCallback:^(iTunesManager *manager) {
        iTunesMetadata *loadedMetadata = [manager metadataForFileURL:_fileURL];
        
        [weakSelf setStartTime:[loadedMetadata startTime]];
        [weakSelf setStopTime:[loadedMetadata stopTime]];
    }];
}


- (void) _loadMetadataViaAsset
{
    if (!_fileURL) {
        return;
    }

    AVAsset *asset = [[AVURLAsset alloc] initWithURL:_fileURL options:@{
        AVURLAssetPreferPreciseDurationAndTimingKey: @YES
    }];

    __weak id weakSelf = self;
    __weak AVAsset *weakAsset = asset;

    NSString *fallbackTitle = [[_fileURL lastPathComponent] stringByDeletingPathExtension];

    [asset loadValuesAsynchronouslyForKeys:@[ @"commonMetadata", @"duration", @"availableMetadataFormats" ] completionHandler:^{
        AVAsset *asset = weakAsset;

        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

        NSError *error;
        AVKeyValueStatus metadataStatus = [asset statusOfValueForKey:@"commonMetadata" error:&error];
        AVKeyValueStatus durationStatus = [asset statusOfValueForKey:@"duration"       error:&error];
        AVKeyValueStatus formatsStatus  = [asset statusOfValueForKey:@"availableMetadataFormats" error:&error];

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

        if (formatsStatus == AVKeyValueStatusLoaded) {
            Tonality tonality = Tonality_Unknown;

            for (NSString *format in [asset availableMetadataFormats]) {
                NSArray *metadata = [asset metadataForFormat:format];
            
                for (AVMetadataItem *item in metadata) {
                    id key = [item key];

                    if ([key isEqual:@"com.apple.iTunes.initialkey"] && [[item value] isKindOfClass:[NSString class]]) {
                        NSString *string = (NSString *)[item value];
                        tonality = GetTonalityForString(string);
                    }
                }
            }
            
            if (tonality != Tonality_Unknown) {
                [dictionary setObject:@(tonality) forKey:sTonalityKey];
            }
        }

        if (durationStatus == AVKeyValueStatusLoaded) {
            NSTimeInterval duration = CMTimeGetSeconds([asset duration]);
            [dictionary setObject:@(duration) forKey:sDurationKey];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _loadState:dictionary];
        });
    }];
}


#pragma mark - Public Methods

- (NSDictionary *) stateDictionary
{
    NSMutableDictionary *state = [NSMutableDictionary dictionary];

    [state setObject:@([self trackType]) forKey:sTypeKey];

    if (_bookmark)       [state setObject:_bookmark             forKey:sBookmarkKey];
    if (_artist)         [state setObject:_artist               forKey:sArtistKey];
    if (_title)          [state setObject:_title                forKey:sTitleKey];
    if (_trackStatus)    [state setObject:@(_trackStatus)       forKey:sStatusKey];
    if (_startTime)      [state setObject:@(_startTime)         forKey:sStartTimeKey];
    if (_stopTime)       [state setObject:@(_stopTime)          forKey:sStopTimeKey];
    if (_duration)       [state setObject:@(_duration)          forKey:sDurationKey];
    if (_silenceAtStart) [state setObject:@(_silenceAtStart)    forKey:sStartSilenceKey];
    if (_silenceAtEnd)   [state setObject:@(_silenceAtEnd)      forKey:sEndSilenceKey];
    if (_tonality)       [state setObject:@(_tonality)          forKey:sTonalityKey];

    if (_pausesAfterPlaying) {
        [state setObject:@YES forKey:sPausesKey];
    }

    return state;
}


- (TrackData *) trackData
{
    return [[TrackData alloc] initWithFileURL:_fileURL mixdown:NO];
}


- (BOOL) isSilentAtOffset:(NSTimeInterval)offset
{
    if (offset <= [self silenceAtStart]) {
        return YES;
    }
    
    if (([self playDuration] - offset) < [self silenceAtEnd]) {
        return YES;
    }
    
    return NO;
}


#pragma mark - Accessors

- (TrackType) trackType
{
    return TrackTypeAudioFile;
}


- (NSTimeInterval) playDuration
{
    NSTimeInterval stopTime = _stopTime ? _stopTime : _duration;
    return stopTime - _startTime;
}


@end


@implementation SilentTrack

+ (instancetype) silenceTrack
{
    return [[self alloc] init];
}


- (id) init
{
    if ((self = [super init])) {
        [self setTitle:NSLocalizedString(@"Silence", nil)];
        [self setDuration:5];
    }
    
    return self;
}


- (TrackType) trackType
{
    return TrackTypeSilence;
}


@end