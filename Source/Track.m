//
//  Track.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Track.h"
#import "iTunesManager.h"
#import "TrackAnalyzer.h"

#import <AVFoundation/AVFoundation.h>

#define DUMP_UNKNOWN_TAGS 0

NSString * const TrackDidUpdateNotification = @"TrackDidUpdate";

static NSString * const sTypeKey          = @"type";
static NSString * const sStatusKey        = @"status";
static NSString * const sBookmarkKey      = @"bookmark";
static NSString * const sPausesKey        = @"pauses";
static NSString * const sTitleKey         = @"title";
static NSString * const sArtistKey        = @"artist";
static NSString * const sStartTimeKey     = @"start-time";
static NSString * const sStopTimeKey      = @"stop-time";
static NSString * const sDurationKey      = @"duration";
static NSString * const sTonalityKey      = @"tonality";
static NSString * const sTrackLoudnessKey = @"track-loudness";
static NSString * const sTrackPeakKey     = @"track-peak";
static NSString * const sOverviewDataKey  = @"overview-data";
static NSString * const sOverviewRateKey  = @"overview-rate";
static NSString * const sBPMKey           = @"bpm";


@interface Track ()
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *artist;
@property (nonatomic) NSInteger beatsPerMinute;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) Tonality tonality;
@property (nonatomic) double trackLoudness;
@property (nonatomic) double trackPeak;
@property (nonatomic) NSData *overviewData;
@property (nonatomic) double  overviewRate;
@end



@implementation Track {
    NSData        *_bookmark;
    TrackAnalyzer *_trackAnalyzer;
    AVAsset       *_asset;
    NSTimeInterval _silenceAtStart;
    NSTimeInterval _silenceAtEnd;
}

@dynamic playDuration, silenceAtStart, silenceAtEnd;



+ (NSSet *) keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    NSArray *affectingKeys = nil;
 
    if ([key isEqualToString:@"playDuration"]) {
        affectingKeys = @[ @"duration", @"stopTime", @"startTime" ];
    } else if ([key isEqualToString:@"silenceAtStart"]) {
        affectingKeys = @[ @"overviewData", @"startTime" ];
    } else if ([key isEqualToString:@"silenceAtEnd"]) {
        affectingKeys = @[ @"overviewData", @"stopTime" ];
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
        
        track = [[Track alloc] _initWithFileURL:nil bookmark:bookmark state:state];

    } else if (type == TrackTypeSilence) {
        track = [[SilentTrack alloc] init];

    } else {
        return nil;
    }

    return track;
}


+ (instancetype) trackWithFileURL:(NSURL *)url
{
    return [[self alloc] _initWithFileURL:url bookmark:nil state:nil];
}


- (id) _initWithFileURL:(NSURL *)url bookmark:(NSData *)bookmark state:(NSDictionary *)state
{
    if ((self = [super init])) {
        if (!bookmark) {
            NSError *error = nil;
            bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

            if (error) {
                NSLog(@"Error creating bookmark for %@: %@", url, error);
            }
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
        if (![_fileURL startAccessingSecurityScopedResource]) {
            NSLog(@"startAccessingSecurityScopedResource failed");
        }

        _bookmark = bookmark;
        
        [self _invalidateSilence];
        
        [self _loadState:state notify:NO];

        [self _loadMetadataViaManager];
        [self _loadMetadataViaAsset];
        
        [self _loadMetadataViaAnalysisIfNeeded];
    }

    return self;
}


- (void) dealloc
{
    [self _clearTrackDataForAnalysis];

    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_fileURL stopAccessingSecurityScopedResource];
    _fileURL = nil;
}


- (void) cancelLoad
{
    [self _clearTrackDataForAnalysis];
}


- (void) _loadState:(NSDictionary *)state notify:(BOOL)notify
{
    NSString *artist       = [state objectForKey:sArtistKey];
    NSString *title        = [state objectForKey:sTitleKey];
    NSNumber *startTime    = [state objectForKey:sStartTimeKey];
    NSNumber *stopTime     = [state objectForKey:sStopTimeKey];
    NSNumber *duration     = [state objectForKey:sDurationKey];
    NSNumber *trackStatus  = [state objectForKey:sStatusKey];
    NSNumber *tonality     = [state objectForKey:sTonalityKey];
    NSNumber *bpm          = [state objectForKey:sBPMKey];
    NSNumber *pauses       = [state objectForKey:sPausesKey];
    NSNumber *loudness     = [state objectForKey:sTrackLoudnessKey];
    NSNumber *peak         = [state objectForKey:sTrackPeakKey];
    NSData   *overviewData = [state objectForKey:sOverviewDataKey];
    NSNumber *overviewRate = [state objectForKey:sOverviewRateKey];

    if (artist)       [self setArtist:artist];
    if (title)        [self setTitle:title];
    if (startTime)    [self setStartTime:  [startTime   doubleValue]];
    if (stopTime)     [self setStopTime:   [stopTime    doubleValue]];
    if (duration)     [self setDuration:   [duration    doubleValue]];
    if (trackStatus)  [self setTrackStatus:[trackStatus integerValue]];

    if (tonality)     [self setTonality:[tonality integerValue]];
    if (bpm)          [self setBeatsPerMinute:[bpm integerValue]];
    
    if (loudness)     [self setTrackLoudness:[loudness doubleValue]];
    if (peak)         [self setTrackPeak:[peak doubleValue]];
    if (overviewData) [self setOverviewData:overviewData];
    if (overviewRate) [self setOverviewRate:[overviewRate doubleValue]];

    if (pauses)       [self setPausesAfterPlaying:[pauses boolValue]];
    
    if (overviewData || startTime || stopTime) {
        [self _calculateSilence];
    }
    
    if (notify) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TrackDidUpdateNotification object:self];
    }
}


