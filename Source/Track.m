//
//  Track.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Track.h"
#import "iTunesManager.h"
#import "TrackKeys.h"
#import "AppDelegate.h"
#import "ScriptsManager.h"
#import "WorkerService.h"

#import <AVFoundation/AVFoundation.h>

NSString * const TrackDidModifyTitleNotificationName            = @"TrackDidModifyTitleNotificationName";
NSString * const TrackDidModifyPlayDurationNotificationName     = @"TrackDidModifyPlayDurationNotification";
NSString * const TrackDidModifyExpectedDurationNotificationName = @"TrackDidModifyExpectedDurationNotification";

#define DUMP_UNKNOWN_TAGS 0

static NSString * const sTypeKey              = @"trackType";
static NSString * const sLabelKey             = @"trackLabel";
static NSString * const sStopsAfterPlayingKey = @"stopsAfterPlaying";
static NSString * const sIgnoresAutoGapKey    = @"ignoresAutoGap";
static NSString * const sStatusKey            = @"trackStatus";
static NSString * const sTrackErrorKey        = @"trackError";
static NSString * const sBookmarkKey          = @"bookmark";
static NSString * const sPlayedTimeKey        = @"playedTime";


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

    NSTimeInterval  _startTimeInterval;

    NSMutableArray *_dirtyKeys;
    BOOL            _dirty;
    BOOL            _cleared;
    BOOL            _priorityAnalysisRequested;
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
        affectingKeys = @[ @"duration", @"decodedDuration", @"stopTime", @"startTime" ];
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

    NSData *bookmark = [state objectForKey:TrackKeyBookmark];
    Track  *track    = [[Track alloc] _initWithUUID:UUID fileURL:nil bookmark:bookmark state:state];

    return track;
}


+ (instancetype) trackWithFileURL:(NSURL *)url
{
    NSUUID *UUID = [NSUUID UUID];
    return [[self alloc] _initWithUUID:UUID fileURL:url bookmark:nil state:nil];
}


+ (BOOL) automaticallyNotifiesObserversForKey:(NSString *)theKey
{
    // Player does a setTrackStatus: in each tick
    if ([theKey isEqualToString:@"trackStatus"]) {
        return NO;
    }

    return [super automaticallyNotifiesObserversForKey:theKey];
}


- (id) _initWithUUID:(NSUUID *)UUID fileURL:(NSURL *)url bookmark:(NSData *)bookmark state:(NSDictionary *)state
{
    if ((self = [super init])) {
        _UUID = UUID;

        _isResolvingURLs = YES;
        [self _resolveExternalURL:url bookmark:bookmark];
        
        [self _invalidateSilence];
        
        [self _updateState:state initialLoad:YES];
        [self _readMetadataViaManagerWithFileURL:url];
        
        EmbraceLog(@"Track", @"%@ is at memory address %p", self, self);
        
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
        return [NSString stringWithFormat:@"<%@: \"%@\">", [self class], friendlyString];
    } else {
        return [super description];
    }
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self _requestWorkerCancel];
}


- (void) cancelLoad
{
    [self setCancelled:YES];
    [self _requestWorkerCancel];
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

    NSData *bookmark = [state objectForKey:TrackKeyBookmark];

    Track *result = [[[self class] alloc] _initWithUUID:UUID fileURL:nil bookmark:bookmark state:state];
    result->_dirty = YES;
    
    [result setTrackStatus:TrackStatusQueued];
    
    return result;
}


#pragma mark - State

