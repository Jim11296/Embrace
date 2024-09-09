// (c) 2017-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

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
