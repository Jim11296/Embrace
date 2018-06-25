// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "iTunesManager.h"

#import <ScriptingBridge/ScriptingBridge.h>
#import "iTunes.h"
#import "Utils.h"
#import "AppDelegate.h"
#import "TrackKeys.h"
#import "WorkerService.h"


NSString * const iTunesManagerDidUpdateLibraryMetadataNotification = @"iTunesManagerDidUpdateLibraryMetadata";


@implementation iTunesManager {
    NSTimer             *_libraryCheckTimer;
    NSTimeInterval       _lastLibraryParseTime;
    NSMutableDictionary *_pathToLibraryMetadataMap;

    NSMutableDictionary *_pathToTrackIDMap;
    NSMutableDictionary *_trackIDToPasteboardMetadataMap;

    dispatch_queue_t _tunesQueue;
}


+ (id) sharedInstance
{
    static iTunesManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[iTunesManager alloc] init];
    });

    return sSharedInstance;
}


- (id) init
{
    if ((self = [super init])) {
        _libraryCheckTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(_checkLibrary:) userInfo:nil repeats:YES];
        
        if ([_libraryCheckTimer respondsToSelector:@selector(setTolerance:)]) {
            [_libraryCheckTimer setTolerance:5.0];
        }
        
        [self _checkLibrary:nil];
    }

    return self;
}


#pragma mark - Export

- (void) _performOnTunesQueue:(void (^)())block completion:(void (^)())completion
{
    if (!_tunesQueue) {
        _tunesQueue = dispatch_queue_create("iTunesManager", 0);
    }
    
    void (^blockCopy)() = [block copy];
    void (^completionCopy)() = [completion copy];

    dispatch_async(_tunesQueue, ^{
        blockCopy();
        if (completionCopy) completionCopy();
    });
}


- (void) exportPlaylistWithName:(NSString *)playlistName fileURLs:(NSArray *)fileURLs
{
    [self _performOnTunesQueue:^{
        iTunesApplication *iTunes = (iTunesApplication *)[[SBApplication alloc] initWithBundleIdentifier:@"com.apple.iTunes"];

        SBElementArray *sources = [iTunes sources];
        iTunesSource *library = nil;

        for (iTunesSource *source in sources) {
            if ([source kind] == iTunesESrcLibrary) {
                library = source;
                break;
            }
        }

        iTunesUserPlaylist *playlist = nil;

        if (!playlist) {
            playlist = [[[iTunes classForScriptingClass:@"playlist"] alloc] init];
            [[library userPlaylists] insertObject:playlist atIndex:0];
            [playlist setName:playlistName];
        }
        
        if (playlist) {
            for (NSURL *fileURL in fileURLs) {
                [iTunes add:@[ fileURL ] to:playlist];
            }
        }

        [iTunes activate];
        
        [[[playlist tracks] firstObject] reveal];

    } completion:nil];
}


#pragma mark - Library Metadata

- (void) _checkLibrary:(NSTimer *)timer
{
    NSURL *libraryURL = nil;
    
    // Get URL for "iTunes Library.itl"
    {
        NSArray  *musicPaths = NSSearchPathForDirectoriesInDomains(NSMusicDirectory, NSUserDomainMask, YES);
        NSString *musicPath  = [musicPaths firstObject];
        
        NSString *iTunesPath = [musicPath  stringByAppendingPathComponent:@"iTunes"];
        NSString *itlPath    = [iTunesPath stringByAppendingPathComponent:@"iTunes Library.itl"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:itlPath]) {
            libraryURL = [NSURL fileURLWithPath:itlPath];
        }
    }

    EmbraceLog(@"iTunesManager", @"libraryURL is: %@", libraryURL);
    
    NSDate *modificationDate = nil;
    NSError *error = nil;

    [libraryURL getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:&error];
    if (error) {
        EmbraceLog(@"iTunesManager", @"Could not get modification date for %@: error: %@", libraryURL, error);
    }

    if (!error && [modificationDate isKindOfClass:[NSDate class]]) {
        NSTimeInterval timeInterval = [modificationDate timeIntervalSinceReferenceDate];
        
        if (timeInterval > _lastLibraryParseTime) {
            if (_lastLibraryParseTime) {
                EmbraceLog(@"iTunesManager", @"iTunes Library modified!");
            }

            id<WorkerProtocol> worker = [GetAppDelegate() workerProxyWithErrorHandler:^(NSError *proxyError) {
                EmbraceLog(@"iTunesManager", @"Received error for worker fetch: %@", proxyError);
            }];

            _lastLibraryParseTime = timeInterval;

            [worker performLibraryParseWithReply:^(NSDictionary *dictionary) {
                NSMutableDictionary *pathToLibraryMetadataMap = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];

                for (NSString *path in dictionary) {
                    iTunesLibraryMetadata *metadata = [[iTunesLibraryMetadata alloc] init];
                    
                    NSDictionary *trackData = [dictionary objectForKey:path];
                    [metadata setStartTime:[[trackData objectForKey:TrackKeyStartTime] doubleValue]];
                    [metadata setStopTime: [[trackData objectForKey:TrackKeyStopTime]  doubleValue]];

                    [pathToLibraryMetadataMap setObject:metadata forKey:path];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    _didParseLibrary = YES;

                    if (![_pathToLibraryMetadataMap isEqualToDictionary:pathToLibraryMetadataMap]) {
                        _pathToLibraryMetadataMap = pathToLibraryMetadataMap;
                        [[NSNotificationCenter defaultCenter] postNotificationName:iTunesManagerDidUpdateLibraryMetadataNotification object:self];
                    }
                });
            }];
        }
    }
}


