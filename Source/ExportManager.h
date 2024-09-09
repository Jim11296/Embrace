// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>

@class Track;

typedef NS_ENUM(NSInteger, ExportManagerFormat) {
    ExportManagerFormatNone,
    ExportManagerFormatPlainText,
    ExportManagerFormatM3U
};


@interface ExportManager : NSObject

+ (instancetype) sharedInstance;

- (NSInteger) runModalWithTracks:(NSArray<Track *> *)tracks;

- (NSString *) suggestedNameWithTracks:(NSArray<Track *> *)tracks;
- (NSString *) stringWithFormat:(ExportManagerFormat)format tracks:(NSArray<Track *> *)tracks;

@end
