//
//  EffectSettingsController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "EditSystemEffectController.h"
#import "Effect.h"
#import "EffectAdditions.h"
#import "EffectType.h"
#import "BorderedView.h"


#import <AudioUnit/AUCocoaUIView.h>

@interface EditSystemEffectController ()

- (IBAction) switchView:(id)sender;


@property (nonatomic, weak) IBOutlet NSToolbar *toolbar;

@property (nonatomic, weak) IBOutlet NSScrollView *scrollView;
@property (nonatomic, weak) IBOutlet NSView *containerView;

@property (nonatomic, weak) IBOutlet NSToolbarItem *modeToolbarItem;
@property (nonatomic, weak) IBOutlet NSSegmentedControl *modeControl;

@end


@interface NSView (Radar21789723Workaround)
- (NSPoint) embrace_radar_21789723_convertPointToBase:(NSPoint)aPoint;
@end


@implementation NSView (Radar21789723Workaround)

- (NSPoint) embrace_radar_21789723_convertPointToBase:(NSPoint)aPoint
{
    return [self convertPoint:aPoint toView:nil];
}

@end


@implementation EditSystemEffectController {
    NSInteger _index;
    NSView   *_settingsView;
    BOOL      _useGenericView;
    
    BorderedView *_backgroundView;
}

- (void) windowDidLoad
{
    [super windowDidLoad];

    if (![[self effect] hasCustomView]) {
       [[self modeToolbarItem] setEnabled:NO];
    }

    [self _updateViewForce:YES useGenericView:NO];
}


- (NSString *) windowNibName
{
    return @"EditSystemEffectWindow";
}


#pragma mark - Private Methods

- (void) _performWorkaroundsIfNeeded
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // AUCompressionExpansionView
        static UInt8 a[] = { 193,213,195,239,237,240,242,229,243,243,233,239,238,197,248,240,225,238,243,233,239,238,214,233,229,247,0 };

        // AppleEQGraphView
        static UInt8 b[] = { 193,240,240,236,229,197,209,199,242,225,240,232,214,233,229,247,0 };

        // AUCompressionView
        static UInt8 c[] = { 193,213,195,239,237,240,242,229,243,243,233,239,238,214,233,229,247,0 };

        EmbraceSizzle(EmbraceGetPrivateName(a), @"embrace_radar_21789723_convertPointToBase:", @"convertPointToBase:");
        EmbraceSizzle(EmbraceGetPrivateName(b), @"embrace_radar_21789723_convertPointToBase:", @"convertPointToBase:");
        EmbraceSizzle(EmbraceGetPrivateName(c), @"embrace_radar_21789723_convertPointToBase:", @"convertPointToBase:");
    });
}

- (void) _tweakView:(NSView *)view window:(NSWindow *)window
{
    if ([view isKindOfClass:NSClassFromString(@"AppleAUCustomViewBase")]) {
        for (NSView *subview in [view subviews]) {
            if ([subview isKindOfClass:[NSTextField class]]) {
                if ([[(NSTextField *)subview font] pointSize] >= 16) {
                    [subview setHidden:YES];
                }
            }
        }
    }
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
        [self _performWorkaroundsIfNeeded];
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
        Effect *effect = [self effect];
        NSRect frame = [[self containerView] bounds];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [_settingsView removeFromSuperview];
        _settingsView = nil;

        NSView *view = nil;
        if (effect) {
            BOOL tryToTweakView = NO;

            if (!view && !useGenericView) {
                view = [self _customViewWithEffect:effect size:frame.size];
                tryToTweakView = YES;
            }
            
            if (!view) {
                useGenericView = YES;
                view = [[AUGenericView alloc] initWithAudioUnit:[effect audioUnit] displayFlags:(AUViewPropertiesDisplayFlag|AUViewParametersDisplayFlag)];
            }

            NSDisableScreenUpdates();

            [view setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];

            NSRect actualFrame = [view bounds];
            if (!NSEqualSizes(actualFrame.size, frame.size)) {
                [self _resizeWindowWithOldSize:frame.size newSize:actualFrame.size];
            }

            [[self window] setContentMinSize:[[[self window] contentView] frame].size];

            if (tryToTweakView) {
                [self _tweakView:view window:[self window]];
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


@end