#pragma mark - Metadata

- (void) _invalidateSilence
{
    _silenceAtEnd = _silenceAtStart = NAN;
}


- (void) _calculateSilence
{
    if (!_overviewData || !_overviewRate) return;

    UInt8     *buffer      = (UInt8 *)[_overviewData bytes];
    NSUInteger length      = [_overviewData length];
    UInt8      threshold   = 5;

    // Calculate silence at start
    {
        NSInteger startIndex = 0;
        NSInteger sampleCount = 0;

        if (_startTime) {
            startIndex = (_overviewRate * _startTime);
        }

        for (NSInteger i = startIndex; i < length; i++) {
            if (buffer[i] > threshold) {
                break;
            }
            
            sampleCount++;
        }
    
        _silenceAtStart = sampleCount / _overviewRate;
    }

    // Calculate silence at end
    {
        NSInteger startIndex  = (length - 1);
        NSInteger sampleCount = 0;
        
        if (_stopTime) {
            startIndex = (_overviewRate * _stopTime);
        }

        for (NSInteger i = startIndex; i >= 0; i--) {
            if (buffer[i] > threshold) {
                break;
            }

            sampleCount++;
        }
        
        _silenceAtEnd = sampleCount / _overviewRate;
    }
}


- (void) _clearTrackDataForAnalysis
{
    [_trackAnalyzer cancel];
    _trackAnalyzer = nil;
}


- (void) _handleTrackAnalyzerDidAnalyze:(TrackAnalyzerResult *)result
{
    if (_trackAnalyzer && result) {
        [self _loadState:@{
            sOverviewDataKey:  [result overviewData],
            sOverviewRateKey:  @([result overviewRate]),
            sTrackLoudnessKey: @([result loudness]),
            sTrackPeakKey:     @([result peak])
        } notify:YES];
    }
    
    [self _clearTrackDataForAnalysis];
}


- (void) _analyzeImmediately:(BOOL)immediately
{
    [_trackAnalyzer cancel];
    _trackAnalyzer = nil;

    TrackAnalyzer *trackAnalyzer = [[TrackAnalyzer alloc] init];
    
    id __weak weakSelf = self;
    [trackAnalyzer analyzeFileAtURL:_fileURL immediately:NO completion:^(TrackAnalyzerResult *result) {
        [weakSelf _handleTrackAnalyzerDidAnalyze:result];
    }];

    _trackAnalyzer = trackAnalyzer;
}


- (void) _loadMetadataViaAnalysisIfNeeded
{
    if (_overviewData || _trackAnalyzer) {
        return;
    }
    
    [self _analyzeImmediately:NO];
}


- (void) _handleDidUpdateLibraryMetadata:(NSNotification *)note
{
    iTunesLibraryMetadata *metadata = [[iTunesManager sharedInstance] libraryMetadataForFileURL:_fileURL];
    
    [self setStartTime:[metadata startTime]];
    [self setStopTime: [metadata stopTime]];
}


- (void) _loadMetadataViaManager
{
    if (!_fileURL) {
        return;
    }

    iTunesPasteboardMetadata *metadata = [[iTunesManager sharedInstance] pasteboardMetadataForFileURL:_fileURL];
    
    if (metadata) {
        if (!_title)    [self setTitle:[metadata title]];
        if (!_artist)   [self setArtist:[metadata artist]];
        if (!_duration) [self setDuration:[metadata duration]];
    }

    if ([[iTunesManager sharedInstance] didParseLibrary]) {
        iTunesLibraryMetadata *metadata = [[iTunesManager sharedInstance] libraryMetadataForFileURL:_fileURL];

        [self setStartTime:[metadata startTime]];
        [self setStopTime: [metadata stopTime]];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleDidUpdateLibraryMetadata:) name:iTunesManagerDidUpdateLibraryMetadataNotification object:nil];
}


- (void) _clearAsset
{
    _asset = nil;
}


