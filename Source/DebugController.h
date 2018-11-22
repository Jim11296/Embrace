// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>

#if DEBUG

@interface DebugController : NSWindowController

- (IBAction) populatePlaylist:(id)sender;
- (IBAction) playPauseLoop:(id)sender;

- (IBAction) showIssueDialog:(id)sender;

- (IBAction) explode:(id)sender;


@end

#endif
