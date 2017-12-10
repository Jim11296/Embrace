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

@interface PreferencesController ()

- (IBAction) changeMainDevice:(id)sender;
- (IBAction) changeMainDeviceAttributes:(id)sender;

@property (nonatomic, weak)   IBOutlet NSPopUpButton *mainDevicePopUp;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *sampleRatePopUp;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *framesPopUp;
@property (nonatomic, weak)   IBOutlet NSButton      *hogModeButton;

@property (nonatomic, weak)   IBOutlet NSButton      *resetVolumeButton;
@property (nonatomic, weak)   IBOutlet NSButton      *usesMasteringComplexityButton;

@end


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

    [[self usesMasteringComplexityButton] setState:[preferences usesMasteringComplexitySRC]];
    
    BOOL resetVolumeEnabled = [device hasVolumeControl] &&
                              [device isHoggable] &&
                              [preferences mainOutputUsesHogMode];

    [self setResetVolumeEnabled:resetVolumeEnabled];

    if ([device isHoggable]) {
        [self setDeviceHoggable:YES];
        
        BOOL mainOutputUsesHogMode = [preferences mainOutputUsesHogMode];
        [[self hogModeButton] setState:(mainOutputUsesHogMode ? NSOnState : NSOffState)];

        BOOL mainOutputResetsVolume = mainOutputUsesHogMode && [preferences mainOutputResetsVolume] && [device hasVolumeControl];
        [[self resetVolumeButton] setState:(mainOutputResetsVolume ? NSOnState : NSOffState)];

    } else {
        [self setDeviceHoggable:NO];
        [[self hogModeButton] setState:NSOffState];
        [[self resetVolumeButton] setState:NSOffState];
    }
 
    [self _rebuildDevicesMenu];

    [self setDeviceConnected:[device isConnected]];
}


- (void) _handleAudioDevicesDidRefresh:(NSNotification *)note
{
    [self _rebuildDevicesMenu];

    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    [self setDeviceConnected:[device isConnected]];
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

    } else if (sender == [self resetVolumeButton]) {
        BOOL resetsVolume = [[self resetVolumeButton] state] == NSOnState;
        [[Preferences sharedInstance] setMainOutputResetsVolume:resetsVolume];

    } else if (sender == [self usesMasteringComplexityButton]) {
        BOOL usesMasteringComplexitySRC = [[self usesMasteringComplexityButton] state] == NSOnState;
        [[Preferences sharedInstance] setUsesMasteringComplexitySRC:usesMasteringComplexitySRC];
    }
}


- (NSMenuItem *) _itemWithTitle:(NSString *)title representedObject:(id)representedObject valid:(BOOL)valid useIssueImage:(BOOL)useIssueImage
{
    NSMenuItem *item = [[NSMenuItem alloc] init];

    [item setTitle:title];
    [item setRepresentedObject:representedObject];
    
    if (!valid) {
        NSFont *font = [[self mainDevicePopUp] font];

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

        NSMutableParagraphStyle *ps = nil;
        if (!useIssueImage) {
            [[NSParagraphStyle defaultParagraphStyle] mutableCopy]; 
            [ps setMinimumLineHeight:18];
            [ps setMaximumLineHeight:18];
        }
        
        [attributes setObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName]; 
        if (font) [attributes setObject:font forKey:NSFontAttributeName];
        if (ps)   [attributes setObject:ps   forKey:NSParagraphStyleAttributeName];

        NSAttributedString *as = [[NSAttributedString alloc] initWithString:title attributes:attributes];

        [item setAttributedTitle:as];

        if (useIssueImage) {
            [item setImage:[NSImage imageNamed:@"IssueSmall"]];
        }

    } else {
        [item setImage:nil];
    }

    return item;
}


- (void) _rebuildDevicesMenu
{
    void (^rebuild)(NSPopUpButton *, AudioDevice *) = ^(NSPopUpButton *popUpButton, AudioDevice *deviceToSelect) {
        NSMenu *menu = [popUpButton menu];

        [menu removeAllItems];
        
        NSMenuItem *itemToSelect = nil;

        for (AudioDevice *device in [AudioDevice outputAudioDevices]) {
            NSString *title = [device name];
            if (!title) continue;

            BOOL valid = [device isConnected];
            NSMenuItem *item = [self _itemWithTitle:title representedObject:device valid:valid useIssueImage:YES];
            
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
    NSNumber *sampleRate = @([[Preferences sharedInstance] mainOutputSampleRate]);

    NSArray *deviceSampleRates = [device sampleRates];
    
    [menu removeAllItems];

    NSMenuItem *itemToSelect = nil;

    NSMutableArray *sampleRates = [deviceSampleRates mutableCopy];
    
    if (![sampleRates containsObject:sampleRate]) {
        [sampleRates insertObject:sampleRate atIndex:0];
        [sampleRates sortUsingSelector:@selector(compare:)];
    }

    for (NSNumber *number in sampleRates) {
        NSString *title = [NSString stringWithFormat:@"%@ Hz", number];
        
        BOOL valid = [deviceSampleRates containsObject:number];

        NSMenuItem *item = [self _itemWithTitle:title representedObject:number valid:valid useIssueImage:NO];

        if (fabs([number doubleValue] - [sampleRate doubleValue]) < 1) {
            itemToSelect = item;
        }
        
        [menu addItem:item];
        if (!valid) [menu addItem:[NSMenuItem separatorItem]];
    }

    [[self sampleRatePopUp] selectItem:itemToSelect];
}


- (void) _rebuildFrameMenu
{
    NSMenu *menu = [[self framesPopUp] menu];
    
    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    NSNumber *frameSize = @([[Preferences sharedInstance] mainOutputFrames]);

    NSArray *deviceFrameSizes = [device frameSizes];

    [menu removeAllItems];
    
    NSMenuItem *itemToSelect = nil;

    NSMutableArray *frameSizes = [deviceFrameSizes mutableCopy];
    
    if (![deviceFrameSizes containsObject:frameSize]) {
        [frameSizes addObject:frameSize];
        [frameSizes sortUsingSelector:@selector(compare:)];
    }

    for (NSNumber *number in frameSizes) {
        NSString *title = [number stringValue];

        BOOL valid = [deviceFrameSizes containsObject:number];

        NSMenuItem *item = [self _itemWithTitle:title representedObject:number valid:valid useIssueImage:NO];

        if ([number unsignedIntegerValue] == [frameSize unsignedIntegerValue]) {
            itemToSelect = item;
        }
        
        [menu addItem:item];
        if (!valid) [menu addItem:[NSMenuItem separatorItem]];
    }
    
    [[self framesPopUp] selectItem:itemToSelect];
}


@end
