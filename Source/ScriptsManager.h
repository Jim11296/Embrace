//
//  ScriptsManager.h
//  Embrace
//
//  Created by Ricci Adams on 2017-11-12.
//  Copyright © 2017 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Track;

@interface ScriptsManager : NSObject

+ (instancetype) sharedInstance;

- (NSString *) scriptsDirectory;
- (void) reloadScripts;

- (void) callMetadataAvailableWithTrack:(Track *)track;

@end
