// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>

extern NSString * const MusicAppManagerDidUpdateLibraryMetadataNotification;

@class MusicAppLibraryMetadata, MusicAppPasteboardMetadata, MusicAppPasteboardParseResult;


@interface MusicAppManager : NSObject

+ (id) sharedInstance;

- (MusicAppLibraryMetadata *) libraryMetadataForFileURL:(NSURL *)url;
@property (nonatomic, readonly) BOOL didParseLibrary;

- (MusicAppPasteboardParseResult *) parsePasteboard:(NSPasteboard *)pasteboard;

- (void) clearPasteboardMetadata;
- (void) addPasteboardMetadataArray:(NSArray *)array;
- (MusicAppPasteboardMetadata *) pasteboardMetadataForFileURL:(NSURL *)url;

@end


@interface MusicAppPasteboardParseResult : NSObject

@property (nonatomic) NSArray<MusicAppPasteboardMetadata *> *metadataArray;
@property (nonatomic) NSArray<NSURL *> *fileURLs;

@end


@interface MusicAppLibraryMetadata : NSObject
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval stopTime;
@end


@interface MusicAppPasteboardMetadata : NSObject

@property (nonatomic) NSInteger trackID;
@property (nonatomic) NSInteger databaseID;
@property (nonatomic, copy) NSString *location;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic) NSTimeInterval duration;
@end
