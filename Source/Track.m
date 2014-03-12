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

NSString * const TrackDidModifyPlayDurationNotificationName = @"TrackDidModifyPlayDurationNotification";


#define DUMP_UNKNOWN_TAGS 1

static NSString * const sTypeKey          = @"trackType";
static NSString * const sStatusKey        = @"trackStatus";
static NSString * const sTrackErrorKey    = @"trackError";

static NSString * const sBookmarkKey      = @"bookmark";
static NSString * const sPausesKey        = @"pausesAfterPlaying";
static NSString * const sTitleKey         = @"title";
static NSString * const sArtistKey        = @"artist";
static NSString * const sStartTimeKey     = @"startTime";
static NSString * const sStopTimeKey      = @"stopTime";
static NSString * const sDurationKey      = @"duration";
static NSString * const sTonalityKey      = @"tonality";
static NSString * const sTrackLoudnessKey = @"trackLoudness";
static NSString * const sTrackPeakKey     = @"trackPeak";
static NSString * const sOverviewDataKey  = @"overviewData";
static NSString * const sOverviewRateKey  = @"overviewRate";
static NSString * const sBPMKey           = @"beatsPerMinute";
static NSString * const sDatabaseIDKey    = @"databaseID";
static NSString * const sGroupingKey      = @"grouping";
static NSString * const sCommentsKey      = @"comments";
static NSString * const sEnergyLevelKey   = @"energyLevel";
static NSString * const sGenreKey         = @"genre";

@interface Track ()
@property (nonatomic) NSUUID *UUID;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *artist;
@property (nonatomic) NSString *grouping;
@property (nonatomic) NSString *comments;
@property (nonatomic) NSInteger beatsPerMinute;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) Tonality tonality;
@property (nonatomic) double trackLoudness;
@property (nonatomic) double trackPeak;
@property (nonatomic) NSData *overviewData;
@property (nonatomic) double  overviewRate;
@property (nonatomic) NSInteger databaseID;
@property (nonatomic) NSInteger energyLevel;
@property (nonatomic) NSString *genre;

@property (atomic, getter=isCancelled) BOOL cancelled;
@end


@implementation Track {
    NSData         *_bookmark;
    TrackAnalyzer  *_trackAnalyzer;
    NSTimeInterval  _silenceAtStart;
    NSTimeInterval  _silenceAtEnd;

    NSMutableArray *_dirtyKeys;
    BOOL            _dirty;
}

@dynamic playDuration, silenceAtStart, silenceAtEnd;


static NSURL *sGetStateDirectoryURL()
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *appSupport = GetApplicationSupportDirectory();
    
    NSString *tracks = [appSupport stringByAppendingPathComponent:@"Tracks"];
    NSURL *result = [NSURL fileURLWithPath:tracks];

    if (![manager fileExistsAtPath:tracks]) {
        NSError *error = nil;
        [manager createDirectoryAtURL:result withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    return result;
}


static NSURL *sGetStateURLForUUID(NSUUID *UUID)
{
    if (!UUID) return nil;
    
    NSURL *result = [sGetStateDirectoryURL() URLByAppendingPathComponent:[UUID UUIDString]];
    result = [result URLByAppendingPathExtension:@"plist"];

    return result;
}


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


+ (void) clearPersistedState
{
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:sGetStateDirectoryURL() error:&error];
}


+ (instancetype) trackWithUUID:(NSUUID *)UUID
{
    NSURL *url = sGetStateURLForUUID(UUID);
    NSDictionary *state = url ? [NSDictionary dictionaryWithContentsOfURL:url] : nil;
    
    if (!state) {
        return nil;
    }

    NSData *bookmark = [state objectForKey:sBookmarkKey];
    Track  *track    = [[Track alloc] _initWithUUID:UUID fileURL:nil bookmark:bookmark state:state];

    return track;
}


+ (instancetype) trackWithFileURL:(NSURL *)url
{
    NSUUID *UUID = [NSUUID UUID];
    return [[self alloc] _initWithUUID:UUID fileURL:url bookmark:nil state:nil];
}


- (id) _initWithUUID:(NSUUID *)UUID fileURL:(NSURL *)url bookmark:(NSData *)bookmark state:(NSDictionary *)state
{
    if ((self = [super init])) {
        _UUID = UUID;

        [self _resolveURL:url bookmark:bookmark];
        
        [self _invalidateSilence];
        
        [self _updateState:state initialLoad:YES];
        [self _loadMetadataViaManagerWithFileURL:url];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    }

    return self;
}


