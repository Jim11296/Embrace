//
//  PreferencesController.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-12.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Preferences;

@interface PreferencesController : NSWindowController

- (IBAction) selectPane:(id)sender;

- (IBAction) changeMainDevice:(id)sender;
- (IBAction) changeMainDeviceAttributes:(id)sender;
- (IBAction) changeEditingDevice:(id)sender;

- (IBAction) changePreferredLibrary:(id)sender;

@property (nonatomic, weak) IBOutlet NSToolbar *toolbar;
@property (nonatomic, weak) IBOutlet NSToolbarItem *generalItem;
@property (nonatomic, weak) IBOutlet NSToolbarItem *devicesItem;

@property (nonatomic, strong) IBOutlet NSView *generalPane;
@property (nonatomic, strong) IBOutlet NSView *devicesPane;

@property (nonatomic, weak)   IBOutlet NSPopUpButton *preferredLibraryPopUp;
@property (nonatomic, weak)   IBOutlet NSMenuItem    *preferredLibraryLocationItem;
@property (nonatomic, weak)   IBOutlet NSMenuItem    *preferredLibrarySeparatorItem;

@property (nonatomic, strong) IBOutlet NSView        *devicesView;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *mainDevicePopUp;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *sampleRatePopUp;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *framesPopUp;
@property (nonatomic, weak)   IBOutlet NSButton      *hogModeButton;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *editingDevicePopUp;

@property (nonatomic, weak) Preferences *preferences;

@end
