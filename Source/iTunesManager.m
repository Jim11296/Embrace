//
//  MetadataManager.m
//  Terpsichore
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


@implementation iTunesManager {
    NSDictionary *_pathToTrackIDMap;
    NSDictionary *_trackIDToStartTimeMap;
    NSDictionary *_trackIDToStopTimeMap;
    BOOL _parsing;
    NSMutableArray *_readyCallbacks;
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


- (void) _parseFinished:(NSDictionary *)results
{
    _trackIDToStartTimeMap = [results objectForKey:sStartTimeKey];
    _trackIDToStopTimeMap  = [results objectForKey:sStopTimeKey];
    _pathToTrackIDMap      = [results objectForKey:sLocationKey];

    _parsing = NO;
    _ready = YES;
    
    for (iTunesManagerReadyCallback callback in _readyCallbacks) {
        callback();
    }
    
    _readyCallbacks = nil;
}


- (void) _parseLibraryXML
{
    if (_parsing) return;

    __weak id weakSelf = self;
    
    _parsing = YES;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableDictionary *trackIDToStartTimeMap = [NSMutableDictionary dictionary];
        NSMutableDictionary *trackIDToStopTimeMap  = [NSMutableDictionary dictionary];
        NSMutableDictionary *urlToTrackIDMap = nil;

        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        
        @try {
            NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSMusicDirectory, NSUserDomainMask, YES);
            NSString *path  = [paths firstObject];
            
            path = [path stringByAppendingPathComponent:@"iTunes"];
            path = [path stringByAppendingPathComponent:@"iTunes Library.xml"];
            
            NSURL *URL = [NSURL fileURLWithPath:path];

            NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfURL:URL];

            NSDictionary *tracks = [dictionary objectForKey:@"Tracks"];

            urlToTrackIDMap = [NSMutableDictionary dictionaryWithCapacity:[tracks count]];

            for (id key in tracks) {
                NSInteger trackID = [key integerValue];
                NSDictionary *track = [tracks objectForKey:key];
                
                id startTimeNumber = [track objectForKey:sStartTimeKey];
                id stopTimeNumber  = [track objectForKey:sStopTimeKey];
                id location        = [track objectForKey:sLocationKey];

                if (startTimeNumber) {
                    NSTimeInterval startTime = [startTimeNumber doubleValue] / 1000.0;
                    [trackIDToStartTimeMap setObject:@(startTime) forKey:@(trackID)];
                }

                if (stopTimeNumber) {
                    NSTimeInterval stopTime = [stopTimeNumber doubleValue] / 1000.0;
                    [trackIDToStopTimeMap setObject:@(stopTime) forKey:@(trackID)];
                }
                
                if (location) {
                    NSURL *URL = [NSURL URLWithString:location];
                    [urlToTrackIDMap setObject:@(trackID) forKey:[URL path]];
                }
            }

        } @catch (NSException *e) {

        }

        NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
        
        NSLog(@"%f", end - start);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _parseFinished:@{
                sStartTimeKey: trackIDToStartTimeMap,
                sStopTimeKey:  trackIDToStopTimeMap,
                sLocationKey:  urlToTrackIDMap
            }];
        });
    });
}


- (BOOL) getStartTime:(NSTimeInterval *)outStartTime forTrack:(NSInteger)trackID
{
    NSNumber *number = [_trackIDToStartTimeMap objectForKey:@(trackID)];
    if (!number) return NO;

    *outStartTime = [number doubleValue];
    
    return YES;
}


- (BOOL) getStopTime:(NSTimeInterval *)outEndTime forTrack:(NSInteger)trackID
{
    NSNumber *number = [_trackIDToStopTimeMap objectForKey:@(trackID)];
    if (!number) return NO;

    *outEndTime = [number doubleValue];
    
    return YES;
}


- (NSInteger) trackIDForURL:(NSURL *)url
{
    return [[_pathToTrackIDMap objectForKey:[url path]] integerValue];
}


- (void) addReadyCallback:(iTunesManagerReadyCallback)callback
{
    if (_ready) {
        callback();
    } else {
        if (!_readyCallbacks) _readyCallbacks = [NSMutableArray array];
        [_readyCallbacks addObject:callback];
    }
}


@end
