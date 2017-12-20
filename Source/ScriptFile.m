//
//  ScriptsManager.m
//  Embrace
//
//  Created by Ricci Adams on 2017-11-12.
//  Copyright © 2017 Ricci Adams. All rights reserved.
//

#import "ScriptFile.h"

@implementation ScriptFile {
    NSAppleScript *_appleScript;
}


- (instancetype) initWithURL:(NSURL *)URL
{
    if ((self = [super init])) {
        _URL = URL;
    }
    
    return self;
}


- (NSString *) fileName
{
    return [_URL lastPathComponent];
}


- (NSString *) displayName
{
    return [[_URL lastPathComponent] stringByDeletingPathExtension];
}


@end