- (NSString *) description
{
    NSString *friendlyString = [self title];
    
    if ([friendlyString length] == 0) {
        friendlyString = [[_fileURL path] lastPathComponent];
    }

    if ([friendlyString length]) {
        return [NSString stringWithFormat:@"<%@: %p, \"%@\">", [self class], self, friendlyString];
    } else {
        return [super description];
    }
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
    [self setCancelled:YES];
    [self _clearTrackDataForAnalysis];
}


- (id) valueForUndefinedKey:(NSString *)key
{
    EmbraceLog(@"Track", @"-valueForUndefinedKey: %@", key);
    NSLog(@"-[Track valueForUndefinedKey:], key: %@", key);
    return nil;
}


- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    EmbraceLog(@"Track", @"-setValue:forUndefinedKey: %@", key);
    NSLog(@"-[Track setValue:forUndefinedKey:], key: %@", key);
}


#pragma mark - State

- (void) _updateState:(NSDictionary *)state initialLoad:(BOOL)initialLoad
{
    BOOL postPlayDurationChanged = NO;

    for (NSString *key in state) {
        id oldValue = [self valueForKey:key];
        id newValue = [state objectForKey:key];
        
        if (![oldValue isEqual:newValue]) {
            [self setValue:newValue forKey:key];
            
            if (!_dirtyKeys) _dirtyKeys = [NSMutableArray array];
            [_dirtyKeys addObject:key];
            _dirty = YES;

            if ([@[ @"duration", @"startTime", @"endTime" ] containsObject:key]) {
                postPlayDurationChanged = YES;
            }
        }
    }

    NSData   *overviewData = [state objectForKey:sOverviewDataKey];
    NSNumber *startTime    = [state objectForKey:sStartTimeKey];
    NSNumber *stopTime     = [state objectForKey:sStopTimeKey];
    
    if (overviewData || startTime || stopTime) {
        [self _calculateSilence];
    }
    
    if (initialLoad) {
        [_dirtyKeys removeAllObjects];
        _dirty = NO;
    }

    if (_dirty && !initialLoad) {
        [self _saveStateImmediately:NO];
    }

    if (postPlayDurationChanged) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:TrackDidModifyPlayDurationNotificationName object:self];
        });
    }
}


- (void) _reallySaveState
{
    NSMutableDictionary *state = [NSMutableDictionary dictionary];

    // Never save the state until we have a bookmark
    if (!_bookmark) return;

    if (_bookmark)       [state setObject:_bookmark             forKey:sBookmarkKey];
    if (_artist)         [state setObject:_artist               forKey:sArtistKey];
    if (_title)          [state setObject:_title                forKey:sTitleKey];
    if (_comments)       [state setObject:_comments             forKey:sCommentsKey];
    if (_grouping)       [state setObject:_grouping             forKey:sGroupingKey];
    if (_genre)          [state setObject:_genre                forKey:sGenreKey];
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
    if (_trackError)     [state setObject:@(_trackError)        forKey:sTrackErrorKey];
    if (_databaseID)     [state setObject:@(_databaseID)        forKey:sDatabaseIDKey];
    if (_energyLevel)    [state setObject:@(_energyLevel)       forKey:sEnergyLevelKey];

    if (_pausesAfterPlaying) {
        [state setObject:@YES forKey:sPausesKey];
    }

    NSURL *url = _UUID ? sGetStateURLForUUID(_UUID) : nil;
    if (url) [state writeToURL:url atomically:YES];
    
    _dirty = NO;
    [_dirtyKeys removeAllObjects];
}


- (void) _saveStateImmediately:(BOOL)immediately
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reallySaveState) object:nil];

    if (immediately) {
        [self _reallySaveState];
    } else {
        [self performSelector:@selector(_reallySaveState) withObject:nil afterDelay:10];
    }
}


- (void) _handleApplicationWillTerminate:(NSNotification *)note
{
    if (_dirty) {
        [self _reallySaveState];
    }
}


#pragma mark - Bookmarks

- (void) _handleResolvedURL:(NSURL *)fileURL bookmark:(NSData *)bookmark
{
    EmbraceLog(@"Track", @"%@ resolved %@ to bookmark %@", self, fileURL, bookmark);

    if (![_bookmark isEqual:bookmark]) {
        _bookmark = bookmark;
        _dirty = YES;
    }

    _fileURL = fileURL;


    if (![_fileURL startAccessingSecurityScopedResource]) {
        EmbraceLog(@"Track", @"%@, -startAccessingSecurityScopedResource failed for %@", self, _fileURL);
    }


    [self _loadMetadataViaManagerWithFileURL:_fileURL];
    [self _loadMetadataViaAsset];
    
    [self _loadMetadataViaAnalysisIfNeeded];
    
    if (_dirty) {
        [self _saveStateImmediately:YES];
    }
}


