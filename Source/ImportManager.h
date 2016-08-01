//
//  ImportManager.h
//  Embrace
//
//  Created by Ricci Adams on 2016-07-31.
//  Copyright © 2016 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Track;

@interface ImportManager : NSObject

+ (instancetype) sharedInstance;

- (BOOL) canOpenURLs:(NSArray<NSURL *> *)urls;

- (NSArray<Track *> *) tracksWithURLs:(NSArray<NSURL *> *)urls;

@end
