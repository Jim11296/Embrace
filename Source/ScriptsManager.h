//
//  ScriptsManager.h
//  Embrace
//
//  Created by Ricci Adams on 2017-11-12.
//  Copyright © 2017 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const ScriptsManagerDidReloadNotification;

@class Track, ScriptFile;

@interface ScriptsManager : NSObject

+ (instancetype) sharedInstance;

- (void) openHandlersFolder;

- (void) callMetadataAvailableWithTrack:(Track *)track;

@property (nonatomic, readonly) NSArray<ScriptFile *> *allScriptFiles;
@property (nonatomic, readonly) ScriptFile *handlerScriptFile;

@property (nonatomic) NSMenuItem *scriptsMenuItem;

@end
