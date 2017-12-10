//  Copyright (c) 2016-2017 Ricci Adams. All rights reserved.


#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, WorkerTrackCommand) {
    WorkerTrackCommandReadMetadata,         // Reads the file metadating using AVAsset
    WorkerTrackCommandReadLoudness,         // Reads loudness via LoudnessAnalyzer
    WorkerTrackCommandReadLoudnessImmediate // Reads loudness via LoudnessAnalyzer immediately
};


@protocol WorkerProtocol

- (void) cancelUUID:(NSUUID *)uuid;

- (void) performTrackCommand: (WorkerTrackCommand) command
                        UUID: (NSUUID *) uuid
                bookmarkData: (NSData *) bookmarkData
            originalFilename: (NSString *) originalFilename
                       reply: (void (^)(NSDictionary *))reply;

- (void) performLibraryParseWithReply: (void (^)(NSDictionary *))reply;

@end
