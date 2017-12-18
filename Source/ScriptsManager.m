//
//  ScriptsManager.m
//  Embrace
//
//  Created by Ricci Adams on 2017-11-12.
//  Copyright © 2017 Ricci Adams. All rights reserved.
//

#import "ScriptsManager.h"
#import "Track.h"
#import "Scripting.h"

@implementation ScriptsManager {
    NSArray *_scripts;
}


+ (id) sharedInstance
{
    static ScriptsManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[ScriptsManager alloc] init];
    });

    return sSharedInstance;
}


- (instancetype) init
{
    if ((self = [super init])) {
        [self _makeScriptsDirectoryIfNeeded];
        [self reloadScripts];
    }
    
    return self;
}


- (NSURL *) _scriptsDirectoryURL
{
    NSString *appSupport = GetApplicationSupportDirectory();
    
    return [NSURL fileURLWithPath:[appSupport stringByAppendingPathComponent:@"Scripts"]];
}


- (void) _makeScriptsDirectoryIfNeeded
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *scriptsDirectoryURL = [self _scriptsDirectoryURL];

    if (![manager fileExistsAtPath:[scriptsDirectoryURL path]]) {
        NSError *error = nil;
        [manager createDirectoryAtURL:scriptsDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
    }
}


- (NSString *) scriptsDirectory
{
    return [[self _scriptsDirectoryURL] path];
}


- (void) reloadScripts
{
    NSURL *scriptsDirectoryURL = [self _scriptsDirectoryURL];
    NSError *dirError = nil;

    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[scriptsDirectoryURL path] error:&dirError];
    
    _scripts = nil;
    
    NSMutableArray *scripts = [NSMutableArray array];
    
    for (NSString *item in contents) {
        NSDictionary *scriptError = nil;
        
        NSURL *scriptURL = [scriptsDirectoryURL URLByAppendingPathComponent:item];
        NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&scriptError];
        
        if (scriptError) {
            NSLog(@"Embrace error when loading script: %@: %@", item, scriptError);
            script = nil;
        }
        
        if (script) [scripts addObject:script];
    }
    
    _scripts = scripts;
}


- (void) callMetadataAvailableWithTrack:(Track *)track
{
    NSAppleEventDescriptor *target = [NSAppleEventDescriptor nullDescriptor];
    if (!target) return;

    NSAppleEventDescriptor *param  = [[track objectSpecifier] descriptor];
    if (!param) return;
    
    NSAppleEventDescriptor *appleEvent = [[NSAppleEventDescriptor alloc] initWithEventClass:'embr' eventID:'he00' targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
    if (!appleEvent) return;

    [appleEvent setParamDescriptor:param forKeyword:'hetr'];

    for (NSAppleScript *script in _scripts) {
        NSDictionary *errorInfo = nil;
        NSAppleEventDescriptor *result = nil;
        @try {
            result = [script executeAppleEvent:appleEvent error:&errorInfo];
        } @catch (NSException *e) {
            NSLog(@"NSException: %@", e);
        }

        if (errorInfo) {
            NSLog(@"Embrace error when running script: %@", errorInfo);
        }
    }
}

@end
