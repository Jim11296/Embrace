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


#define DUMP_UNKNOWN_TAGS 0

static NSString * const sTypeKey          = @"trackType";
static NSString * const sStatusKey        = @"trackStatus";
static NSString * const sLabelKey         = @"trackLabel";
static NSString * const sTrackErrorKey    = @"trackError";

static NSString * const sBookmarkKey      = @"bookmark";
static NSString * const sPausesKey        = @"pausesAfterPlaying";
static NSString * const sTitleKey         = @"title";
static NSString * const sArtistKey        = @"artist";
static NSString * const sStartTimeKey     = @"startTime";
static NSString * const sStopTimeKey      = @"stopTime";
static NSString * const sDurationKey      = @"duration";
static NSString * const sInitialKeyKey    = @"initialKey";
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


static const char *sGenreList[128] = {
    NULL,
    "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop", "Jazz", "Metal",
    "New Age", "Oldies", "Other", "Pop", "R&B", "Rap", "Reggae", "Rock", "Techno", "Industrial",
    "Alternative", "Ska", "Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk",
    "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
    "AlternRock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic",
    "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta",
    "Top 40", "Christian Rap", "Pop/Funk", "Jungle", "Native American", "Cabaret", "New Wave", "Psychadelic", "Rave", "Showtunes",
    "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock",
    "Folk", "Folk/Rock", "National Folk", "Swing", "Fast Fusion", "Bebob", "Latin", "Revival", "Celtic", "Bluegrass",
    "Avantgarde", "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock", "Big Band", "Chorus", "Easy Listening", "Acoustic",
    "Humour", "Speech", "Chanson", "Opera", "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus", "Porn Groove",
    "Satire", "Slow Jam", "Club", "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle",
    "Duet", "Punk Rock", "Drum Solo", "A Capella", "Euro-House", "Dance Hall",
    NULL
};


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
@property (nonatomic) NSString *initialKey;

@property (atomic, getter=isCancelled) BOOL cancelled;
@end


@implementation Track {
    NSData         *_bookmark;
    TrackAnalyzer  *_trackAnalyzer;
    NSTimeInterval  _silenceAtStart;
    NSTimeInterval  _silenceAtEnd;

    NSMutableArray *_dirtyKeys;
    BOOL            _dirty;
    BOOL            _cleared;
}

@dynamic playDuration, silenceAtStart, silenceAtEnd, tonality;


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


static NSURL *sGetInternalDirectoryURL()
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *appSupport = GetApplicationSupportDirectory();
    
    NSString *files = [appSupport stringByAppendingPathComponent:@"Files"];
    NSURL *result = [NSURL fileURLWithPath:files];

    if (![manager fileExistsAtPath:files]) {
        NSError *error = nil;
        [manager createDirectoryAtURL:result withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    return result;
}


static NSURL *sGetInternalURLForUUID(NSUUID *UUID, NSString *extension)
{
    if (!UUID) return nil;
    
    NSURL *result = [sGetInternalDirectoryURL() URLByAppendingPathComponent:[UUID UUIDString]];

    if (extension) {
        result = [result URLByAppendingPathExtension:extension];
    }

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
    } else if ([key isEqualToString:@"tonality"]) {
        affectingKeys = @[ @"initialKey" ];
    }

    if (affectingKeys) {
        keyPaths = [keyPaths setByAddingObjectsFromArray:affectingKeys];
    }
 
    return keyPaths;
}


+ (void) clearPersistedState
{
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:sGetStateDirectoryURL()    error:&error];
    [[NSFileManager defaultManager] removeItemAtURL:sGetInternalDirectoryURL() error:&error];
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

        [self _resolveExternalURL:url bookmark:bookmark];
        
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
        friendlyString = [[[self externalURL] path] lastPathComponent];
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


- (void) setValue:(id)value forUndefinedKey:(NSString *)key
{
    EmbraceLog(@"Track", @"-setValue:forUndefinedKey: %@", key);
    NSLog(@"-[Track setValue:forUndefinedKey:], key: %@", key);
}


