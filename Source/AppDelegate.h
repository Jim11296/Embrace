//
//  AppDelegate.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EditEffectController, ViewTrackController, Effect;
@class SetlistController, Track;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (void) displayErrorForTrackError:(NSInteger)trackError;

- (IBAction) openFile:(id)sender;

- (IBAction) clearSetlist:(id)sender;
- (IBAction) copySetlist:(id)sender;
- (IBAction) saveSetlist:(id)sender;
- (IBAction) exportSetlist:(id)sender;

- (IBAction) changeViewLayout:(id)sender;
- (IBAction) changeViewAttributes:(id)sender;
- (IBAction) revealEndTime:(id)sender;

- (IBAction) performPreferredPlaybackAction:(id)sender;
- (IBAction) hardSkip:(id)sender;
- (IBAction) hardPause:(id)sender;

- (IBAction) increaseVolume:(id)sender;
- (IBAction) decreaseVolume:(id)sender;
- (IBAction) increaseAutoGap:(id)sender;
- (IBAction) decreaseAutoGap:(id)sender;

- (IBAction) showSetlistWindow:(id)sender;
- (IBAction) showEffectsWindow:(id)sender;
- (IBAction) showPreferences:(id)sender;
- (IBAction) showCurrentTrack:(id)sender;

- (IBAction) sendFeedback:(id)sender;
- (IBAction) viewOnAppStore:(id)sender;

- (IBAction) openAcknowledgements:(id)sender;

@property (nonatomic, readonly) SetlistController *setlistController;

- (EditEffectController *) editControllerForEffect:(Effect *)effect;
- (void) closeEditControllerForEffect:(Effect *)effect;

- (ViewTrackController *) viewTrackControllerForTrack:(Track *)track;
- (void) closeViewTrackControllerForEffect:(Track *)track;

// Debug
- (IBAction) showDebugWindow:(id)sender;

- (IBAction) sendCrashReports:(id)sender;

@property (nonatomic, weak) IBOutlet NSMenuItem *debugMenuItem;

@property (nonatomic, weak) IBOutlet NSMenuItem *crashReportSeparator;
@property (nonatomic, weak) IBOutlet NSMenuItem *crashReportMenuItem;

@end
