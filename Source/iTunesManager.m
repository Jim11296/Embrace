//
//  MetadataManager.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "iTunesManager.h"

#import <ScriptingBridge/ScriptingBridge.h>
#import "iTunes.h"

NSString * const iTunesManagerDidUpdateLibraryMetadataNotification = @"iTunesManagerDidUpdateLibraryMetadata";

static NSString * const sStartTimeKey = @"Start Time";
static NSString * const sStopTimeKey  = @"Stop Time";
static NSString * const sLocationKey  = @"Location";


@implementation iTunesMetadata
@end


@implementation iTunesLibraryMetadata

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: %p, %ld, \"%@\", %lg - %lg>", [self class], self, (long)[self trackID], [self location], [self startTime], [self stopTime]];
}


- (BOOL) isEqual:(id)otherObject
{
    if (![otherObject isKindOfClass:[iTunesLibraryMetadata class]]) {
        return NO;
    }

    iTunesLibraryMetadata *otherMetadata = (iTunesLibraryMetadata *)otherObject;

    return [[self location] isEqualToString:[otherMetadata location]] &&
           _startTime == otherMetadata->_startTime &&
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


@implementation iTunesManager {
    NSURL         *_libraryURL;
    NSTimeInterval _lastCheckTime;
    
    NSMutableDictionary *_pathToTrackIDMap;
    NSMutableDictionary *_trackIDToLibraryMetadataMap;
    NSMutableDictionary *_trackIDToPasteboardMetadataMap;

    BOOL _parsing;

    dispatch_queue_t _tunesQueue;
    
    NSTimer *_checkTimer;
    
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


+ (NSString *) _libraryXMLPath
{
    NSArray  *musicPaths = NSSearchPathForDirectoriesInDomains(NSMusicDirectory, NSUserDomainMask, YES);
    NSString *musicPath  = [musicPaths firstObject];
    
    NSString *iTunesPath = [musicPath  stringByAppendingPathComponent:@"iTunes"];
    NSString *xmlPathA   = [iTunesPath stringByAppendingPathComponent:@"iTunes Library.xml"];
    NSString *xmlPathB   = [iTunesPath stringByAppendingPathComponent:@"iTunes Music Library.xml"];

    BOOL existsA = [[NSFileManager defaultManager] fileExistsAtPath:xmlPathA];
    BOOL existsB = [[NSFileManager defaultManager] fileExistsAtPath:xmlPathB];
    
    NSError *error;
    NSDictionary *attributesA = [[NSFileManager defaultManager] attributesOfItemAtPath:xmlPathA error:&error];
    NSDictionary *attributesB = [[NSFileManager defaultManager] attributesOfItemAtPath:xmlPathB error:&error];

    NSDate *modificationDateA = [attributesA objectForKey:NSFileModificationDate];
    NSDate *modificationDateB = [attributesB objectForKey:NSFileModificationDate];

    if (existsA && existsB && modificationDateA && modificationDateB) {
        if ([modificationDateA isGreaterThan:modificationDateB]) {
            return xmlPathA;
        } else {
            return xmlPathB;
        }
        
    } else if (existsA) {
        return xmlPathA;
    } else if (existsB) {
        return xmlPathB;
    }
    
    return nil;
}


- (id) init
{
    if ((self = [super init])) {
        NSString *path = [iTunesManager _libraryXMLPath];
        _libraryURL = path ? [NSURL fileURLWithPath:path] : nil;

        EmbraceLog(@"iTunesManager", @"_libraryURL is: %@", _libraryURL);

        _checkTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(_checkLibrary:) userInfo:nil repeats:YES];
        
        if ([_checkTimer respondsToSelector:@selector(setTolerance:)]) {
            [_checkTimer setTolerance:5.0];
        }
        
        [self _checkLibrary:nil];
        
        _trackIDToLibraryMetadataMap    = [NSMutableDictionary dictionary];
        _trackIDToPasteboardMetadataMap = [NSMutableDictionary dictionary];
    }

    return self;
}


- (void) _checkLibrary:(NSTimer *)timer
{
    id       value = nil;
    NSError *error = nil;
    
    [_libraryURL getResourceValue:&value forKey:NSURLContentModificationDateKey error:&error];

    if (error) {
        EmbraceLog(@"iTunesManager", @"Could not get modification date for %@: error: %@", _libraryURL, error);
        [_checkTimer invalidate];
        _checkTimer = nil;
    }


    if (!error && [value isKindOfClass:[NSDate class]]) {
        NSTimeInterval timeInterval = [value timeIntervalSinceReferenceDate];
        
        if (timeInterval > _lastCheckTime) {
            if (_lastCheckTime) {
                EmbraceLog(@"iTunesManager", @"iTunes XML modified!");
            }

            if ([self _parseLibraryXML]) {
                _lastCheckTime = timeInterval;
            }
        }
    }
}


- (void) _addMetadata:(iTunesMetadata *)metadata to:(NSMutableDictionary *)trackIDToMetadataMap
{
    NSInteger trackID = [metadata trackID];

    [trackIDToMetadataMap setObject:metadata forKey:@(trackID)];
    NSString *location = [metadata location];
    
    if (location) {
        if (!_pathToTrackIDMap) _pathToTrackIDMap = [NSMutableDictionary dictionary];
        [_pathToTrackIDMap setObject:@(trackID) forKey:location];
    }
}


- (void) _parseLibraryXMLFinished:(NSArray *)results
{
    NSMutableDictionary *oldMetadataMap = _trackIDToLibraryMetadataMap;
    NSMutableDictionary *newMetadataMap = [NSMutableDictionary dictionary];

    for (iTunesMetadata *metadata in results) {
        [self _addMetadata:metadata to:newMetadataMap];
    }

    _trackIDToLibraryMetadataMap = newMetadataMap;

    _parsing = NO;
    _didParseLibrary = YES;

    if (![oldMetadataMap isEqualToDictionary:newMetadataMap]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:iTunesManagerDidUpdateLibraryMetadataNotification object:nil];
    }
}


