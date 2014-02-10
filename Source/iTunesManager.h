//
//  MetadataManager.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const iTunesManagerDidUpdateStartAndStopTimesNotification;

@class iTunesManager, iTunesMetadata;


@interface iTunesManager : NSObject

+ (id) sharedInstance;

- (void) extractMetadataFromPasteboard:(NSPasteboard *)pasteboard;

- (iTunesMetadata *) metadataForFileURL:(NSURL *)url;
- (iTunesMetadata *) metadataForTrackID:(NSInteger)trackID;

@property (nonatomic, readonly) BOOL didParseLibrary;

- (void) exportPlaylistWithName:(NSString *)name fileURLs:(NSArray *)fileURLs;

@end


@interface iTunesMetadata : NSObject

- (void) mergeIn:(iTunesMetadata *)other;

@property (nonatomic) NSInteger trackID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *location;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@end