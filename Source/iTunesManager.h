//
//  MetadataManager.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^iTunesManagerReadyCallback)();

@interface iTunesManager : NSObject

+ (id) sharedInstance;

@property (nonatomic, readonly, getter=isReady) BOOL ready;
- (void) addReadyCallback:(iTunesManagerReadyCallback)callback;

- (NSInteger) trackIDForURL:(NSURL *)url;

- (BOOL) getStartTime:(NSTimeInterval *)outStartTime forTrack:(NSInteger)trackID;
- (BOOL) getStopTime: (NSTimeInterval *)outEndTime   forTrack:(NSInteger)trackID;

@end