- (void) _resolveURL:(NSURL *)inURL bookmark:(NSData *)inBookmark
{
    static dispatch_queue_t sResolverQueue = NULL;
    
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sResolverQueue = dispatch_queue_create("Track.resolve-bookmark", NULL);
    });
    
    __block NSURL  *fileURL  = inURL;
    __block NSData *bookmark = inBookmark;

    dispatch_async(sResolverQueue, ^{
        if (!bookmark) {
            [fileURL startAccessingSecurityScopedResource];
            
            NSError *error = nil;
            bookmark = [fileURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

            if (error) {
                EmbraceLog(@"Track", @"%@.  Error creating bookmark for %@: %@", self, fileURL, error);
            }

            [fileURL stopAccessingSecurityScopedResource];
        }

        NSURLBookmarkResolutionOptions options = NSURLBookmarkResolutionWithoutUI|NSURLBookmarkResolutionWithSecurityScope;
        
        BOOL isStale = NO;
        NSError *error = nil;
        fileURL = [NSURL URLByResolvingBookmarkData: bookmark
                                            options: options
                                      relativeToURL: nil
                                bookmarkDataIsStale: &isStale
                                              error: &error];

        if (isStale) {
            EmbraceLog(@"Track", @"%@ bookmark is stale, refreshing", self);

            if (![fileURL startAccessingSecurityScopedResource]) {
                EmbraceLog(@"Track", @"%@ -startAccessingSecurityScopedResource failed for %@", self, fileURL);
            }

            bookmark = [fileURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

            if (error) {
                EmbraceLog(@"Track", @"%@ error refreshing bookmark: %@", self, error);
            }

            [fileURL stopAccessingSecurityScopedResource];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self _handleResolvedURL:fileURL bookmark:bookmark];
        });
    });
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
    UInt8      threshold   = 4;

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
        NSInteger maxIndex    = (length - 1);
        NSInteger startIndex  = maxIndex;
        NSInteger sampleCount = 0;
        
        if (_stopTime) {
            startIndex = (_overviewRate * _stopTime);
        }
        
        if (startIndex > maxIndex) {
            startIndex = maxIndex;
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
    EmbraceLog(@"Track", @"%@ analysis result %@.  loudness: %g, peak: %g, error: %ld", self, result, [result loudness], [result peak], (long)[result error]);

    if (_trackAnalyzer && result) {
        NSMutableDictionary *state = [NSMutableDictionary dictionary];
        
        NSData *overviewData = [result overviewData];
        if (overviewData) [state setObject:overviewData forKey:sOverviewDataKey];
        
        [state addEntriesFromDictionary:@{
            sOverviewRateKey:  @([result overviewRate]),
            sTrackLoudnessKey: @([result loudness]),
            sTrackPeakKey:     @([result peak]),
            sTrackErrorKey:    @([result error])
        }];

        [self _updateState:state initialLoad:NO];
    }
    
    [self _clearTrackDataForAnalysis];
}


