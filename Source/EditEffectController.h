//
//  EffectSettingsController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Effect;

@interface EditEffectController : NSWindowController

- (id) initWithEffect:(Effect *)effect;

- (IBAction) switchView:(id)sender;
- (IBAction) loadPreset:(id)sender;
- (IBAction) restoreDefaultValues:(id)sender;

@property (nonatomic, weak) IBOutlet NSView *containerView;
@property (nonatomic, weak) IBOutlet NSToolbarItem *modeToolbarItem;
@property (nonatomic, weak) IBOutlet NSSegmentedControl *modeControl;

@property (nonatomic, weak) Effect *effect;

@end
