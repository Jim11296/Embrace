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


static NSString * const sStartTimeKey = @"Start Time";
static NSString * const sStopTimeKey  = @"Stop Time";
static NSString * const sLocationKey  = @"Location";


@implementation iTunesMetadata

- (void) mergeIn:(iTunesMetadata *)other
{
    if (other->_startTime && !_startTime) _startTime = other->_startTime;
    if (other->_stopTime  && !_stopTime)  _stopTime  = other->_stopTime;
    if (other->_artist    && !_artist)    _artist    = other->_artist;
    if (other->_title     && !_title)     _title     = other->_title;
    if (other->_location  && !_location)  _location  = other->_location;
    if (other->_duration  && !_duration)  _duration  = other->_duration;
}

@end


@implementation iTunesManager {
    NSMutableDictionary *_pathToTrackIDMap;
    NSMutableDictionary *_trackIDToMetadataMap;

    BOOL _parsing;
    NSMutableArray *_metadataReadyCallbacks;

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
        [self _parseLibraryXML];
    }

    return self;
}


- (void) _addMetadata:(iTunesMetadata *)metadata
{
    NSInteger trackID = [metadata trackID];

    iTunesMetadata *existing = [_trackIDToMetadataMap objectForKey:@(trackID)];
    NSString *location = [existing location];

    if (existing) {
        [existing mergeIn:metadata];
    } else {
        if (!_trackIDToMetadataMap) _trackIDToMetadataMap = [NSMutableDictionary dictionary];
        [_trackIDToMetadataMap setObject:metadata forKey:@(trackID)];
        location = [metadata location];
    }
    
    if (location) {
        if (!_pathToTrackIDMap) _pathToTrackIDMap = [NSMutableDictionary dictionary];
        [_pathToTrackIDMap setObject:@(trackID) forKey:location];
    }
}


- (void) _parseFinished:(NSArray *)results
{
    for (iTunesMetadata *metadata in results) {
        [self _addMetadata:metadata];
    }

    _parsing = NO;
    _metadataReady = YES;
    
    for (iTunesManagerMetadataReadyCallback callback in _metadataReadyCallbacks) {
        callback(self);
    }
    
    _metadataReadyCallbacks = nil;
}


- (void) _parseLibraryXML
{
    if (_parsing) return;

    __weak id weakSelf = self;
    
    _parsing = YES;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableArray *results = [NSMutableArray array];

        @try {
            NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSMusicDirectory, NSUserDomainMask, YES);
            NSString *path  = [paths firstObject];
            
            path = [path stringByAppendingPathComponent:@"iTunes"];
            path = [path stringByAppendingPathComponent:@"iTunes Library.xml"];
            
            NSURL *URL = [NSURL fileURLWithPath:path];

            NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfURL:URL];

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

                    iTunesMetadata *metadata = [[iTunesMetadata alloc] init];
                    
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

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _parseFinished:results];
        });
    });
}


- (iTunesMetadata *) metadataForTrackID:(NSInteger)trackID
{
    return [_trackIDToMetadataMap objectForKey:@(trackID)];
}


- (iTunesMetadata *) metadataForFileURL:(NSURL *)url
{
    NSInteger trackID = [[_pathToTrackIDMap objectForKey:[url path]] integerValue];
    return [self metadataForTrackID:trackID];
}


- (void) addMetadataReadyCallback:(iTunesManagerMetadataReadyCallback)callback
{
    iTunesManagerMetadataReadyCallback cb = [callback copy];

    if (_metadataReady) {
        dispatch_async(dispatch_get_main_queue(), ^{
            cb(self);
        });

    } else {
        if (!_metadataReadyCallbacks) _metadataReadyCallbacks = [NSMutableArray array];
        [_metadataReadyCallbacks addObject:cb];
    }
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

        iTunesMetadata *metadata = [[iTunesMetadata alloc] init];
        [metadata setDuration:totalTime];
        [metadata setTitle:name];
        [metadata setArtist:artist];
        [metadata setLocation:location];
        [metadata setTrackID:[key integerValue]];
        
        [self _addMetadata:metadata];
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


@end
