// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

extern NSString * const iTunesManagerDidUpdateLibraryMetadataNotification;

@class iTunesLibraryMetadata, iTunesPasteboardMetadata;


@interface iTunesManager : NSObject

+ (id) sharedInstance;

- (iTunesLibraryMetadata *) libraryMetadataForFileURL:(NSURL *)url;
@property (nonatomic, readonly) BOOL didParseLibrary;

- (void) clearPasteboardMetadata;
- (void) extractMetadataFromPasteboard:(NSPasteboard *)pasteboard;
- (iTunesPasteboardMetadata *) pasteboardMetadataForFileURL:(NSURL *)url;

@end


@interface iTunesLibraryMetadata : NSObject
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@end


@interface iTunesPasteboardMetadata : NSObject
@property (nonatomic) NSInteger databaseID;
@property (nonatomic, copy) NSString *location;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic) NSTimeInterval duration;
@end
