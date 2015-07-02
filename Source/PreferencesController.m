//
//  PreferencesController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-12.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "PreferencesController.h"
#import "Preferences.h"
#import "AudioDevice.h"
#import "Player.h"
#import "WrappedAudioDevice.h"

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
    
    [self setPreferences:[Preferences sharedInstance]];
    [self setPlayer:[Player sharedInstance]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:)   name:PreferencesDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleAudioDevicesDidRefresh:) name:AudioDevicesDidRefreshNotification object:nil];
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    Preferences *preferences = [Preferences sharedInstance];

    AudioDevice *device = [preferences mainOutputAudioDevice];
    [self _rebuildFrameMenu];
    [self _rebuildSampleRateMenu];
    
    if ([device isHoggable]) {
        [self setDeviceHoggable:YES];
        [[self hogModeButton] setState:[preferences mainOutputUsesHogMode]];
    } else {
        [self setDeviceHoggable:NO];
        [[self hogModeButton] setState:NSOffState];
    }
 
    [self _rebuildDevicesMenu];
}


- (void) _handleAudioDevicesDidRefresh:(NSNotification *)note
{
    [self _rebuildDevicesMenu];
}


- (IBAction) changeMainDevice:(id)sender
{
    AudioDevice *device = [[sender selectedItem] representedObject];
    [[Preferences sharedInstance] setMainOutputAudioDevice:device];

    [AudioDevice selectChosenAudioDevice:device];
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
            
            if (![device isConnected]) {
                NSAttributedString *as = [[NSAttributedString alloc] initWithString:[device name] attributes:@{
                    NSForegroundColorAttributeName: GetRGBColor(0x0, 0.5),
                    NSFontAttributeName: [NSFont systemFontOfSize:13]
                }];

                [item setAttributedTitle:as];
                [item setImage:[NSImage imageNamed:@"IssueSmall"]];


            } else {
                [item setImage:nil];
            }
            
            if ([device isEqual:deviceToSelect]) {
                itemToSelect = item;
            }
            
            [menu addItem:item];
        }

        [popUpButton selectItem:itemToSelect];
    };
    
    AudioDevice *mainOutputAudioDevice = [[Preferences sharedInstance] mainOutputAudioDevice];
    rebuild([self mainDevicePopUp], mainOutputAudioDevice);
}


- (void) _rebuildSampleRateMenu
{
    NSMenu *menu = [[self sampleRatePopUp] menu];

    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    double sampleRate = [[Preferences sharedInstance] mainOutputSampleRate];

    if (!sampleRate) {
        sampleRate = [[[[device controller] availableSampleRates] firstObject] doubleValue];
    }

    [menu removeAllItems];

    NSMenuItem *itemToSelect = nil;

    for (NSNumber *number in [device sampleRates]) {
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
    UInt32 selectedFrames  = [[Preferences sharedInstance] mainOutputFrames];
    UInt32 preferredFrames = [[device controller] preferredAvailableFrameSize];
    
    [menu removeAllItems];
    
    NSMenuItem *selectedItem  = nil;
    NSMenuItem *preferredItem = nil;

    for (NSNumber *number in [device frameSizes]) {
        NSMenuItem *item = [[NSMenuItem alloc] init];

        [item setTitle:[number stringValue]];
        [item setRepresentedObject:number];
        
        if ([number unsignedIntegerValue] == selectedFrames) {
            selectedItem = item;
        }
        if ([number unsignedIntegerValue] == preferredFrames) {
            preferredItem = item;
        }
        
        [menu addItem:item];
    }
    
    [[self framesPopUp] selectItem:selectedItem ? selectedItem : preferredItem];
}


@end