- (void) _analyzeImmediately:(BOOL)immediately
{
    [_trackAnalyzer cancel];
    _trackAnalyzer = nil;

    EmbraceLog(@"Track", @"%@ requesting analysis, immediately=%ld", self, (long)immediately);

    TrackAnalyzer *trackAnalyzer = [[TrackAnalyzer alloc] init];
    
    id __weak weakSelf = self;
    [trackAnalyzer analyzeFileAtURL:_fileURL immediately:immediately completion:^(TrackAnalyzerResult *result) {
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
    
    NSTimeInterval startTime = [metadata startTime];
    NSTimeInterval stopTime  = [metadata stopTime];
    
    EmbraceLog(@"Track", @"%@ updated startTime=%g, stopTime=%g with %@", self, startTime, stopTime, metadata);
    
    [self setStartTime:startTime];
    [self setStopTime: stopTime];
}


- (void) _loadMetadataViaManagerWithFileURL:(NSURL *)fileURL
{
    if (!fileURL) {
        return;
    }

    iTunesPasteboardMetadata *pasteboardMetadata = [[iTunesManager sharedInstance] pasteboardMetadataForFileURL:fileURL];
    
    if (pasteboardMetadata) {
        NSString      *title      = [pasteboardMetadata title];
        NSString      *artist     = [pasteboardMetadata artist];
        NSTimeInterval duration   = [pasteboardMetadata duration];
        NSInteger      databaseID = [pasteboardMetadata trackID];

        EmbraceLog(@"Track", @"%@ has pasteboard metadata: title=%@, artist=%@, duration=%g, databaseID=%ld", self, title, artist, duration, databaseID);
        
        if (!_title)      [self setTitle:title];
        if (!_artist)     [self setArtist:artist];
        if (!_duration)   [self setDuration:duration];
        if (!_databaseID) [self setDatabaseID:databaseID];
    }

    if ([[iTunesManager sharedInstance] didParseLibrary]) {
        iTunesLibraryMetadata *libraryMetadata = [[iTunesManager sharedInstance] libraryMetadataForFileURL:fileURL];

        NSTimeInterval startTime = [libraryMetadata startTime];
        NSTimeInterval stopTime  = [libraryMetadata stopTime];
        
        EmbraceLog(@"Track", @"%@ has library metadata: startTime=%g, stopTime=%g", self, startTime, stopTime);
        
        [self setStartTime:startTime];
        [self setStopTime: stopTime];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleDidUpdateLibraryMetadata:) name:iTunesManagerDidUpdateLibraryMetadataNotification object:nil];
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
        
        id value = [item value];
        NSDictionary *dictionaryValue = nil;
        if ([value isKindOfClass:[NSDictionary class]]) {
            dictionaryValue = (NSDictionary *)value;
        }

        if (!stringValue) {
            stringValue = [dictionaryValue objectForKey:@"text"];
        }
        
        if ([commonKey isEqual:@"artist"] || [key isEqual:@"artist"]) {
            [dictionary setObject:[item stringValue] forKey:sArtistKey];

        } else if ([commonKey isEqual:@"title"] || [key isEqual:@"title"]) {
            [dictionary setObject:[item stringValue] forKey:sTitleKey];

        } else if ([key isEqual:@"com.apple.iTunes.initialkey"] && stringValue) {
            parseTonality(stringValue, dictionary);

        } else if ([key isEqual:@"com.apple.iTunes.energylevel"] && numberValue) {
            [dictionary setObject:numberValue forKey:sEnergyLevelKey];

        } else if ([key isEqual:@((UInt32) 'COMM')  ] ||
                   [key isEqual:@((UInt32) '\00COM')] ||
                   [key isEqual:@(-1453101708)])
        {
            if (dictionaryValue) {
                NSString *identifier = [dictionaryValue objectForKey:@"identifier"];
                NSString *text       = [dictionaryValue objectForKey:@"text"];
                
                if ([identifier isEqualToString:@"iTunNORM"]) {
                    return;
                }

                if (text) {
                    [dictionary setObject:text forKey:sCommentsKey];
                }

            } else if (stringValue) {
                [dictionary setObject:stringValue forKey:sCommentsKey];
            }
            
        } else if ([key isEqual:@((UInt32) 'TKEY')] && stringValue) { // Initial key as ID3v2.3 TKEY tag
            parseTonality(stringValue, dictionary);

        } else if ([key isEqual:@((UInt32) '\00TKE')] && stringValue) { // Initial key as ID3v2.2 TKE tag
            parseTonality(stringValue, dictionary);

        } else if ([key isEqual:@((UInt32) 'tmpo')] && numberValue) { // Tempo key, 'tmpo'
            [dictionary setObject:numberValue forKey:sBPMKey];

        } else if ([key isEqual:@((UInt32) 'TBPM')] && numberValue) { // Tempo as ID3v2.3 TBPM tag
            [dictionary setObject:numberValue forKey:sBPMKey];

        } else if ([key isEqual:@((UInt32) '\00TBP')] && numberValue) { // Tempo as ID3v2.2 TBP tag
            [dictionary setObject:numberValue forKey:sBPMKey];

        } else if ([key isEqual:@(-1452838288)] && stringValue) { // Grouping, '?grp'
            [dictionary setObject:stringValue forKey:sGroupingKey];

        } else if ([key isEqual:@((UInt32) 'TIT1')] && stringValue) { // Grouping as ID3v2.3 TIT1 tag
            [dictionary setObject:stringValue forKey:sGroupingKey];

        } else if ([key isEqual:@((UInt32) '\00TT1')] && stringValue) { // Grouping as ID3v2.2 TT1 tag
            [dictionary setObject:stringValue forKey:sGroupingKey];

        } else if ([key isEqual:@(-1452841618)] && stringValue) { // Genre, '?gen'
            [dictionary setObject:stringValue forKey:sGenreKey];

        } else if ([key isEqual:@((UInt32) 'TCON')] && stringValue) { // Genre, 'TCON'
            [dictionary setObject:stringValue forKey:sGenreKey];

        } else if ([key isEqual:@((UInt32) '\00TCO')] && stringValue) { // Genre, 'TCO'
            [dictionary setObject:stringValue forKey:sGenreKey];

        } else if ([key isEqual:@((UInt32) 'TXXX')] || [key isEqual:@((UInt32) '\00TXX')]) { // Read TXXX / TXX
            if ([[dictionaryValue objectForKey:@"identifier"] isEqualToString:@"EnergyLevel"]) {
                [dictionary setObject:@( [stringValue integerValue] ) forKey:sEnergyLevelKey];
            }

        } else {
#if DUMP_UNKNOWN_TAGS
            NSString *debugStringValue = [item stringValue];
            if ([debugStringValue length] > 256) stringValue = @"(data)";

            NSLog(@"common: %@ %@, key: %@ %@, value: %@",
                commonKey, GetStringForFourCharCodeObject(commonKey),
                key, GetStringForFourCharCodeObject(key),
                [item value],
                debugStringValue
            );
#endif
        }
    };

    static dispatch_queue_t sLoaderQueue = NULL;
    
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sLoaderQueue = dispatch_queue_create("Track.load-avasset-metadata", NULL);
    });

    __weak id weakSelf = self;

    NSString *fallbackTitle = [[_fileURL lastPathComponent] stringByDeletingPathExtension];

    dispatch_async(sLoaderQueue, ^{ @autoreleasepool {
        BOOL isCancelled = [weakSelf isCancelled];
        if (isCancelled) {
            return;
        }

        NSURL *fileURL = [weakSelf fileURL];
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];

        NSArray *commonMetadata = [asset commonMetadata];
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

        for (AVMetadataItem *item in commonMetadata) {
            parseMetadataItem(item, dictionary);
        }

        if (![dictionary objectForKey:sTitleKey]) {
            [dictionary setObject:fallbackTitle forKey:sTitleKey];
        }


        for (NSString *format in [asset availableMetadataFormats]) {
            NSArray *metadata = [asset metadataForFormat:format];
        
            for (AVMetadataItem *item in metadata) {
                parseMetadataItem(item, dictionary);
            }
        }

        NSTimeInterval duration = CMTimeGetSeconds([asset duration]);
        [dictionary setObject:@(duration) forKey:sDurationKey];
    
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _updateState:dictionary initialLoad:NO];
        });

        [asset cancelLoading];
        asset = nil;
    }});
}


