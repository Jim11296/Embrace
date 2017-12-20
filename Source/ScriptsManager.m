//
//  ScriptsManager.m
//  Embrace
//
//  Created by Ricci Adams on 2017-11-12.
//  Copyright © 2017 Ricci Adams. All rights reserved.
//

#import "ScriptsManager.h"
#import "FileSystemMonitor.h"
#import "Preferences.h"
#import "ScriptFile.h"
#import "Track.h"


NSString * const ScriptsManagerDidReloadNotification = @"ScriptsManagerDidReload";

@implementation ScriptsManager {
    NSArray *_allScriptFiles;
    NSAppleScript *_handlerScript;
    FileSystemMonitor *_monitor;
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
        [self _setup];
        [self _reloadScripts];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];
    }
    
    return self;
}


#pragma mark - Private Methods

- (void) _setup
{
    NSFileManager *manager = [NSFileManager defaultManager];

    NSURL *handlersDirectoryURL  = [self _handlersDirectoryURL];
    
    if (![manager fileExistsAtPath:[handlersDirectoryURL path]]) {
        NSError *error = nil;
        [manager createDirectoryAtURL:handlersDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    _monitor = [[FileSystemMonitor alloc] initWithURL:handlersDirectoryURL callback:^(NSArray *events) {
        [self _reloadScripts];
        [[NSNotificationCenter defaultCenter] postNotificationName:ScriptsManagerDidReloadNotification object:nil];
    }];
    
    [_monitor start];
}


- (NSURL *) _handlersDirectoryURL
{
    NSString *appSupport = GetApplicationSupportDirectory();
    
    return [NSURL fileURLWithPath:[appSupport stringByAppendingPathComponent:@"Handlers"]];
}


- (void) _reloadScripts
{
    NSURL *handlersDirectoryURL = [self _handlersDirectoryURL];

    NSError *dirError = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[handlersDirectoryURL path] error:&dirError];
   
    NSMutableArray *scriptFiles = [NSMutableArray array];

    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];

    for (NSString *item in contents) {
        if ([item hasPrefix:@"."]) continue;
        
        NSURL    *scriptURL = [handlersDirectoryURL URLByAppendingPathComponent:item];
        NSString *type      = nil;
        NSError  *error     = nil;

        if ([scriptURL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&error]) {
            if ([workspace type:type conformsToType:@"com.apple.applescript.script"] ||
                [workspace type:type conformsToType:@"com.apple.applescript.text"] ||
                [workspace type:type conformsToType:@"com.apple.applescript.script-bundle"]
            ) {
                ScriptFile *scriptFile = [[ScriptFile alloc] initWithURL:scriptURL];
                [scriptFiles addObject:scriptFile];
            }
        }
    }
    
    _allScriptFiles = scriptFiles;

    [self _updateHandlerScriptFile];
}


- (void) _updateHandlerScriptFile
{
    NSString *scriptHandlerName = [[Preferences sharedInstance] scriptHandlerName];
    if (![scriptHandlerName length]) {
        scriptHandlerName = nil;
    }

    _handlerScript     = nil;
    _handlerScriptFile = nil;

    for (ScriptFile *file in _allScriptFiles) {
        if (scriptHandlerName && [[file fileName] isEqualToString:scriptHandlerName]) {
            _handlerScriptFile = file;
            break;
        }
    }
    
    if (_handlerScriptFile) {
        NSDictionary *errorInfo = nil;

        _handlerScript = [[NSAppleScript alloc] initWithContentsOfURL:[_handlerScriptFile URL] error:&errorInfo];
        if (errorInfo) {
            [self _logErrorInfo:errorInfo when:@"loading" scriptFile:_handlerScriptFile];
        }
    }
}


- (NSAppleScript *) _handlerScript
{
    if (![_handlerScript isCompiled]) {
        NSDictionary *errorInfo = nil;
        [_handlerScript compileAndReturnError:&errorInfo];

        if (errorInfo) {
            [self _logErrorInfo:errorInfo when:@"compiling" scriptFile:_handlerScriptFile];
        }
    }
    
    return _handlerScript;
}


- (void) _logErrorInfo:(NSDictionary *)errorInfo when:(NSString *)whenString scriptFile:(ScriptFile *)scriptFile
{
    NSString *errorNumber  = [errorInfo objectForKey:NSAppleScriptErrorNumber];
    NSNumber *errorMessage = [errorInfo objectForKey:NSAppleScriptErrorMessage];
    
    NSString *finalString = [NSString stringWithFormat:@"Error %@ when %@ '%@': %@", errorNumber, whenString, [scriptFile fileName], errorMessage];

    NSLog(@"%@", finalString);
    EmbraceLog(@"ScriptsManager", @"%@", finalString);
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    NSString *scriptHandlerName = [[Preferences sharedInstance] scriptHandlerName];

    if (![scriptHandlerName length]) {
        scriptHandlerName = nil;
    }

    if (scriptHandlerName) {
        if (![[_handlerScriptFile fileName] isEqual:scriptHandlerName]) {
            [self _updateHandlerScriptFile];
        }

    } else {
        if (_handlerScriptFile) {
            [self _updateHandlerScriptFile];
        }
    }
}


#pragma mark - Public Methods

- (void) callMetadataAvailableWithTrack:(Track *)track
{
    NSAppleScript *handlerScript = [self _handlerScript];
    if (!handlerScript) return;
    
    NSAppleEventDescriptor *param  = [[track objectSpecifier] descriptor];
    if (!param) return;
    
    NSAppleEventDescriptor *target = [NSAppleEventDescriptor nullDescriptor];
    if (!target) return;

    NSAppleEventDescriptor *appleEvent = [[NSAppleEventDescriptor alloc] initWithEventClass:'embr' eventID:'he00' targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
    if (!appleEvent) return;

    [appleEvent setParamDescriptor:param forKeyword:'hetr'];

    NSDictionary *errorInfo = nil;
    
    [handlerScript executeAppleEvent:appleEvent error:&errorInfo];
    
    if (errorInfo) {
        [self _logErrorInfo:errorInfo when:@"running" scriptFile:_handlerScriptFile];
    }
}


- (void) openHandlersFolder
{
    [[NSWorkspace sharedWorkspace] openURL:[self _handlersDirectoryURL]];
}


@end
