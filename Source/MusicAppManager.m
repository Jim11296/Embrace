// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "MusicAppManager.h"

#import "Utils.h"
#import "AppDelegate.h"
#import "TrackKeys.h"
#import "WorkerService.h"


NSString * const MusicAppManagerDidUpdateLibraryMetadataNotification = @"MusicAppManagerDidUpdateLibraryMetadata";


static NSString *sGetExpandedPath(NSString *inPath)
{
    inPath = [inPath stringByStandardizingPath];
    inPath = [inPath stringByResolvingSymlinksInPath];
    
    return inPath;
}


@implementation MusicAppManager {
    NSTimer             *_libraryCheckTimer;
    NSTimeInterval       _lastLibraryParseTime;
    NSMutableDictionary *_pathToLibraryMetadataMap;

    NSMutableDictionary *_pathToTrackIDMap;
    NSMutableDictionary *_trackIDToPasteboardMetadataMap;
}


+ (id) sharedInstance
{
    static MusicAppManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[MusicAppManager alloc] init];
    });

    return sSharedInstance;
}


- (id) init
{
    if ((self = [super init])) {
        _libraryCheckTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(_checkLibrary:) userInfo:nil repeats:YES];
        [_libraryCheckTimer setTolerance:5.0];
        
        [self _checkLibrary:nil];
    }

    return self;
}


#pragma mark - Library Metadata

- (void) _checkLibrary:(NSTimer *)timer
{
    NSURL *libraryURL = nil;
    
    // Get URL for "iTunes Library.itl"
    {
        NSArray  *musicPaths = NSSearchPathForDirectoriesInDomains(NSMusicDirectory, NSUserDomainMask, YES);
        NSString *musicPath  = [musicPaths firstObject];
        
        NSString *itlPath = musicPath;
        itlPath = [itlPath stringByAppendingPathComponent:@"iTunes"];
        itlPath = [itlPath stringByAppendingPathComponent:@"iTunes Library.itl"];

        NSString *musicdbPath = musicPath;
        musicdbPath = [musicdbPath stringByAppendingPathComponent:@"Music"];
        musicdbPath = [musicdbPath stringByAppendingPathComponent:@"Music Library.musiclibrary"];
        musicdbPath = [musicdbPath stringByAppendingPathComponent:@"Library.musicdb"];

        if ([[NSFileManager defaultManager] fileExistsAtPath:musicdbPath]) {
            libraryURL = [NSURL fileURLWithPath:musicdbPath];

        } else if ([[NSFileManager defaultManager] fileExistsAtPath:itlPath]) {
            libraryURL = [NSURL fileURLWithPath:itlPath];
        }
    }

    EmbraceLog(@"MusicAppManager", @"libraryURL is: %@", libraryURL);
    
    NSDate *modificationDate = nil;
    NSError *error = nil;

    [libraryURL getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:&error];
    if (error) {
        EmbraceLog(@"MusicAppManager", @"Could not get modification date for %@: error: %@", libraryURL, error);
    }

    if (!error && [modificationDate isKindOfClass:[NSDate class]]) {
        NSTimeInterval timeInterval = [modificationDate timeIntervalSinceReferenceDate];
        
        if (timeInterval > _lastLibraryParseTime) {
            if (_lastLibraryParseTime) {
                EmbraceLog(@"MusicAppManager", @"Music.app Library modified!");
            }

            id<WorkerProtocol> worker = [GetAppDelegate() workerProxyWithErrorHandler:^(NSError *proxyError) {
                EmbraceLog(@"MusicAppManager", @"Received error for worker fetch: %@", proxyError);
            }];

            _lastLibraryParseTime = timeInterval;

            [worker performLibraryParseWithReply:^(NSDictionary *dictionary) {
                NSMutableDictionary *pathToLibraryMetadataMap = [NSMutableDictionary dictionaryWithCapacity:[dictionary count]];

                for (NSString *path in dictionary) {
                    MusicAppLibraryMetadata *metadata = [[MusicAppLibraryMetadata alloc] init];
                    
                    NSDictionary *trackData = [dictionary objectForKey:path];
                    [metadata setStartTime:[[trackData objectForKey:TrackKeyStartTime] doubleValue]];
                    [metadata setStopTime: [[trackData objectForKey:TrackKeyStopTime]  doubleValue]];

                    [pathToLibraryMetadataMap setObject:metadata forKey:sGetExpandedPath(path)];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    _didParseLibrary = YES;

                    if (![_pathToLibraryMetadataMap isEqualToDictionary:pathToLibraryMetadataMap]) {
                        _pathToLibraryMetadataMap = pathToLibraryMetadataMap;
                        [[NSNotificationCenter defaultCenter] postNotificationName:MusicAppManagerDidUpdateLibraryMetadataNotification object:self];
                    }
                });
            }];
        }
    }
}


