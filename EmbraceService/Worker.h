//
//  EmbraceService.h
//  EmbraceService
//
//  Created by Ricci Adams on 2016-05-07.
//  Copyright © 2016 Ricci Adams. All rights reserved.
//

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
                 internalURL: (NSURL *) internalURL
                 externalURL: (NSURL *) externalURL
                       reply: (void (^)(NSDictionary *))reply;

@end
