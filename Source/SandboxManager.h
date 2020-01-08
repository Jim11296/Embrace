// (c) 2019-2020 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@class SandboxPersistentGrant;

@interface SandboxManager : NSObject {
    
}


+ (instancetype) sharedInstance;

- (void) startAccessToURL:(NSURL *)fileURL;
- (void) stopAccessToURL:(NSURL *)fileURL;

@property (nonatomic) NSArray<SandboxPersistentGrant *> *grants;

@end


@interface SandboxPersistentGrant : NSObject

- (instancetype) initWithFileURL:(NSURL *)fileURL;
- (instancetype) initWithBookmarkData:(NSData *)bookmarkData;

@property (nonatomic, readonly) NSData *bookmarkData;

- (void) startAccessingSecurityScopedResource;
- (void) stopAccessingSecurityScopedResource;

@end