- (Track *) duplicatedTrack
{
    NSUUID *UUID = [NSUUID UUID];

    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    [self _writeStateToDictionary:state];

    NSData *bookmark = [state objectForKey:sBookmarkKey];

    Track *result = [[[self class] alloc] _initWithUUID:UUID fileURL:nil bookmark:bookmark state:state];
    result->_dirty = YES;
    
    [result setTrackStatus:TrackStatusQueued];
    
    return result;
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

- (void) _writeStateToDictionary:(NSMutableDictionary *)state
{
    // Never save the state until we have a bookmark
    if (!_bookmark) return;

    // This track is dead
    if (_cleared) return;

    if (_bookmark)       [state setObject:_bookmark             forKey:sBookmarkKey];
    if (_artist)         [state setObject:_artist               forKey:sArtistKey];
    if (_title)          [state setObject:_title                forKey:sTitleKey];
    if (_comments)       [state setObject:_comments             forKey:sCommentsKey];
    if (_grouping)       [state setObject:_grouping             forKey:sGroupingKey];
    if (_genre)          [state setObject:_genre                forKey:sGenreKey];
    if (_trackLabel)     [state setObject:@(_trackLabel)        forKey:sLabelKey];
    if (_trackStatus)    [state setObject:@(_trackStatus)       forKey:sStatusKey];
    if (_startTime)      [state setObject:@(_startTime)         forKey:sStartTimeKey];
    if (_stopTime)       [state setObject:@(_stopTime)          forKey:sStopTimeKey];
    if (_duration)       [state setObject:@(_duration)          forKey:sDurationKey];
    if (_beatsPerMinute) [state setObject:@(_beatsPerMinute)    forKey:sBPMKey];
    if (_trackLoudness)  [state setObject:@(_trackLoudness)     forKey:sTrackLoudnessKey];
    if (_trackPeak)      [state setObject:@(_trackPeak)         forKey:sTrackPeakKey];
    if (_overviewData)   [state setObject:  _overviewData       forKey:sOverviewDataKey];
    if (_overviewRate)   [state setObject:@(_overviewRate)      forKey:sOverviewRateKey];
    if (_trackError)     [state setObject:@(_trackError)        forKey:sTrackErrorKey];
    if (_databaseID)     [state setObject:@(_databaseID)        forKey:sDatabaseIDKey];
    if (_energyLevel)    [state setObject:@(_energyLevel)       forKey:sEnergyLevelKey];
    if (_initialKey)     [state setObject:  _initialKey         forKey:sInitialKeyKey];

    if (_pausesAfterPlaying) {
        [state setObject:@YES forKey:sPausesKey];
    }
}


- (void) _reallySaveState
{
    // Never save the state until we have a bookmark
    if (!_bookmark) return;

    // This track is dead
    if (_cleared) return;

    NSMutableDictionary *state = [NSMutableDictionary dictionary];

    [self _writeStateToDictionary:state];

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

- (void) _handleResolvedExternalURL:(NSURL *)externalURL internalURL:(NSURL *)internalURL bookmark:(NSData *)bookmark
{
    EmbraceLog(@"Track", @"%@ resolved %@ to bookmark %@, internalURL: %@", self, externalURL, bookmark, internalURL);

    if (![_bookmark isEqual:bookmark]) {
        _bookmark = bookmark;
        _dirty = YES;
    }

    _internalURL = internalURL;
    _externalURL = externalURL;

    [self _loadMetadataViaManagerWithFileURL:externalURL];
    [self _loadMetadataViaAsset];
    
    [self _loadMetadataViaAnalysisIfNeeded];
    
    if (_dirty) {
        [self _saveStateImmediately:YES];
    }
}


- (void) _resolveExternalURL:(NSURL *)inURL bookmark:(NSData *)inBookmark
{
    static dispatch_queue_t sResolverQueue = NULL;
    
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sResolverQueue = dispatch_queue_create("Track.resolve-bookmark", NULL);
    });
    
    __block NSURL  *externalURL = inURL;
    __block NSData *bookmark    = inBookmark;

    NSUUID *UUID = _UUID;

    dispatch_async(sResolverQueue, ^{
        NSURL *internalURL;

        @try {
            if (!bookmark) {
                [externalURL embrace_startAccessingResourceWithKey:@"bookmark"];
                
                NSError *error = nil;
                bookmark = [externalURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

                if (error) {
                    EmbraceLog(@"Track", @"%@.  Error creating bookmark for %@: %@", self, externalURL, error);
                }

                [externalURL embrace_stopAccessingResourceWithKey:@"bookmark"];
            }

            if (!bookmark) {
                [self setTitle:[inURL lastPathComponent]];
                [self setTrackError:TrackErrorOpenFailed];
                return;
            }

            NSURLBookmarkResolutionOptions options = NSURLBookmarkResolutionWithoutUI|NSURLBookmarkResolutionWithSecurityScope;
            
            BOOL isStale = NO;
            NSError *error = nil;
            externalURL = [NSURL URLByResolvingBookmarkData: bookmark
                                                    options: options
                                              relativeToURL: nil
                                        bookmarkDataIsStale: &isStale
                                                      error: &error];

            if (!externalURL) {
                [self setTrackError:TrackErrorOpenFailed];
                return;
            }

            if (![externalURL embrace_startAccessingResourceWithKey:@"resolve"]) {
                EmbraceLog(@"Track", @"%@, -embrace_startAccessingResource failed for %@", self, externalURL);
            }

            if (isStale) {
                EmbraceLog(@"Track", @"%@ bookmark is stale, refreshing", self);

                bookmark = [externalURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

                if (error) {
                    EmbraceLog(@"Track", @"%@ error refreshing bookmark: %@", self, error);
                }
            }

            NSString *extension = [externalURL pathExtension];
            internalURL = sGetInternalURLForUUID(UUID, extension);

            if (![[NSFileManager defaultManager] fileExistsAtPath:[internalURL path]]) {
                if (externalURL) {
                    if (![[NSFileManager defaultManager] copyItemAtURL:externalURL toURL:internalURL error:&error]) {
                        EmbraceLog(@"Track", @"%@, failed to copy to internal location: %@", self, error);
                    } else {
                        EmbraceLog(@"Track", @"%@, copied %@ to internal location: %@", self, externalURL, internalURL);
                    }
                }
            }

            [externalURL embrace_stopAccessingResourceWithKey:@"resolve"];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self _handleResolvedExternalURL:externalURL internalURL:internalURL bookmark:bookmark];
            });
            
        } @catch (NSException *e) {
            EmbraceLog(@"Track", @"Resolving bookmark raised exception %@", e);
            externalURL = internalURL = nil;

            [self setTrackError:TrackErrorOpenFailed];
        }
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
    [trackAnalyzer analyzeFileAtURL:_internalURL immediately:immediately completion:^(TrackAnalyzerResult *result) {
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
    iTunesLibraryMetadata *metadata = [[iTunesManager sharedInstance] libraryMetadataForFileURL:[self externalURL]];
    
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
    if (![self internalURL]) {
        return;
    }

    void (^parseMetadataItem)(AVMetadataItem *, NSMutableDictionary *) = ^(AVMetadataItem *item, NSMutableDictionary *dictionary) {
        id commonKey = [item commonKey];
        id key       = [item key];

        FourCharCode key4cc = 0;
        if ([key isKindOfClass:[NSString class]] && [key length] == 4) {
            NSData *keyData = [key dataUsingEncoding:NSASCIIStringEncoding];
            
            if ([keyData length] == 4) {
                key4cc = OSSwapBigToHostInt32(*(UInt32 *)[keyData bytes]);
            }

        } else if ([key isKindOfClass:[NSNumber class]]) {
            key4cc = [key unsignedIntValue];
        }
        
        // iTunes stores normalization info in 'COMM'
        BOOL isAppleNormalizationTag = NO;
        if (key4cc == 'COMM') {
            if ([[[item extraAttributes] objectForKey:@"info"] isEqual:@"iTunNORM"]) {
                isAppleNormalizationTag = YES;
            }
        }

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
        
        if (!numberValue) {
            if ([value isKindOfClass:[NSData class]]) {
                NSData *data = (NSData *)value;
                
                if ([data length] == 4) {
                    numberValue = @( OSSwapBigToHostInt32(*(UInt32 *)[data bytes]) );
                } else if ([data length] == 2) {
                    numberValue = @( OSSwapBigToHostInt16(*(UInt16 *)[data bytes]) );
                } else if ([data length] == 1) {
                    numberValue = @(                      *(UInt8  *)[data bytes]  );
                }
            }
        }
        
        if ([commonKey isEqual:@"artist"] || [key isEqual:@"artist"]) {
            [dictionary setObject:[item stringValue] forKey:sArtistKey];

        } else if ([commonKey isEqual:@"title"] || [key isEqual:@"title"]) {
            [dictionary setObject:[item stringValue] forKey:sTitleKey];

        } else if ([key isEqual:@"com.apple.iTunes.initialkey"] && stringValue) {
            [dictionary setObject:[item stringValue] forKey:sInitialKeyKey];

        } else if ([key isEqual:@"com.apple.iTunes.energylevel"] && numberValue) {
            [dictionary setObject:numberValue forKey:sEnergyLevelKey];

        } else if ((key4cc == 'COMM' && !isAppleNormalizationTag) ||
                   (key4cc == '\00COM') ||
                   (key4cc == '\251cmt'))
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
            
        } else if ((key4cc == 'TKEY') && stringValue) { // Initial key as ID3v2.3 TKEY tag
            [dictionary setObject:stringValue forKey:sInitialKeyKey];

        } else if ((key4cc == '\00TKE') && stringValue) { // Initial key as ID3v2.2 TKE tag
            [dictionary setObject:stringValue forKey:sInitialKeyKey];

        } else if ((key4cc == 'tmpo') && numberValue) { // Tempo key, 'tmpo'
            [dictionary setObject:numberValue forKey:sBPMKey];

        } else if ((key4cc == 'TBPM') && numberValue) { // Tempo as ID3v2.3 TBPM tag
            [dictionary setObject:numberValue forKey:sBPMKey];

        } else if ((key4cc == '\00TBP') && numberValue) { // Tempo as ID3v2.2 TBP tag
            [dictionary setObject:numberValue forKey:sBPMKey];

        } else if ((key4cc == '\251grp') && stringValue) { // Grouping, '?grp'
            [dictionary setObject:stringValue forKey:sGroupingKey];

        } else if ((key4cc == 'TIT1') && stringValue) { // Grouping as ID3v2.3 TIT1 tag
            [dictionary setObject:stringValue forKey:sGroupingKey];

        } else if ((key4cc == '\00TT1') && stringValue) { // Grouping as ID3v2.2 TT1 tag
            [dictionary setObject:stringValue forKey:sGroupingKey];

        } else if (key4cc == 'gnre') { // Genre, 'gnre' - Use sGenreList lookup
            NSInteger i = [numberValue integerValue];
            if (i > 0 && i < 127) {
                const char *genre = sGenreList[i];
                if (genre) [dictionary setObject:@(sGenreList[i]) forKey:sGenreKey];
            }

        } else if ((key4cc == '\251gen') && stringValue) { // Genre, '?gen'
            [dictionary setObject:stringValue forKey:sGenreKey];

        } else if ((key4cc == 'TCON') && stringValue) { // Genre, 'TCON'
            [dictionary setObject:stringValue forKey:sGenreKey];

        } else if ((key4cc == '\00TCO') && stringValue) { // Genre, 'TCO'
            [dictionary setObject:stringValue forKey:sGenreKey];

        } else if ((key4cc == 'TXXX') || (key4cc == '\00TXX')) { // Read TXXX / TXX
            if ([[dictionaryValue objectForKey:@"identifier"] isEqualToString:@"EnergyLevel"]) {
                [dictionary setObject:@( [stringValue integerValue] ) forKey:sEnergyLevelKey];
            }

        } else {
#if DUMP_UNKNOWN_TAGS
            NSString *debugStringValue = [item stringValue];
            if ([debugStringValue length] > 256) stringValue = @"(data)";

            NSLog(@"common: %@ %@, key: %@ %@, value: %@, stringValue: %@",
                commonKey, GetStringForFourCharCodeObject(commonKey),
                key, GetStringForFourCharCodeObject(key),
                [item value],
                stringValue
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

    NSString *fallbackTitle = [[[self externalURL] lastPathComponent] stringByDeletingPathExtension];

    dispatch_async(sLoaderQueue, ^{ @autoreleasepool {
        BOOL isCancelled = [weakSelf isCancelled];
        if (isCancelled) {
            return;
        }

        NSURL *fileURL = [weakSelf internalURL];
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

- (void) clearAndCleanup
{
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:sGetStateURLForUUID(_UUID) error:&error];
    if (_internalURL) [[NSFileManager defaultManager] removeItemAtURL:_internalURL error:&error];

    _cleared = YES;
}


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


- (void) setTrackLabel:(TrackLabel)trackLabel
{
    if (_trackLabel != trackLabel) {
        _trackLabel = trackLabel;
        _dirty = YES;
        [self _saveStateImmediately:NO];
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


- (Tonality) tonality
{
    return GetTonalityForString([self initialKey]);
}


@end