- (MusicAppLibraryMetadata *) libraryMetadataForFileURL:(NSURL *)url
{
    NSString *path = sGetExpandedPath([url path]);
    return [_pathToLibraryMetadataMap objectForKey:path];
}


#pragma mark - Pasteboard Parsing

- (MusicAppPasteboardParseResult *) parsePasteboard:(NSPasteboard *)pasteboard
{
    NSMutableDictionary *trackIDToMetadataMap = [NSMutableDictionary dictionary];
    NSMutableArray *orderedTrackIDs  = [NSMutableArray array];

    NSMutableArray *metadataFileURLs = [NSMutableArray array];
    NSMutableArray *otherFileURLs    = [NSMutableArray array];
    
    auto parsePlaylist = ^(NSDictionary *playlist) {
        if (![playlist isKindOfClass:[NSDictionary class]]) {
            return;
        }

        NSArray *items = [playlist objectForKey:@"Playlist Items"];
        if (![items isKindOfClass:[NSArray class]]) {
            return;
        }
        
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:[NSDictionary class]]) {
                continue;
            }
        
            id trackIDObject = [item objectForKey:@"Track ID"];
            if (![trackIDObject respondsToSelector:@selector(integerValue)]) {
                trackIDObject = nil;
            }

            NSInteger trackID = [trackIDObject integerValue];
            if (trackID) [orderedTrackIDs addObject:@(trackID)];
        }
    };

    auto parsePlaylists = ^(NSArray *playlists) {
        if (![playlists isKindOfClass:[NSArray class]]) {
            return;
        }
        
        for (NSDictionary *playlist in playlists) {
            parsePlaylist(playlist);
        }
    };

    auto parseTrack = ^(NSString *key, NSDictionary *track) {
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
        NSInteger trackID   = [trackIDObject integerValue];
        
        if (!trackID) return;

        MusicAppPasteboardMetadata *metadata = [[MusicAppPasteboardMetadata alloc] init];
        [metadata setDuration:totalTime];
        [metadata setTitle:name];
        [metadata setArtist:artist];
        [metadata setLocation:sGetExpandedPath(location)];
        [metadata setTrackID:trackID];
        [metadata setDatabaseID:[key integerValue]];
        
        [trackIDToMetadataMap setObject:metadata forKey:@(trackID)];
    };

    auto parseTracks = ^(NSDictionary *tracks) {
        if (![tracks isKindOfClass:[NSDictionary class]]) {
            return;
        }
        
        for (NSString *key in tracks) {
            NSDictionary *track = [tracks objectForKey:key];
            parseTrack(key, track);
        }
    };

    auto parseMetadataRoot = ^(NSDictionary *root) {
        if (![root isKindOfClass:[NSDictionary class]]) {
            return;
        }

        parsePlaylists( [root objectForKey:@"Playlists"] );
        parseTracks(    [root objectForKey:@"Tracks"]    );
    };
    
    auto parsePasteboardItem = ^(NSPasteboardItem *item) {
        for (NSString *type in [item types]) {
            if ([type hasPrefix:@"com.apple."] && [type hasSuffix:@".metadata"]) {
                parseMetadataRoot([item propertyListForType:type]);
            }
        }
    };

    // Step 1, Fill metadataFileURLs from com.apple.*.metadata 
    {
        for (NSPasteboardItem *item in [pasteboard pasteboardItems]) {
            parsePasteboardItem(item);
        }

        for (NSNumber *trackID in orderedTrackIDs) {
            MusicAppPasteboardMetadata *metadata = [trackIDToMetadataMap objectForKey:trackID];
            
            NSString *location = [metadata location];
            NSURL    *fileURL  = location ? [NSURL fileURLWithPath:location] : nil;

            if (fileURL) [metadataFileURLs addObject:fileURL];
        }
    }

    // Step 2, Fill otherFileURLs with NSPasteboardTypeFileURL/kPasteboardTypeFileURLPromise
    {
        for (NSPasteboardItem *item in [pasteboard pasteboardItems]) {
            NSArray *types = [item types];

            BOOL hasPromise        = [types containsObject:(id)kPasteboardTypeFileURLPromise];
            BOOL hasPromiseContent = [types containsObject:(id)kPasteboardTypeFilePromiseContent];
              
            NSString *fileURLString = [item propertyListForType:NSPasteboardTypeFileURL];

            // In macOS Catalina 10.15.0, the new Music app likes to write a real URL
            // as a kPasteboardTypeFileURLPromise without kPasteboardTypeFilePromiseContent
            //
            if (!fileURLString && hasPromise && !hasPromiseContent) {
                fileURLString = [item propertyListForType:NSPasteboardTypeFileURL];
            }

            NSURL *fileURL = fileURLString ? [NSURL URLWithString:fileURLString] : nil;
            
            fileURL = [fileURL URLByStandardizingPath];
            fileURL = [fileURL URLByResolvingSymlinksInPath];
            
            if (fileURL) [otherFileURLs addObject:fileURL];
        }
    }

    // Step 3, Fill otherFileURLs with legacy NSFilenamesPboardType
    if ([otherFileURLs count] == 0) {
        NSArray *filenames = [pasteboard propertyListForType:@"NSFilenamesPboardType"];

        if (filenames) {
            for (NSString *filename in filenames) {
                NSURL *url = [NSURL fileURLWithPath:sGetExpandedPath(filename)];
                if (url) [otherFileURLs addObject:url];
            }
        }
    }
    
    NSArray *fileURLs = [metadataFileURLs count] > [otherFileURLs count] ? metadataFileURLs : otherFileURLs;
    NSArray *metadataArray = [trackIDToMetadataMap allValues];

    if ([fileURLs count] > 0 || [metadataArray count] > 0) {
        MusicAppPasteboardParseResult *result = [[MusicAppPasteboardParseResult alloc] init];

        [result setMetadataArray:metadataArray];
        [result setFileURLs:fileURLs];
        
        return result;
    }

    return nil;
}


