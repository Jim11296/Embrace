//
//  PreferencesController.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-12.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "PreferencesController.h"
#import "Preferences.h"
#import "AudioDevice.h"


@implementation PreferencesController

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *) windowNibName
{
    return @"PreferencesWindow";
}

- (void) windowDidLoad
{
    [self _handlePreferencesDidChange:nil];
    [self selectPane:0 animated:NO];
    
    [self setPreferences:[Preferences sharedInstance]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    Preferences *preferences = [Preferences sharedInstance];

    AudioDevice *device = [preferences mainOutputAudioDevice];
    [self _rebuildFrameMenu];
    [self _rebuildSampleRateMenu];
    
    if ([device isHogModeSettable]) {
        [[self hogModeButton] setEnabled:YES];
        [[self hogModeButton] setState:[preferences mainOutputUsesHogMode]];
    } else {
        [[self hogModeButton] setEnabled:NO];
        [[self hogModeButton] setState:NSOffState];
    }
 
    [self _rebuildDevicesMenu];
    [self _rebuildPreferredLocationMenu];
}



- (IBAction) changeMainDevice:(id)sender
{
    AudioDevice *device = [[sender selectedItem] representedObject];
    [[Preferences sharedInstance] setMainOutputAudioDevice:device];
}


- (IBAction) changeMainDeviceAttributes:(id)sender
{
    if (sender == [self framesPopUp]) {
        NSNumber *number = [[sender selectedItem] representedObject];
        
        UInt32 frames =[number unsignedIntValue];
        [[Preferences sharedInstance] setMainOutputFrames:frames];
        
    } else if (sender == [self sampleRatePopUp]) {
        NSNumber *number = [[sender selectedItem] representedObject];

        double sampleRate =[number doubleValue];
        [[Preferences sharedInstance] setMainOutputSampleRate:sampleRate];
        
    } else if (sender == [self hogModeButton]) {
        BOOL hogMode = [[self hogModeButton] state] == NSOnState;
        [[Preferences sharedInstance] setMainOutputUsesHogMode:hogMode];
    }
}

- (IBAction) changeEditingDevice:(id)sender
{
    AudioDevice *device = [[sender selectedItem] representedObject];
    [[Preferences sharedInstance] setEditingAudioDevice:device];
}


- (IBAction) changePreferredLibrary:(id)sender
{
    NSInteger selectedTag = [[sender selectedItem] tag];
    
    // "Choose..." item
    if (selectedTag == 2) {
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setCanChooseFiles:NO];
        [openPanel setCanChooseDirectories:YES];
        
        [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelCancelButton) {
                return;
            }

            NSURL *url = [openPanel URL];
            
            NSError *error = nil;
            NSData  *bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];

            NSString *name = [url lastPathComponent];
            if (!bookmark) name = @"";
        
            [[Preferences sharedInstance] setPreferredLibraryName:name];
            [[Preferences sharedInstance] setPreferredLibraryData:bookmark];
        }];
    
    // "None" item
    } else if (selectedTag == 0) {
        [[Preferences sharedInstance] setPreferredLibraryName:@""];
        [[Preferences sharedInstance] setPreferredLibraryData:[NSData data]];
    }
}


- (void) _rebuildPreferredLocationMenu
{
    Preferences *preferences = [Preferences sharedInstance];

    NSData   *data = [preferences preferredLibraryData];
    NSString *name = [preferences preferredLibraryName];

    if ([name length] && [data length]) {
        [[self preferredLibraryLocationItem] setTitle:[preferences preferredLibraryName]];
        [[self preferredLibraryLocationItem] setImage:[NSImage imageNamed:NSImageNameFolder]];

        [[self preferredLibraryLocationItem]  setHidden:NO];
        [[self preferredLibrarySeparatorItem] setHidden:NO];
        
        [[self preferredLibraryPopUp] selectItem:[self preferredLibraryLocationItem]];
        
    } else {
        [[self preferredLibraryLocationItem]  setHidden:YES];
        [[self preferredLibrarySeparatorItem] setHidden:YES];

        [[self preferredLibraryPopUp] selectItemWithTag:0];
    }
}


