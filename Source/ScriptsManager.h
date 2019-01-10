// (c) 2017-2019 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

extern NSString * const ScriptsManagerDidReloadNotification;

@class Track, ScriptFile;


@interface ScriptsManager : NSObject

+ (instancetype) sharedInstance;

- (void) revealScriptsFolder;

- (void) callMetadataAvailableWithTrack:(Track *)track;

@property (nonatomic, readonly) NSArray<ScriptFile *> *allScriptFiles;
@property (nonatomic, readonly) ScriptFile *handlerScriptFile;

@property (nonatomic) NSMenuItem *scriptsMenuItem;

@end
