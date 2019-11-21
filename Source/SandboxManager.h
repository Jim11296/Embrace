//
//  SandboxManager.h
//  Embrace
//
//  Created by Ricci Adams on 11/13/19.
//  Copyright © 2019 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SandboxManager : NSObject {
    
}


+ (instancetype) sharedInstance;

- (void) showAddGrantDialog;
- (void) showResetGrantsDialog;

- (void) addPersistentGrantToURL:(NSURL *)fileURL;
- (void) removeAllPersistentGrants;

- (void) startAccessToURL:(NSURL *)fileURL;
- (void) stopAccessToURL:(NSURL *)fileURL;

@end

