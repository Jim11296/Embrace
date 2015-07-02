//
//  EffectSettingsController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "EditEffectController.h"
#import "Effect.h"
#import "EffectType.h"

#import <AudioUnit/AUCocoaUIView.h>

@interface EditEffectController ()

- (IBAction) switchView:(id)sender;

- (IBAction) loadPreset:(id)sender;
- (IBAction) savePreset:(id)sender;
- (IBAction) restoreDefaultValues:(id)sender;
- (IBAction) toggleBypass:(id)sender;

@property (nonatomic, weak) IBOutlet NSView *containerView;
@property (nonatomic, weak) IBOutlet NSToolbarItem *modeToolbarItem;
@property (nonatomic, weak) IBOutlet NSSegmentedControl *modeControl;

@end


@implementation EditEffectController {
    NSInteger _index;
    NSView   *_settingsView;
    Effect   *_settingsViewEffect;
    BOOL      _useGenericView;
}


- (id) initWithEffect:(Effect *)effect index:(NSInteger)index
{
    if ((self = [super init])) {
        _effect = effect;
        _index = index;
    }
    
    return self;
}


- (void) dealloc
{
    [[self effect] removeObserver:self forKeyPath:@"bypass"];
}


- (NSString *) windowNibName
{
    return @"EditEffectWindow";
}


- (void) windowDidLoad
{
    NSString *autosaveName = [NSString stringWithFormat:@"%@-%ld", [[_effect type] fullName], (long)_index];
    [[self window] setFrameAutosaveName:autosaveName];
    [[self window] setFrameUsingName:autosaveName];
    
    if (![_effect hasCustomView]) {
       [[self modeToolbarItem] setEnabled:NO];
    }
    
    [self _updateViewForce:YES useGenericView:NO];
    [self _updateTitle];

    [[self effect] addObserver:self forKeyPath:@"bypass" options:0 context:NULL];
}


- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(toggleBypass:)) {
        [menuItem setState:[[self effect] bypass] ? NSOnState : NSOffState];
    }

    return YES;
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == [self effect]) {
        if ([keyPath isEqualToString:@"bypass"]) {
            [self _updateTitle];
        }
    }
}


#pragma mark - Private Methods

- (void) _updateTitle
{
    NSString *name = [[_effect type] friendlyName];
    if (!name) name = NSLocalizedString(@"Effect", nil);

    if ([[self effect] bypass]) {
        NSString *bypassString = NSLocalizedString(@"(Bypassed)", nil);
        name = [NSString stringWithFormat:@"%@ %@", name, bypassString];
    }

    [[self window] setTitle:name];
}


- (NSView *) _customViewWithEffect:(Effect *)effect size:(NSSize)size;
{
    AudioUnit unit = [effect audioUnit];

    UInt32  dataSize   = 0;
    Boolean isWritable = 0;

    OSStatus err = AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_CocoaUI, kAudioUnitScope_Global, 0, &dataSize, &isWritable);
    if (err != noErr) return nil;

    unsigned numberOfClasses = (dataSize - sizeof(CFURLRef)) / sizeof(CFStringRef);
    if (!numberOfClasses) return nil;

    AudioUnitCocoaViewInfo *viewInfo = (AudioUnitCocoaViewInfo *)malloc(dataSize);
    AudioUnitGetProperty(unit, kAudioUnitProperty_CocoaUI, kAudioUnitScope_Global, 0, viewInfo, &dataSize);
    
    NSString *viewClassName = (__bridge NSString *)(viewInfo->mCocoaAUViewClass[0]);
    NSString *bundlePath = CFBridgingRelease(CFURLCopyPath(viewInfo->mCocoaAUViewBundleLocation));

    Class viewClass = [[NSBundle bundleWithPath:bundlePath] classNamed:viewClassName];

    NSView *result = nil;
    
    if ([viewClass conformsToProtocol: @protocol(AUCocoaUIBase)]) {
        id<AUCocoaUIBase> factory = [[viewClass alloc] init];
        result = [factory uiViewForAudioUnit:unit withSize:size];
    }
    
    if (viewInfo) {
        for (NSInteger i = 0; i < numberOfClasses; i++) {
            CFRelease(viewInfo->mCocoaAUViewClass[i]);
        }

        CFRelease(viewInfo->mCocoaAUViewBundleLocation);
        free(viewInfo);
    }
    
    return result;
}


- (void) _resizeWindowWithOldSize:(NSSize)oldSize newSize:(NSSize)newSize
{
    CGFloat deltaW = newSize.width  - oldSize.width;
    CGFloat deltaH = newSize.height - oldSize.height;

    NSRect windowFrame = [[self window] frame];
    windowFrame.size.width  += deltaW;
    windowFrame.size.height += deltaH;
    windowFrame.origin.y -= deltaH;

    [_settingsView setAutoresizingMask:0];
    [[self window] setFrame:windowFrame display:NO animate:NO];
    [_settingsView setFrame:[[self containerView] bounds]];
    [_settingsView setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];
}


