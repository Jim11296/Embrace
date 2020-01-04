// (c) 2019-2020 Ricci Adams.  All rights reserved.

#import "SandboxManager.h"


@interface SandboxPersistentGrant : NSObject

- (instancetype) initWithBookmarkData:(NSData *)bookmarkData;

@property (nonatomic, readonly) NSData *bookmarkData;

- (void) startAccessingSecurityScopedResource;
- (void) stopAccessingSecurityScopedResource;

@end


static NSData *sGetBookmarkDataWithFileURL(NSURL *fileURL)
{
    NSURLBookmarkCreationOptions options = NSURLBookmarkCreationWithSecurityScope;

    NSError *error = nil;
    
    NSData *bookmark = [fileURL bookmarkDataWithOptions: options
                         includingResourceValuesForKeys:  @[ NSURLNameKey ]
                                          relativeToURL: nil
                                                  error: &error];

    if (error) {
        EmbraceLog(@"SandboxManager", @"Couldn't make bookmark for URL: %@, error: %@", fileURL, error);
    }

    return bookmark;
}


@implementation SandboxManager {
    NSMutableArray<SandboxPersistentGrant *> *_grants;
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


- (void) _addGrantWithBookmarkData:(NSData *)bookmarkData
{
    if (!bookmarkData) return;

    SandboxPersistentGrant *grant = [[SandboxPersistentGrant alloc] initWithBookmarkData:bookmarkData];
    if (!grant) return;

    if (!_grants) _grants = [NSMutableArray array];
    [_grants addObject:grant];
}


- (void) _loadState
{
    NSArray *dataArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"sandbox-grants"];

    if (![dataArray isKindOfClass:[NSArray class]]) {
        return;
    }

    for (NSData *bookmarkData in dataArray) {
        if (![bookmarkData isKindOfClass:[NSData class]]) {
            continue;
        }
        
        [self _addGrantWithBookmarkData:bookmarkData];
    }
}


- (void) _saveState
{
    NSMutableArray *dataArray = [NSMutableArray array];
    
    for (SandboxPersistentGrant *grant in _grants) {
        NSData *data = [grant bookmarkData];
        if (data) [dataArray addObject:data];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:dataArray forKey:@"sandbox-grants"];
}


- (void) addPersistentGrantToURL:(NSURL *)fileURL
{
    [self _addGrantWithBookmarkData:sGetBookmarkDataWithFileURL(fileURL)];
    [self _saveState];
}


- (void) removeAllPersistentGrants
{
    _grants = nil;
    [self _saveState];
}


- (void) showAddGrantDialog
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    [openPanel setTitle:NSLocalizedString(@"Grant Sandbox Access", nil)];

    [openPanel setPrompt:NSLocalizedString(@"Grant Access", nil)];
    [openPanel setAllowedFileTypes:@[ NSFileTypeDirectory ]];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:@"/"]];

    if ([openPanel runModal] == NSModalResponseOK) {
        NSURL *fileURL = [openPanel URL];

        if (fileURL) {
            [self addPersistentGrantToURL:fileURL];
        }
    }
}


- (void) showResetGrantsDialog
{
    NSAlert *alert = [[NSAlert alloc] init];

    [alert setMessageText:NSLocalizedString(@"Reset sandbox access?", nil)];
    [alert setInformativeText:NSLocalizedString(@"All previously granted sandbox permissions will be cleared.", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Reset",  nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert setAlertStyle:NSAlertStyleWarning];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [self removeAllPersistentGrants];
    }
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


@end


@implementation SandboxPersistentGrant {
    NSURL  *_accessedFileURL;
    NSData *_bookmarkData;
}


- (instancetype) initWithBookmarkData:(NSData *)bookmarkData
{
    if ((self = [super init])) {
        _bookmarkData = bookmarkData;
    }

    return self;
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


