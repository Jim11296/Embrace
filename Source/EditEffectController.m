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

@implementation EditEffectController {
    NSView   *_settingsView;
    Effect   *_settingsViewEffect;
    BOOL      _useGenericView;
}



- (id) initWithEffect:(Effect *)effect
{
    if ((self = [super init])) {
        _effect = effect;
    }
    
    return self;
}


- (NSString *) windowNibName
{
    return @"EditEffectWindow";
}


- (void) windowDidLoad
{
    [[self window] setTitle:[[_effect type] name]];
    
    if (![_effect hasCustomView]) {
       [[self modeToolbarItem] setEnabled:NO];
    }
    
    [self _updateViewForce:YES useGenericView:NO];
}


#pragma mark - Private Methods

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

    if (unitExists && unitIsDirectory) {
        [openPanel setDirectoryURL:[NSURL fileURLWithPath:unitPresets]];
    } else if (allExists && allIsDirectory) {
        [openPanel setDirectoryURL:[NSURL fileURLWithPath:allPresets]];
    }

    __weak id weakEffect = _effect;

    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            [weakEffect loadAudioPresetAtFileURL:[openPanel URL]];
        }
    }];
}


- (IBAction) restoreDefaultValues:(id)sender
{
    [_effect loadDefaultValues];
}


@end