- (BOOL) _parseLibraryXML
{
    if (_parsing) return NO;

    EmbraceLog(@"iTunesManager", @"Starting library parse...");

    __weak id weakSelf = self;
    
    _parsing = YES;

    NSURL *libraryURL = _libraryURL;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableArray *results = [NSMutableArray array];

        @try {
            NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfURL:libraryURL];

            NSDictionary *tracks = [dictionary objectForKey:@"Tracks"];

            for (id key in tracks) {
                NSDictionary *track = [tracks objectForKey:key];

                id startTimeNumber = [track objectForKey:sStartTimeKey];
                id stopTimeNumber  = [track objectForKey:sStopTimeKey];

                if (startTimeNumber || stopTimeNumber) {
                    id location = [track objectForKey:sLocationKey];
                
                    if ([location hasPrefix:@"file:"]) {
                        location = [[NSURL URLWithString:location] path];
                    }
                    
                    NSLog(@"%@: %@ - %@", location, startTimeNumber, stopTimeNumber);

                    iTunesLibraryMetadata *metadata = [[iTunesLibraryMetadata alloc] init];

                    [metadata setTrackID:[key integerValue]];
                    [metadata setLocation:location];

                    NSTimeInterval startTime = [startTimeNumber doubleValue] / 1000.0;
                    NSTimeInterval stopTime  = [stopTimeNumber doubleValue]  / 1000.0;

                    [metadata setStartTime:startTime];
                    [metadata setStopTime:stopTime];

                    [results addObject:metadata];
                }
            }

        } @catch (NSException *e) { }

        EmbraceLog(@"iTunesManager", @"Got results for %ld tracks", [results count]);

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _parseLibraryXMLFinished:results];
        });
    });
    
    return YES;
}



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
        [metadata setTrackID:[key integerValue]];
        
        [self _addMetadata:metadata to:_trackIDToPasteboardMetadataMap];
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


- (iTunesLibraryMetadata *) libraryMetadataForTrackID:(NSInteger)trackID
{
    return [_trackIDToLibraryMetadataMap objectForKey:@(trackID)];
}


- (iTunesLibraryMetadata *) libraryMetadataForFileURL:(NSURL *)url
{
    NSInteger trackID = [[_pathToTrackIDMap objectForKey:[url path]] integerValue];
    return [self libraryMetadataForTrackID:trackID];
}


- (iTunesPasteboardMetadata *) pasteboardMetadataForTrackID:(NSInteger)trackID
{
    return [_trackIDToPasteboardMetadataMap objectForKey:@(trackID)];
}


- (iTunesPasteboardMetadata *) pasteboardMetadataForFileURL:(NSURL *)url
{
    NSInteger trackID = [[_pathToTrackIDMap objectForKey:[url path]] integerValue];
    return [self pasteboardMetadataForTrackID:trackID];
}


- (void) clearPasteboardMetadata
{
    [_trackIDToPasteboardMetadataMap removeAllObjects];
}


@end