- (void) _updateState:(NSDictionary *)state initialLoad:(BOOL)initialLoad
{
    BOOL postTitleChanged = NO;
    BOOL postPlayDurationChanged = NO;

    for (NSString *key in state) {
        id oldValue = [self valueForKey:key];
        id newValue = [state objectForKey:key];

        if (![oldValue isEqual:newValue]) {
            // Transform NSNumbers to NSDates for various keys
            if ([@[ @"startDate" ] containsObject:key] && [newValue isKindOfClass:[NSNumber class]]) {
                newValue = [NSDate dateWithTimeIntervalSinceReferenceDate:[newValue doubleValue]];
            }

            [self setValue:newValue forKey:key];
            
            if (!_dirtyKeys) _dirtyKeys = [NSMutableArray array];
            [_dirtyKeys addObject:key];
            _dirty = YES;

            if ([@"title" isEqualToString:key]) {
                postTitleChanged = YES;
            }
            
            if ([@[ @"duration", @"decodedDuration", @"startTime", @"endTime" ] containsObject:key]) {
                postPlayDurationChanged = YES;
            }
        }
    }

    NSData   *overviewData = [state objectForKey:TrackKeyOverviewData];
    NSNumber *startTime    = [state objectForKey:TrackKeyStartTime];
    NSNumber *stopTime     = [state objectForKey:TrackKeyStopTime];

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

    if (postTitleChanged) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:TrackDidModifyTitleNotificationName object:self];
        });
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

    if (_trackError)     [state setObject:@(_trackError)        forKey:TrackKeyError];
    if (_trackLabel)     [state setObject:@(_trackLabel)        forKey:sLabelKey];
    if (_trackStatus)    [state setObject:@(_trackStatus)       forKey:sStatusKey];
    if (_playedTime)     [state setObject:@(_playedTime)        forKey:sPlayedTimeKey];

    if (_stopsAfterPlaying) {
        [state setObject:@YES forKey:sStopsAfterPlayingKey];
    }

    if (_ignoresAutoGap) {
        [state setObject:@YES forKey:sIgnoresAutoGapKey];
    }

    if (_album)            [state setObject:_album                forKey:TrackKeyAlbum];
    if (_albumArtist)      [state setObject:_albumArtist          forKey:TrackKeyAlbumArtist];
    if (_artist)           [state setObject:_artist               forKey:TrackKeyArtist];
    if (_beatsPerMinute)   [state setObject:@(_beatsPerMinute)    forKey:TrackKeyBPM];
    if (_bookmark)         [state setObject:_bookmark             forKey:TrackKeyBookmark];
    if (_comments)         [state setObject:_comments             forKey:TrackKeyComments];
    if (_composer)         [state setObject:_composer             forKey:TrackKeyComposer];
    if (_databaseID)       [state setObject:@(_databaseID)        forKey:TrackKeyDatabaseID];
    if (_decodedDuration)  [state setObject:@(_decodedDuration)   forKey:TrackKeyDecodedDuration];
    if (_duration)         [state setObject:@(_duration)          forKey:TrackKeyDuration];
    if (_energyLevel)      [state setObject:@(_energyLevel)       forKey:TrackKeyEnergyLevel];
    if (_expectedDuration) [state setObject:@(_expectedDuration)  forKey:TrackKeyExpectedDuration];
    if (_genre)            [state setObject:_genre                forKey:TrackKeyGenre];
    if (_grouping)         [state setObject:_grouping             forKey:TrackKeyGrouping];
    if (_initialKey)       [state setObject:  _initialKey         forKey:TrackKeyInitialKey];
    if (_overviewData)     [state setObject:  _overviewData       forKey:TrackKeyOverviewData];
    if (_overviewRate)     [state setObject:@(_overviewRate)      forKey:TrackKeyOverviewRate];
    if (_startTime)        [state setObject:@(_startTime)         forKey:TrackKeyStartTime];
    if (_stopTime)         [state setObject:@(_stopTime)          forKey:TrackKeyStopTime];
    if (_title)            [state setObject:_title                forKey:TrackKeyTitle];
    if (_trackLoudness)    [state setObject:@(_trackLoudness)     forKey:TrackKeyTrackLoudness];
    if (_trackPeak)        [state setObject:@(_trackPeak)         forKey:TrackKeyTrackPeak];
    if (_year)             [state setObject:@(_year)              forKey:TrackKeyYear];

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
    EmbraceLog(@"Track", @"%@ resolved %@ to bookmark, internalURL: %@", self, externalURL, internalURL);

    if (![_bookmark isEqual:bookmark]) {
        _bookmark = bookmark;
        _dirty = YES;
    }

    _internalURL = internalURL;
    _externalURL = externalURL;

    [self _readMetadataViaManagerWithFileURL:externalURL];
    [self _requestWorkerCommand:WorkerTrackCommandReadMetadata];

    if (!_overviewData) {
        if (_priorityAnalysisRequested) {
            [self _requestWorkerCommand:WorkerTrackCommandReadLoudnessImmediate];
        } else {
            [self _requestWorkerCommand:WorkerTrackCommandReadLoudness];
        }
    }
     
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setTitle:[inURL lastPathComponent]];
                    [self setTrackError:TrackErrorOpenFailed];
                });

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
                dispatch_async(dispatch_get_main_queue(), ^{
                    _isResolvingURLs = NO;
                    [self setTrackError:TrackErrorOpenFailed];
                });

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
                _isResolvingURLs = NO;
                [self _handleResolvedExternalURL:externalURL internalURL:internalURL bookmark:bookmark];
            });
            
        } @catch (NSException *e) {
            EmbraceLog(@"Track", @"Resolving bookmark raised exception %@", e);
            externalURL = internalURL = nil;

            dispatch_async(dispatch_get_main_queue(), ^{
                _isResolvingURLs = NO;
                [self setTrackError:TrackErrorOpenFailed];
            });
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


- (void) _requestWorkerCancel
{
    id<WorkerProtocol> worker = [GetAppDelegate() workerProxyWithErrorHandler:^(NSError *error) {
        EmbraceLog(@"Track", @"Received error for worker cancel: %@", error);
    }];

    [worker cancelUUID:[self UUID]];
}


- (void) _requestWorkerCommand:(WorkerTrackCommand)command
{
    __weak id weakSelf = self;

    NSUUID *UUID        = [self UUID];
    NSURL  *internalURL = [self internalURL];
    NSURL  *externalURL = [self externalURL];

    EmbraceLog(@"Track", @"%@ requesting worker command %ld", self, (long)command);

    id<WorkerProtocol> worker = [GetAppDelegate() workerProxyWithErrorHandler:^(NSError *error) {
        EmbraceLog(@"Track", @"Received error for worker command %ld: %@", command, error);
    }];
    
    
    NSError *error = nil;
    NSData  *bookmarkData = [internalURL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

    NSString *originalFilename = [externalURL lastPathComponent];
    
    [worker performTrackCommand:command UUID:UUID bookmarkData:bookmarkData originalFilename:originalFilename reply: ^(NSDictionary *dictionary) {
        dispatch_async(dispatch_get_main_queue(), ^{
            id strongSelf = weakSelf;
        
            if (command == WorkerTrackCommandReadMetadata) {
                EmbraceLog(@"Track", @"%@ received metadata from worker: %@", self, dictionary);
            } else if (command == WorkerTrackCommandReadLoudness) {
                EmbraceLog(@"Track", @"%@ received loudness from worker", self);
            } else if (command == WorkerTrackCommandReadLoudnessImmediate) {
                EmbraceLog(@"Track", @"%@ received immediate loudness from worker", self);
            }

            [strongSelf _updateState:dictionary initialLoad:NO];
            
            if (command == WorkerTrackCommandReadMetadata) {
                [[ScriptsManager sharedInstance] callMetadataAvailableWithTrack:strongSelf];
            }
        });
    }];
}


- (void) _readMetadataViaManagerWithFileURL:(NSURL *)fileURL
{
    if (!fileURL) {
        return;
    }

    iTunesPasteboardMetadata *pasteboardMetadata = [[iTunesManager sharedInstance] pasteboardMetadataForFileURL:fileURL];
    
    if (pasteboardMetadata) {
        NSString      *title      = [pasteboardMetadata title];
        NSString      *artist     = [pasteboardMetadata artist];
        NSTimeInterval duration   = [pasteboardMetadata duration];
        NSInteger      databaseID = [pasteboardMetadata databaseID];

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


- (void) _handleDidUpdateLibraryMetadata:(NSNotification *)note
{
    iTunesLibraryMetadata *metadata = [[iTunesManager sharedInstance] libraryMetadataForFileURL:[self externalURL]];
    
    NSTimeInterval startTime = [metadata startTime];
    NSTimeInterval stopTime  = [metadata stopTime];
    
    EmbraceLog(@"Track", @"%@ updated startTime=%g, stopTime=%g with %@", self, startTime, stopTime, metadata);
    
    [self setStartTime:startTime];
    [self setStopTime: stopTime];
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
    if (!_priorityAnalysisRequested) {
        _priorityAnalysisRequested = YES;
        
        if ([self internalURL]) {
            [self _requestWorkerCommand:WorkerTrackCommandReadLoudnessImmediate];
        }
    }
}


#pragma mark - Accessors

- (NSDate *) playedTimeDate
{
    return _playedTime ? [NSDate dateWithTimeIntervalSinceReferenceDate:_playedTime] : nil;
}


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
        [self willChangeValueForKey:@"trackStatus"];

        // Update played time for: (Queued -> Non-Queued) or (Preparing -> Playing)
        if ((_trackStatus == TrackStatusQueued    && trackStatus != TrackStatusQueued) ||
            (_trackStatus == TrackStatusPreparing && trackStatus == TrackStatusPlaying))
        {
            _playedTime = [NSDate timeIntervalSinceReferenceDate];

        // Clear playedTime if we become re-queued
        } else if (trackStatus == TrackStatusQueued) {
            _playedTime = 0;
        }
    
        _trackStatus = trackStatus;
        _dirty = YES;
        [self _saveStateImmediately:YES];

        [self didChangeValueForKey:@"trackStatus"];
    }
}


- (void) setTitle:(NSString *)title
{
    if (_title != title) {
        _title = [title precomposedStringWithCanonicalMapping];
        _titleForSimilarTitleDetection = GetSimplifiedString(title);
        _dirty = YES;
        [self _saveStateImmediately:NO];
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


- (void) setStopsAfterPlaying:(BOOL)stopsAfterPlaying
{
    if (_stopsAfterPlaying != stopsAfterPlaying) {
        _stopsAfterPlaying = stopsAfterPlaying;
        
        if (stopsAfterPlaying) {
            [self setIgnoresAutoGap:NO];
        }
        
        _dirty = YES;
        [self _saveStateImmediately:NO];
    }
}



- (void) setIgnoresAutoGap:(BOOL)ignoresAutoGap
{
    if (_ignoresAutoGap != ignoresAutoGap) {
        _ignoresAutoGap = ignoresAutoGap;
        
        if (ignoresAutoGap) {
            [self setStopsAfterPlaying:NO];
        }
        
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

- (void) setExpectedDuration:(NSTimeInterval)expectedDuration
{
    if (_expectedDuration != expectedDuration) {
        _expectedDuration = expectedDuration;
        _dirty = YES;
        [self _saveStateImmediately:NO];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:TrackDidModifyPlayDurationNotificationName object:self];
        });
    }
}


- (NSTimeInterval) playDuration
{
    NSTimeInterval duration = _decodedDuration ? _decodedDuration : _duration;
    NSTimeInterval stopTime = _stopTime ? _stopTime : duration;
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
