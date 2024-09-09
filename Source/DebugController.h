// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Cocoa/Cocoa.h>

#if DEBUG

@interface DebugController : NSWindowController

- (IBAction) populatePlaylist:(id)sender;
- (IBAction) playPauseLoop:(id)sender;

- (IBAction) showIssueDialog:(id)sender;

- (IBAction) explode:(id)sender;


@end

#endif
