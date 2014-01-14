//
//  AppDelegate.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class EditEffectController, Effect;
@class EditTrackController, Track;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction) showMainWindow:(id)sender;
- (IBAction) showEffectsWindow:(id)sender;
- (IBAction) showPreferences:(id)sender;

- (EditEffectController *) editControllerForEffect:(Effect *)effect;
- (EditEffectController *) editControllerForTrack:(Track *)track;

- (void) closeEditControllerForEffect:(Effect *)effect;
- (void) closeEditControllerForTrack:(Track *)track;

@end
