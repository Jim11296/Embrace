// (c) 2019-2020 Ricci Adams.  All rights reserved.

#import "SandboxManager.h"


static NSData *sGetBookmarkDataWithFileURL(NSURL *fileURL)
{
    NSURLBookmarkCreationOptions options = NSURLBookmarkCreationWithSecurityScope;

    NSError *error = nil;
    
    NSData *bookmark = [fileURL bookmarkDataWithOptions: options
                         includingResourceValuesForKeys:  @[ NSURLNameKey, NSURLPathKey ]
                                          relativeToURL: nil
                                                  error: &error];

    if (error) {
        EmbraceLog(@"SandboxManager", @"Couldn't make bookmark for URL: %@, error: %@", fileURL, error);
    }

    return bookmark;
}


@implementation SandboxManager {
    NSArray<SandboxPersistentGrant *> *_grants;
}


+ (instancetype) sharedInstance
{
    static SandboxManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[SandboxManager alloc] init];
    });
    
    return sSharedInstance;
}


- (instancetype) init
{
    if ((self = [super init])) {
        [self _loadState];
    }
    
    return self;
}


- (void) _loadState
{
    NSMutableArray *grants = [NSMutableArray array];

    NSArray *dataArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"sandbox-persistent-grants"];

    if ([dataArray isKindOfClass:[NSArray class]]) {
        for (NSData *bookmarkData in dataArray) {
            if (![bookmarkData isKindOfClass:[NSData class]]) {
                continue;
            }

            SandboxPersistentGrant *grant = [[SandboxPersistentGrant alloc] initWithBookmarkData:bookmarkData];
            if (!grant) continue;

            [grants addObject:grant];
        }
    } 
       
    [self setGrants:grants];
}


- (void) _saveState
{
    NSMutableArray *dataArray = [NSMutableArray array];
    
    for (SandboxPersistentGrant *grant in _grants) {
        NSData *data = [grant bookmarkData];
        if (data) [dataArray addObject:data];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:dataArray forKey:@"sandbox-persistent-grants"];
}


- (void) startAccessToURL:(NSURL *)fileURL
{
    [fileURL startAccessingSecurityScopedResource];
    
    for (SandboxPersistentGrant *grant in _grants) {
        [grant startAccessingSecurityScopedResource];
    }
}


- (void) stopAccessToURL:(NSURL *)fileURL
{
    [fileURL stopAccessingSecurityScopedResource];

    for (SandboxPersistentGrant *grant in _grants) {
        [grant stopAccessingSecurityScopedResource];
    }
}



- (void) setGrants:(NSArray<SandboxPersistentGrant *> *)grants
{
    if (_grants != grants) {
        _grants = grants;
        [self _saveState];
    }
}


@end


@implementation SandboxPersistentGrant {
    NSURL  *_accessedFileURL;
    NSData *_bookmarkData;
    NSString *_displayName;
}


- (instancetype) initWithFileURL:(NSURL *)fileURL
{
    return [self initWithBookmarkData:sGetBookmarkDataWithFileURL(fileURL)];
}


- (instancetype) initWithBookmarkData:(NSData *)bookmarkData
{
    if ((self = [super init])) {
        _bookmarkData = bookmarkData;
    }

    return self;
}


- (void) dealloc
{
    [self stopAccessingSecurityScopedResource];
}


- (NSString *) displayName
{
    if (!_displayName) {
        NSDictionary *values = [NSURL resourceValuesForKeys:@[ NSURLNameKey, NSURLPathKey ] fromBookmarkData:_bookmarkData];
        NSString     *path   = [values objectForKey:NSURLPathKey];
        NSString     *name   = [values objectForKey:NSURLNameKey];

        _displayName = path ? path : name;
    }
    
    return _displayName;
}


- (void) startAccessingSecurityScopedResource
{
    if (_accessedFileURL) return;
    
    NSDictionary *resourceValues   = [NSURL resourceValuesForKeys:@[ NSURLNameKey ] fromBookmarkData:_bookmarkData];
    NSString     *originalFileName = [resourceValues objectForKey:NSURLNameKey];
     
    NSURLBookmarkResolutionOptions options =
        NSURLBookmarkResolutionWithoutUI |
        NSURLBookmarkResolutionWithSecurityScope;

    NSError *error = nil;
    BOOL isStale = NO;

    NSURL *fileURL = [NSURL URLByResolvingBookmarkData:_bookmarkData options:options relativeToURL:nil bookmarkDataIsStale:&isStale error:&error];

    if (error) {
        EmbraceLog(@"SandboxManager", @"Couldn't resolve URL for %@", originalFileName);
    }

    if (fileURL && isStale) {
        EmbraceLog(@"SandboxManager", @"Remaking bookmark for %@", originalFileName);
        _bookmarkData = sGetBookmarkDataWithFileURL(fileURL);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[SandboxManager sharedInstance] _saveState];
        });
    }
    
    if ([fileURL startAccessingSecurityScopedResource]) {
        _accessedFileURL = fileURL;
    }
}


- (void) stopAccessingSecurityScopedResource
{
    if (!_accessedFileURL) return;
    [_accessedFileURL stopAccessingSecurityScopedResource];
    _accessedFileURL = nil;
}


@end


