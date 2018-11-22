// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "PreferencesController.h"
#import "Preferences.h"
#import "AudioDevice.h"
#import "Player.h"
#import "ScriptFile.h"
#import "ScriptsManager.h"
#import "WrappedAudioDevice.h"

@interface PreferencesController ()

- (IBAction) changeMainDevice:(id)sender;
- (IBAction) changeMainDeviceAttributes:(id)sender;

@property (nonatomic, strong) IBOutlet NSView *generalPane;
@property (nonatomic, strong) IBOutlet NSView *advancedPane;

@property (nonatomic, weak)   IBOutlet NSToolbar     *toolbar;
@property (nonatomic, weak)   IBOutlet NSToolbarItem *generalItem;
@property (nonatomic, weak)   IBOutlet NSToolbarItem *advancedItem;

@property (nonatomic, weak)   IBOutlet NSPopUpButton *mainDevicePopUp;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *sampleRatePopUp;
@property (nonatomic, weak)   IBOutlet NSPopUpButton *framesPopUp;
@property (nonatomic, weak)   IBOutlet NSButton      *hogModeButton;

@property (nonatomic, weak)   IBOutlet NSButton      *resetVolumeButton;
@property (nonatomic, weak)   IBOutlet NSButton      *usesMasteringComplexityButton;

@property (nonatomic, weak)   IBOutlet NSPopUpButton *scriptHandlerPopUp;

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:)    name:PreferencesDidChangeNotification    object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleAudioDevicesDidRefresh:)  name:AudioDevicesDidRefreshNotification  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleScriptsManagerDidReload:) name:ScriptsManagerDidReloadNotification object:nil];

    [self selectPane:0 animated:NO];
}


#pragma mark - Private Methods

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


- (void) _rebuildScriptHandlerMenu
{
    NSMenu *menu = [[self scriptHandlerPopUp] menu];

    NSArray    *allScriptFiles    = [[ScriptsManager sharedInstance] allScriptFiles];
    ScriptFile *handlerScriptFile = [[ScriptsManager sharedInstance] handlerScriptFile];

    NSMenuItem *itemToSelect = nil;

    [menu removeAllItems];

    // Add "None"
    {
        NSMenuItem *noneItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"None", nil) action:nil keyEquivalent:@""];
        [noneItem setTag:0];

        itemToSelect = noneItem;
        [menu addItem:noneItem];
    }

    // Add separator and one entry per script
    if ([allScriptFiles count]) {
        [menu addItem:[NSMenuItem separatorItem]];

        for (ScriptFile *scriptFile in allScriptFiles) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[scriptFile displayName] action:nil keyEquivalent:@""];
            [item setTag:1];
            [item setRepresentedObject:[scriptFile fileName]];
            
            if ([handlerScriptFile isEqual:scriptFile]) {
                itemToSelect = item;
            }

            [menu addItem:item];
        }
    }

    // Add separator and "Reveal Scripts in Finder"
    {
        [menu addItem:[NSMenuItem separatorItem]];

        NSMenuItem *revealItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reveal Scripts in Finder", nil) action:nil keyEquivalent:@""];
        [revealItem setTag:2];

        [menu addItem:revealItem];
    }
    
    if (itemToSelect) {
        [[self scriptHandlerPopUp] selectItem:itemToSelect];
    }
}


#pragma mark - Notifications Observers

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
        [[self hogModeButton] setState:(mainOutputUsesHogMode ? NSControlStateValueOn : NSControlStateValueOff)];

        BOOL mainOutputResetsVolume = mainOutputUsesHogMode && [preferences mainOutputResetsVolume] && [device hasVolumeControl];
        [[self resetVolumeButton] setState:(mainOutputResetsVolume ? NSControlStateValueOn : NSControlStateValueOff)];

    } else {
        [self setDeviceHoggable:NO];
        [[self hogModeButton] setState:NSControlStateValueOff];
        [[self resetVolumeButton] setState:NSControlStateValueOff];
    }
 
    [self _rebuildDevicesMenu];
    [self _rebuildScriptHandlerMenu];

    [self setDeviceConnected:[device isConnected]];
}


- (void) _handleAudioDevicesDidRefresh:(NSNotification *)note
{
    [self _rebuildDevicesMenu];

    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    [self setDeviceConnected:[device isConnected]];
}


- (void) _handleScriptsManagerDidReload:(NSNotification *)note
{
    [self _rebuildScriptHandlerMenu];
}


#pragma mark - IBActions

- (IBAction) selectPane:(id)sender
{
    [self selectPane:[sender tag] animated:YES];
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
        BOOL hogMode = [[self hogModeButton] state] == NSControlStateValueOn;
        [[Preferences sharedInstance] setMainOutputUsesHogMode:hogMode];

    } else if (sender == [self resetVolumeButton]) {
        BOOL resetsVolume = [[self resetVolumeButton] state] == NSControlStateValueOn;
        [[Preferences sharedInstance] setMainOutputResetsVolume:resetsVolume];

    } else if (sender == [self usesMasteringComplexityButton]) {
        BOOL usesMasteringComplexitySRC = [[self usesMasteringComplexityButton] state] == NSControlStateValueOn;
        [[Preferences sharedInstance] setUsesMasteringComplexitySRC:usesMasteringComplexitySRC];
    }
}


- (IBAction) handleScriptHandlerPopUp:(id)sender
{
    NSMenuItem *selectedItem = [[self scriptHandlerPopUp] selectedItem];

    if ([selectedItem tag] == 0) {
        [[Preferences sharedInstance] setScriptHandlerName:@""];
   
    } else if ([selectedItem tag] == 1) {
        [[Preferences sharedInstance] setScriptHandlerName:[selectedItem representedObject]];
    
    } else if ([selectedItem tag] == 2) {
        [[ScriptsManager sharedInstance] revealScriptsFolder];
        [self _rebuildScriptHandlerMenu];
    }
}


#pragma mark - Public Methods

- (void) selectPane:(NSInteger)tag animated:(BOOL)animated
{
    NSToolbarItem *item;
    NSView *pane;

    if (tag == 1) {
        item = _advancedItem;
        pane = _advancedPane;

    } else {
        item = _generalItem;
        pane = _generalPane;
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
    
    newFrame.origin    = windowFrame.origin;
    newFrame.origin.y += (windowFrame.size.height - newFrame.size.height);

    [pane setFrameOrigin:NSZeroPoint];

    [window setFrame:newFrame display:YES animate:animated];

    [contentView addSubview:pane];
}


@end
