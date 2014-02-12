//
//  MetadataManager.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const iTunesManagerDidUpdateLibraryMetadataNotification;

@class iTunesLibraryMetadata, iTunesPasteboardMetadata;


@interface iTunesManager : NSObject

+ (id) sharedInstance;

@property (nonatomic, readonly) BOOL didParseLibrary;

- (void) extractMetadataFromPasteboard:(NSPasteboard *)pasteboard;
- (void) exportPlaylistWithName:(NSString *)name fileURLs:(NSArray *)fileURLs;

- (iTunesLibraryMetadata *) libraryMetadataForTrackID:(NSInteger)trackID;
- (iTunesLibraryMetadata *) libraryMetadataForFileURL:(NSURL *)url;

- (iTunesPasteboardMetadata *) pasteboardMetadataForTrackID:(NSInteger)trackID;
- (iTunesPasteboardMetadata *) pasteboardMetadataForFileURL:(NSURL *)url;

@end


@interface iTunesMetadata : NSObject
@property (nonatomic) NSInteger trackID;
@property (nonatomic, copy) NSString *location;
@end


@interface iTunesLibraryMetadata : iTunesMetadata
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@end


@interface iTunesPasteboardMetadata : iTunesMetadata
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic) NSTimeInterval duration;
@end