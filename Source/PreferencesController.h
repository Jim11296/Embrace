//
//  PreferencesController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-12.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Player, Preferences;

@interface PreferencesController : NSWindowController

- (IBAction) changeMainDevice:(id)sender;
- (IBAction) changeMainDeviceAttributes:(id)sender;

@property (nonatomic, weak)   IBOutlet NSPopUpButton *mainDevicePopUp;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *sampleRatePopUp;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *framesPopUp;
@property (nonatomic, weak)   IBOutlet NSButton      *hogModeButton;

// For bindings
@property (nonatomic, weak) Preferences *preferences;
@property (nonatomic, weak) Player *player;

@end
