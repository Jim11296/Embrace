//
//  AppDelegate.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EditEffectController, Effect;
@class Track;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction) clearHistory:(id)sender;
- (IBAction) openFile:(id)sender;
- (IBAction) copyHistory:(id)sender;
- (IBAction) saveHistory:(id)sender;
- (IBAction) exportHistory:(id)sender;

- (IBAction) playOrSoftPause:(id)sender;
- (IBAction) hardSkip:(id)sender;
- (IBAction) hardPause:(id)sender;

- (IBAction) showMainWindow:(id)sender;
- (IBAction) showEffectsWindow:(id)sender;
- (IBAction) showPreferences:(id)sender;
- (IBAction) showCurrentTrack:(id)sender;

- (IBAction) sendFeedback:(id)sender;
- (IBAction) viewOnAppStore:(id)sender;


// Debug
@property (nonatomic, weak) IBOutlet NSMenuItem *debugMenuItem;
- (IBAction) debugPopulatePlaylist:(id)sender;

- (EditEffectController *) editControllerForEffect:(Effect *)effect;
- (void) closeEditControllerForEffect:(Effect *)effect;

@end
