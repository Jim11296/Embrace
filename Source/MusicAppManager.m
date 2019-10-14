// (c) 2014-2019 Ricci Adams.  All rights reserved.

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


@implementation MusicAppPasteboardMetadata

+ (NSArray *) pasteboardMetadataArrayWithPasteboard:(NSPasteboard *)pasteboard
{
    NSMutableArray *result = [NSMutableArray array];

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
        NSInteger trackID   = [trackIDObject integerValue];
        
        if (!trackID) return;

        MusicAppPasteboardMetadata *metadata = [[MusicAppPasteboardMetadata alloc] init];
        [metadata setDuration:totalTime];
        [metadata setTitle:name];
        [metadata setArtist:artist];
        [metadata setLocation:location];
        [metadata setTrackID:trackID];
        [metadata setDatabaseID:[key integerValue]];
        
        [result addObject:metadata];
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
            if ([type hasPrefix:@"com.apple."] && [type hasSuffix:@".metadata"]) {
                parseRoot([item propertyListForType:type]);
            }
        }
    }
    
    return result;
}

@end