- (iTunesLibraryMetadata *) libraryMetadataForFileURL:(NSURL *)url
{
    return [_pathToLibraryMetadataMap objectForKey:[url path]];
}


#pragma mark - Pasteboard Metadata

- (void) clearPasteboardMetadata
{
    [_trackIDToPasteboardMetadataMap removeAllObjects];
}


- (void) extractMetadataFromPasteboard:(NSPasteboard *)pasteboard
{
    void (^parseTrack)(NSString *, NSDictionary *) = ^(NSString *key, NSDictionary *track) {
        if (![key isKindOfClass:[NSString class]]) {
            return;
        }

        if (![track isKindOfClass:[NSDictionary class]]) {
            return;
        }

        NSString *artist = [track objectForKey:@"Artist"];
        if (![artist isKindOfClass:[NSString class]]) artist = nil;

        NSString *name = [track objectForKey:@"Name"];
        if (![name isKindOfClass:[NSString class]]) name = nil;

        NSString *location = [track objectForKey:@"Location"];
        if (![location isKindOfClass:[NSString class]]) location = nil;
        
        if ([location hasPrefix:@"file:"]) {
            location = [[NSURL URLWithString:location] path];
        }

        id totalTimeObject = [track objectForKey:@"Total Time"];
        if (![totalTimeObject respondsToSelector:@selector(doubleValue)]) {
            totalTimeObject = nil;
        }

        id trackIDObject = [track objectForKey:@"Track ID"];
        if (![trackIDObject respondsToSelector:@selector(integerValue)]) {
            trackIDObject = nil;
        }
        
        NSTimeInterval totalTime = [totalTimeObject doubleValue] / 1000.0;
        NSTimeInterval trackID   = [trackIDObject integerValue];
        
        if (!trackID) return;

        iTunesPasteboardMetadata *metadata = [[iTunesPasteboardMetadata alloc] init];
        [metadata setDuration:totalTime];
        [metadata setTitle:name];
        [metadata setArtist:artist];
        [metadata setLocation:location];
        [metadata setDatabaseID:[key integerValue]];

        if (!_trackIDToPasteboardMetadataMap) _trackIDToPasteboardMetadataMap = [NSMutableDictionary dictionary];
        [_trackIDToPasteboardMetadataMap setObject:metadata forKey:@(trackID)];
        
        if (location) {
            if (!_pathToTrackIDMap) _pathToTrackIDMap = [NSMutableDictionary dictionary];
            [_pathToTrackIDMap setObject:@(trackID) forKey:location];
        }
    };

    void (^parseRoot)(NSDictionary *) = ^(NSDictionary *dictionary) {
        if (![dictionary isKindOfClass:[NSDictionary class]]) {
            return;
        }
        
        NSDictionary *trackMap = [dictionary objectForKey:@"Tracks"];
        if (![trackMap isKindOfClass:[NSDictionary class]]) {
            return;
        }
        
        for (NSString *key in trackMap) {
            parseTrack(key, [trackMap objectForKey:key]);
        }
    };

    for (NSPasteboardItem *item in [pasteboard pasteboardItems]) {
        for (NSString *type in [item types]) {
            if ([type isEqualToString:@"com.apple.itunes.metadata"]) {
                parseRoot([item propertyListForType:type]);
            }
        }
    }
}


- (iTunesPasteboardMetadata *) pasteboardMetadataForFileURL:(NSURL *)url
{
    NSInteger trackID = [[_pathToTrackIDMap objectForKey:[url path]] integerValue];
    return [_trackIDToPasteboardMetadataMap objectForKey:@(trackID)];
}


@end


#pragma mark - Other Classes

@implementation iTunesLibraryMetadata

- (BOOL) isEqual:(id)otherObject
{
    if (![otherObject isKindOfClass:[iTunesLibraryMetadata class]]) {
        return NO;
    }

    iTunesLibraryMetadata *otherMetadata = (iTunesLibraryMetadata *)otherObject;

    return _startTime == otherMetadata->_startTime &&
           _stopTime  == otherMetadata->_stopTime;
}


- (NSUInteger) hash
{
    NSUInteger startTime = *(NSUInteger *)&_startTime;
    NSUInteger stopTime  = *(NSUInteger *)&_stopTime;

    return startTime ^ stopTime;
}


@end


@implementation iTunesPasteboardMetadata
@end

