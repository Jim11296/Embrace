// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

extern NSString * const MusicAppManagerDidUpdateLibraryMetadataNotification;

@class MusicAppLibraryMetadata, MusicAppPasteboardMetadata;


@interface MusicAppManager : NSObject

+ (id) sharedInstance;

- (MusicAppLibraryMetadata *) libraryMetadataForFileURL:(NSURL *)url;
@property (nonatomic, readonly) BOOL didParseLibrary;

- (void) clearPasteboardMetadata;
- (void) extractMetadataFromPasteboard:(NSPasteboard *)pasteboard;
- (MusicAppPasteboardMetadata *) pasteboardMetadataForFileURL:(NSURL *)url;

@end


@interface MusicAppLibraryMetadata : NSObject
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@end


@interface MusicAppPasteboardMetadata : NSObject
@property (nonatomic) NSInteger databaseID;
@property (nonatomic, copy) NSString *location;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic) NSTimeInterval duration;
@end