#pragma mark - Public Methods

- (void) startPriorityAnalysis
{
    if ([_trackAnalyzer isAnalyzingImmediately]) {
        return;
    }

    [self _analyzeImmediately:YES];
}


#pragma mark - Accessors

- (NSDate *) estimatedEndTimeDate
{
    NSTimeInterval endTime = _estimatedEndTime;
    
    if (endTime < (60 * 60 * 24 * 7)) {
        return [NSDate dateWithTimeIntervalSinceNow:endTime];
    } else {
        return [NSDate dateWithTimeIntervalSinceReferenceDate:endTime];
    }
}


- (void) setTrackStatus:(TrackStatus)trackStatus
{
    if (_trackStatus != trackStatus) {
        _trackStatus = trackStatus;
        _dirty = YES;
        [self _saveStateImmediately:YES];
    }
}


- (void) setPausesAfterPlaying:(BOOL)pausesAfterPlaying
{
    if (_pausesAfterPlaying != pausesAfterPlaying) {
        _pausesAfterPlaying = pausesAfterPlaying;
        _dirty = YES;
        [self _saveStateImmediately:NO];
    }
}


- (void) setTrackError:(TrackError)trackError
{
    if (_trackError != trackError) {
        EmbraceLog(@"Track", @"%@ setting error to %ld", self, trackError);

        _trackError = trackError;
        _dirty = YES;
        [self _saveStateImmediately:NO];
    }
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
    
    return isnan(_silenceAtStart) ? 0 : _silenceAtStart;
}


- (NSTimeInterval) silenceAtEnd
{
    if (isnan(_silenceAtEnd)) {
        [self _calculateSilence];
    }
    
    return isnan(_silenceAtEnd) ? 0 : _silenceAtEnd;
}


- (BOOL) didAnalyzeLoudness
{
    return (_overviewData != nil);
}


@end
