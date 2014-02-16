//
//  DebugController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-02-15.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#if DEBUG

@interface DebugController : NSWindowController

- (IBAction) populatePlaylist:(id)sender;
- (IBAction) playPauseLoop:(id)sender;

- (IBAction) showIssueDialog:(id)sender;

- (IBAction) doFlipAnimation:(id)sender;


@end

#endif
