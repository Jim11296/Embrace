// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import "PreferencesController.h"
#import "Preferences.h"
#import "Player.h"
#import "ScriptFile.h"
#import "ScriptsManager.h"
#import "HugAudioDevice.h"

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleAudioDevicesDidRefresh:)  name:HugAudioDevicesDidRefreshNotification  object:nil];
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
        
        [attributes setObject:[[NSColor textColor] colorWithAlphaComponent:0.5] forKey:NSForegroundColorAttributeName]; 
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
    NSPopUpButton  *popUpButton    = [self mainDevicePopUp];
    NSMenu         *menu           = [popUpButton menu];
    HugAudioDevice *deviceToSelect = [[Preferences sharedInstance] mainOutputAudioDevice];

    __block NSMenuItem *itemToSelect = nil;

    NSMenuItem *(^makeItem)(HugAudioDevice *) = ^(HugAudioDevice *device) {
        NSMenuItem *item = nil;

        NSString *title = [device name];
        if (!title) return item;

        BOOL valid = [device isConnected];
        item = [self _itemWithTitle:title representedObject:device valid:valid useIssueImage:YES];
                
        return item;
    };

    [menu removeAllItems];
    
    for (HugAudioDevice *device in [HugAudioDevice allDevices]) {
        NSMenuItem *item = makeItem(device);

        if (item) {
            [menu addItem:item];
        }

        if ([deviceToSelect isEqual:device]) {
            itemToSelect = item;
        }
    }
    
    if (!itemToSelect) {
        itemToSelect = makeItem(deviceToSelect);

        if (itemToSelect) {
            [menu insertItem:itemToSelect atIndex:0];
        }
    }

    [popUpButton selectItem:itemToSelect];
}


- (void) _rebuildSampleRateMenu
{
    NSNumber *selectedRate = @([[Preferences sharedInstance] mainOutputSampleRate]);

    __block NSMenuItem *itemToSelect = nil;

    auto makeMenu = ^NSMenuItem *(NSNumber *rate, BOOL isNA) {
        NSString *title = isNA ? @"N/A" : [NSString stringWithFormat:@"%@ Hz", rate];
        
        NSMenuItem *item = [self _itemWithTitle:title representedObject:rate valid:YES useIssueImage:NO];

        if (fabs([rate doubleValue] - [selectedRate doubleValue]) < 1) {
            itemToSelect = item;
        }
        
        return item;
    };

    NSPopUpButton *popUpButton = [self sampleRatePopUp];
    NSMenu *menu = [popUpButton menu];

    HugAudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];

    NSArray *availableSampleRates = [device availableSampleRates];
    
    if (![availableSampleRates count]) {
        availableSampleRates = @[ selectedRate ];
    }
    
    [menu removeAllItems];
    
    for (NSNumber *number in availableSampleRates) {
        [menu addItem:makeMenu(number, NO)];
    }

    if (itemToSelect) {
        [popUpButton selectItem:itemToSelect];

    } else {
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        [menu insertItem:makeMenu(selectedRate, YES) atIndex:0];
        [popUpButton selectItemAtIndex:0];
    }
}


- (void) _rebuildFrameMenu
{
    NSNumber *selectedFrameSize = @([[Preferences sharedInstance] mainOutputFrames]);

    __block NSMenuItem *itemToSelect = nil;

    auto makeMenu = ^NSMenuItem *(NSNumber *frameSize, BOOL isNA) {
        NSString *title = isNA ? @"N/A" : [frameSize stringValue];
        
        NSMenuItem *item = [self _itemWithTitle:title representedObject:frameSize valid:YES useIssueImage:NO];

        if ([frameSize integerValue] == [selectedFrameSize integerValue]) {
            itemToSelect = item;
        }
        
        return item;
    };

    NSPopUpButton *popUpButton = [self framesPopUp];
    NSMenu *menu = [popUpButton menu];

    HugAudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];

    NSArray *availableFrameSizes = [device availableFrameSizes];
    
    if (![availableFrameSizes count]) {
        availableFrameSizes = @[ selectedFrameSize ];
    }
    
    [menu removeAllItems];
    
    for (NSNumber *number in availableFrameSizes) {
        [menu addItem:makeMenu(number, NO)];
    }

    if (itemToSelect) {
        [popUpButton selectItem:itemToSelect];

    } else {
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        [menu insertItem:makeMenu(selectedFrameSize, YES) atIndex:0];
        [popUpButton selectItemAtIndex:0];
    }
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

    HugAudioDevice *device = [preferences mainOutputAudioDevice];
    [self _rebuildFrameMenu];
    [self _rebuildSampleRateMenu];

    [[self usesMasteringComplexityButton] setState:[preferences usesMasteringComplexitySRC]];
    
    BOOL resetVolumeEnabled = [device hasVolumeControl] &&
                              [device isHogModeSettable] &&
                              [preferences mainOutputUsesHogMode];

    [self setResetVolumeEnabled:resetVolumeEnabled];

    if ([device isHogModeSettable]) {
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

    HugAudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
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
    HugAudioDevice *device = [[sender selectedItem] representedObject];
    [[Preferences sharedInstance] setMainOutputAudioDevice:device];
}


- (IBAction) changeMainDeviceAttributes:(id)sender
{
    if (sender == [self framesPopUp]) {
        NSNumber *number = [[sender selectedItem] representedObject];
        
        UInt32 frames = [number unsignedIntValue];
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
    
    newFrame.origin    =  windowFrame.origin;
    newFrame.origin.y += (windowFrame.size.height - newFrame.size.height);

    [pane setFrameOrigin:NSZeroPoint];

    [window setFrame:newFrame display:YES animate:animated];

    [contentView addSubview:pane];
}


@end