- (void) _rebuildDevicesMenu
{
    void (^rebuild)(NSPopUpButton *, AudioDevice *) = ^(NSPopUpButton *popUpButton, AudioDevice *deviceToSelect) {
        NSMenu *menu = [popUpButton menu];

        [menu removeAllItems];
        
        NSMenuItem *itemToSelect = nil;

        for (AudioDevice *device in [AudioDevice outputAudioDevices]) {
            NSMenuItem *item = [[NSMenuItem alloc] init];

            [item setTitle:[device name]];
            [item setRepresentedObject:device];
            
            if ([device isEqual:deviceToSelect]) {
                itemToSelect = item;
            }
            
            [menu addItem:item];
        }

        [popUpButton selectItem:itemToSelect];
    };

    
    AudioDevice *mainOutputAudioDevice = [[Preferences sharedInstance] mainOutputAudioDevice];
    AudioDevice *editingAudioDevice    = [[Preferences sharedInstance] editingAudioDevice];

    rebuild([self mainDevicePopUp], mainOutputAudioDevice);
    rebuild([self editingDevicePopUp], editingAudioDevice);
}


- (void) _rebuildSampleRateMenu
{
    NSMenu *menu = [[self sampleRatePopUp] menu];

    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    double sampleRate = [[Preferences sharedInstance] mainOutputSampleRate];

    [menu removeAllItems];

    NSMenuItem *itemToSelect = nil;

    for (NSNumber *number in [device availableNominalSampleRates]) {
        NSMenuItem *item = [[NSMenuItem alloc] init];

        [item setTitle:[NSString stringWithFormat:@"%@ Hz", number]];
        [item setRepresentedObject:number];
        
        if (fabs([number doubleValue] - sampleRate) < 1) {
            itemToSelect = item;
        }
        
        [menu addItem:item];
    }

    [[self sampleRatePopUp] selectItem:itemToSelect];
}


- (void) _rebuildFrameMenu
{
    NSMenu *menu = [[self framesPopUp] menu];
    
    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    UInt32 selectedFrames = [[Preferences sharedInstance] mainOutputFrames];
    
    [menu removeAllItems];
    
    NSMenuItem *itemToSelect = nil;

    for (NSNumber *number in [device availableIOBufferSizes]) {
        NSMenuItem *item = [[NSMenuItem alloc] init];

        [item setTitle:[number stringValue]];
        [item setRepresentedObject:number];
        
        if ([number unsignedIntegerValue] == selectedFrames) {
            itemToSelect = item;
        }
        
        [menu addItem:item];
    }
    
    [[self framesPopUp] selectItem:itemToSelect];
}


- (void) selectPane:(NSInteger)tag animated:(BOOL)animated
{
    NSToolbarItem *item;
    NSView *pane;
    NSString *title;

    if (tag == 1) {
        item = _devicesItem;
        pane = _devicesPane;
        title = NSLocalizedString(@"Devices", nil);

    } else {
        item = _generalItem;
        pane = _generalPane;
        title = NSLocalizedString(@"General", nil);
    }
    
    [_toolbar setSelectedItemIdentifier:[item itemIdentifier]];
    
    NSWindow *window = [self window];
    NSView *contentView = [window contentView];
    for (NSView *view in [contentView subviews]) {
        [view removeFromSuperview];
    }

    NSRect paneFrame = [pane frame];
    NSRect windowFrame = [window frame];
    NSRect newFrame = [window frameRectForContentRect:paneFrame];
    
    newFrame.origin = windowFrame.origin;
    newFrame.origin.y += (windowFrame.size.height - newFrame.size.height);

    [window setFrame:newFrame display:YES animate:animated];
    [window setTitle:title];

    [contentView addSubview:pane];
}


- (IBAction) selectPane:(id)sender
{
    [self selectPane:[sender tag] animated:YES];
}




@end
