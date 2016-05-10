//
//  OutputWindowController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

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
- (NSString *) stringWithFormat:(ExportManagerFormat)format tracks:(NSArray<Track *> *)tracks;

@end