- (void) _updateViewForce:(BOOL)force useGenericView:(BOOL)useGenericView
{
    if (force || (useGenericView != _useGenericView)) {
        NSRect frame = [[self containerView] bounds];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [_settingsView removeFromSuperview];
        _settingsView = nil;

        NSView *view = nil;
        if (_effect) {
            if (!useGenericView) {
                view = [self _customViewWithEffect:_effect size:frame.size];
            }
            
            if (!view) {
                useGenericView = YES;
                view = [[AUGenericView alloc] initWithAudioUnit:[_effect audioUnit]];
            }

            NSDisableScreenUpdates();

            [view setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];

            NSRect actualFrame = [view bounds];
            if (!NSEqualSizes(actualFrame.size, frame.size)) {
                [self _resizeWindowWithOldSize:frame.size newSize:actualFrame.size];
            }

            [[self containerView] addSubview:view];
            [[self window] displayIfNeeded];
            
            NSEnableScreenUpdates();
        }

        _settingsView = view;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleViewFrameDidChange:) name:NSViewFrameDidChangeNotification object:_settingsView];

        _useGenericView = useGenericView;
        [[self modeControl] setSelectedSegment:(_useGenericView ? 1 : 0)];
    }
}


- (NSURL *) _urlForPresetDirectory
{
    NSString *allPresets = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    allPresets = [allPresets stringByAppendingPathComponent:@"Audio"];
    allPresets = [allPresets stringByAppendingPathComponent:@"Presets"];

    NSString *manufacturer = [[_effect type] manufacturer];
    NSString *name = [[_effect type] name];

    NSString *unitPresets = nil;
    
    if (name && manufacturer) {
        unitPresets = [allPresets stringByAppendingPathComponent:manufacturer];
        unitPresets = [unitPresets stringByAppendingPathComponent:name];
    }

    BOOL allExists = NO,      unitExists = NO;
    BOOL allIsDirectory = NO, unitIsDirectory = NO;
    
    allExists  = [[NSFileManager defaultManager] fileExistsAtPath:allPresets  isDirectory:&allIsDirectory];
    unitExists = [[NSFileManager defaultManager] fileExistsAtPath:unitPresets isDirectory:&unitIsDirectory];

    NSURL *result = nil;

    if (unitExists && unitIsDirectory) {
        result = [NSURL fileURLWithPath:unitPresets];
    } else if (allExists && allIsDirectory) {
        result = [NSURL fileURLWithPath:allPresets];
    }

    return result;
}


- (void) _handleViewFrameDidChange:(NSNotification *)note
{
    if (![[self window] inLiveResize]) {
        NSRect containerBounds   = [[self containerView] bounds];
        NSRect settingsViewFrame = [_settingsView frame];

        NSDisableScreenUpdates();

        [self _resizeWindowWithOldSize:containerBounds.size newSize:settingsViewFrame.size];
        [[self window] displayIfNeeded];

        NSEnableScreenUpdates();
    }
}


#pragma mark - IBActions

- (IBAction) switchView:(id)sender
{
    NSInteger index = [sender indexOfSelectedItem];
    
    if (index > 0) {
        [self _updateViewForce:NO useGenericView:YES];
    } else {
        [self _updateViewForce:NO useGenericView:NO];
    }
}


- (IBAction) loadPreset:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    [openPanel setTitle:NSLocalizedString(@"Load Preset", nil)];
    
    NSURL *url = [self _urlForPresetDirectory];
    [openPanel setDirectoryURL:url];

    __weak id weakEffect = _effect;

    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [weakEffect loadAudioPresetAtFileURL:[openPanel URL]];
        }
    }];
}


- (IBAction) savePreset:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];

    [savePanel setTitle:NSLocalizedString(@"Save Preset", nil)];

    NSURL *url = [self _urlForPresetDirectory];
    [savePanel setDirectoryURL:url];
    [savePanel setAllowedFileTypes:@[ @"aupreset" ]];
    [savePanel setNameFieldStringValue:NSLocalizedString(@"Preset", nil)];

    __weak id weakEffect = _effect;

    [savePanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [weakEffect saveAudioPresetAtFileURL:[savePanel URL]];
        }
    }];
}


- (IBAction) restoreDefaultValues:(id)sender
{
    [[self effect] restoreDefaultValues];
}


- (IBAction) toggleBypass:(id)sender
{
    BOOL bypass = [[self effect] bypass];
    [[self effect] setBypass:!bypass];
}


@end