#pragma mark - Pasteboard Metadata

- (void) clearPasteboardMetadata
{
    [_trackIDToPasteboardMetadataMap removeAllObjects];
}


- (void) addPasteboardMetadataArray:(NSArray *)array
{
    for (MusicAppPasteboardMetadata *metadata in array) {
        NSInteger trackID  = [metadata trackID];
        NSString *location = [metadata location];

        if (!_trackIDToPasteboardMetadataMap) _trackIDToPasteboardMetadataMap = [NSMutableDictionary dictionary];
        [_trackIDToPasteboardMetadataMap setObject:metadata forKey:@(trackID)];
        
        if (location) {
            if (!_pathToTrackIDMap) _pathToTrackIDMap = [NSMutableDictionary dictionary];
            [_pathToTrackIDMap setObject:@(trackID) forKey:sGetExpandedPath(location)];
        }
    }
}


- (MusicAppPasteboardMetadata *) pasteboardMetadataForFileURL:(NSURL *)url
{
    NSString *path = sGetExpandedPath([url path]);
    NSInteger trackID = [[_pathToTrackIDMap objectForKey:path] integerValue];
    return [_trackIDToPasteboardMetadataMap objectForKey:@(trackID)];
}


@end


#pragma mark - Other Classes

@implementation MusicAppLibraryMetadata

- (BOOL) isEqual:(id)otherObject
{
    if (![otherObject isKindOfClass:[MusicAppLibraryMetadata class]]) {
        return NO;
    }

    MusicAppLibraryMetadata *otherMetadata = (MusicAppLibraryMetadata *)otherObject;

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


@implementation MusicAppPasteboardParseResult
@end


@implementation MusicAppPasteboardMetadata
@end