- (void) _loadMetadataViaAsset
{
    if (!_fileURL) {
        return;
    }
    
    void (^parseTonality)(NSString *, NSMutableDictionary *) = ^(NSString *string, NSMutableDictionary *dictionary) {
        Tonality tonality = Tonality_Unknown;
        tonality = GetTonalityForString(string);

        if (tonality != Tonality_Unknown) {
            [dictionary setObject:@(tonality) forKey:sTonalityKey];
        }
    };


    void (^parseMetadataItem)(AVMetadataItem *, NSMutableDictionary *) = ^(AVMetadataItem *item, NSMutableDictionary *dictionary) {

        id commonKey = [item commonKey];
        id key       = [item key];

        NSNumber *numberValue = [item numberValue];
        NSString *stringValue = [item stringValue];
        
        if ([commonKey isEqual:@"artist"] || [key isEqual:@"artist"]) {
            [dictionary setObject:[item stringValue] forKey:sArtistKey];

        } else if ([commonKey isEqual:@"title"] || [key isEqual:@"title"]) {
            [dictionary setObject:[item stringValue] forKey:sTitleKey];

        } else if ([key isEqual:@"com.apple.iTunes.initialkey"] && stringValue) {
            parseTonality(stringValue, dictionary);

        } else if ([key isEqual:@((UInt32) 'TKEY')] && stringValue) { // Initial key as ID3v2 TKEY tag
            parseTonality(stringValue, dictionary);

        } else if ([key isEqual:@(0x746d706f)] && numberValue) { // Tempo key
            [dictionary setObject:numberValue forKey:sBPMKey];

        } else if ([key isEqual:@((UInt32) 'TBPM')] && numberValue) { // Tempo as ID3v2 TBPM tag
            [dictionary setObject:numberValue forKey:sBPMKey];

        } else {
#if DUMP_UNKNOWN_TAGS
            NSLog(@"common: %@, key: %@, value: %@",
                GetStringForFourCharCodeObject(commonKey),
                GetStringForFourCharCodeObject(key),
                [item value]
            );
#endif
        }
    };


    _asset = [[AVURLAsset alloc] initWithURL:_fileURL options:@{
        AVURLAssetPreferPreciseDurationAndTimingKey: @YES
    }];

    __weak id weakSelf = self;
    __weak AVAsset *weakAsset = _asset;

    NSString *fallbackTitle = [[_fileURL lastPathComponent] stringByDeletingPathExtension];

    [_asset loadValuesAsynchronouslyForKeys:@[ @"commonMetadata", @"duration", @"availableMetadataFormats" ] completionHandler:^{
        AVAsset *asset = weakAsset;

        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

        NSError *error;
        AVKeyValueStatus metadataStatus = [asset statusOfValueForKey:@"commonMetadata" error:&error];
        AVKeyValueStatus durationStatus = [asset statusOfValueForKey:@"duration"       error:&error];
        AVKeyValueStatus formatsStatus  = [asset statusOfValueForKey:@"availableMetadataFormats" error:&error];

        if (metadataStatus == AVKeyValueStatusLoaded) {
            NSArray *metadata = [weakAsset commonMetadata];

            for (AVMetadataItem *item in metadata) {
                parseMetadataItem(item, dictionary);
            }

            if (![dictionary objectForKey:sTitleKey]) {
                [dictionary setObject:fallbackTitle forKey:sTitleKey];
            }
        }

        if (formatsStatus == AVKeyValueStatusLoaded) {
            for (NSString *format in [asset availableMetadataFormats]) {
                NSArray *metadata = [asset metadataForFormat:format];
            
                for (AVMetadataItem *item in metadata) {
                    parseMetadataItem(item, dictionary);
                }
            }
        }

        if (durationStatus == AVKeyValueStatusLoaded) {
            NSTimeInterval duration = CMTimeGetSeconds([asset duration]);
            [dictionary setObject:@(duration) forKey:sDurationKey];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _loadState:dictionary notify:YES];
        });

        if (durationStatus != AVKeyValueStatusLoading &&
            formatsStatus  != AVKeyValueStatusLoading &&
            metadataStatus != AVKeyValueStatusLoading)
        {
            [weakSelf _clearAsset];
        }
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
    if (_tonality)       [state setObject:@(_tonality)          forKey:sTonalityKey];
    if (_beatsPerMinute) [state setObject:@(_beatsPerMinute)    forKey:sBPMKey];
    if (_trackLoudness)  [state setObject:@(_trackLoudness)     forKey:sTrackLoudnessKey];
    if (_trackPeak)      [state setObject:@(_trackPeak)         forKey:sTrackPeakKey];
    if (_overviewData)   [state setObject:  _overviewData       forKey:sOverviewDataKey];
    if (_overviewRate)   [state setObject:@(_overviewRate)      forKey:sOverviewRateKey];

    if (_pausesAfterPlaying) {
        [state setObject:@YES forKey:sPausesKey];
    }

    return state;
}


- (void) startPriorityAnalysis
{
    if ([_trackAnalyzer isAnalyzingImmediately]) {
        return;
    }

    [self _analyzeImmediately:YES];
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


- (NSTimeInterval) silenceAtStart
{
    if (isnan(_silenceAtStart)) {
        [self _calculateSilence];
    }
    
    return _silenceAtStart;
}


- (NSTimeInterval) silenceAtEnd
{
    if (isnan(_silenceAtEnd)) {
        [self _calculateSilence];
    }
    
    return _silenceAtEnd;
}


- (BOOL) didAnalyzeLoudness
{
    return (_overviewData != nil);
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