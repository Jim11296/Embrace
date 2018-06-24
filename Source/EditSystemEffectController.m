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
#import <objc/runtime.h>


#import <AudioUnit/AUCocoaUIView.h>

@interface EditSystemEffectController ()

@property (nonatomic, weak) IBOutlet NSToolbar *toolbar;

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
    NSView *_effectView;
    BOOL _inViewFrameCallback;
}


- (NSString *) windowNibName
{
    return @"EditSystemEffectWindow";
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    Effect *effect = [self effect];
    if (!effect) return;

    NSWindow *window = [self window];

    NSRect contentLayoutRect = [window contentLayoutRect];
        
    _effectView = [self _customViewWithEffect:effect size:contentLayoutRect.size];

    if (!_effectView) {
        _effectView = [[AUGenericView alloc] initWithAudioUnit:[effect audioUnit] displayFlags:(AUViewPropertiesDisplayFlag|AUViewParametersDisplayFlag)];
    }

    NSRect effectViewFrame = [_effectView frame];

    NSRect newWindowFrame = [window frame];
    newWindowFrame.size.width  += (effectViewFrame.size.width  - contentLayoutRect.size.width);
    newWindowFrame.size.height += (effectViewFrame.size.height - contentLayoutRect.size.height);

    NSAutoresizingMaskOptions oldAutoresizingMask = [_effectView autoresizingMask];
    
    if ((oldAutoresizingMask & (NSViewWidthSizable|NSViewHeightSizable)) == 0) {
        NSWindowStyleMask styleMask = [[self window] styleMask];
        styleMask &= ~NSWindowStyleMaskResizable;
        [window setStyleMask:styleMask];
    }   
    
    [_effectView setAutoresizingMask:0];
    [window setFrame:newWindowFrame display:NO animate:NO];

    [_effectView setFrame:[[self window] contentLayoutRect]];
    [_effectView setAutoresizingMask:oldAutoresizingMask];

    [[[self window] contentView] addSubview:_effectView];

    [self _tweakView:_effectView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleViewFrameDidChange:) name:NSViewFrameDidChangeNotification object:_effectView];
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

        EmbraceSwizzle(EmbraceGetPrivateName(a), @"embrace_radar_21789723_convertPointToBase:", @"convertPointToBase:");
        EmbraceSwizzle(EmbraceGetPrivateName(b), @"embrace_radar_21789723_convertPointToBase:", @"convertPointToBase:");
        EmbraceSwizzle(EmbraceGetPrivateName(c), @"embrace_radar_21789723_convertPointToBase:", @"convertPointToBase:");
    });
}


- (void) _tweakView:(NSView *)view
{
    Class AppleAUCustomViewBase   = NSClassFromString(@"AppleAUCustomViewBase");
    Class CAAppleAUCustomViewBase = NSClassFromString(@"CAAppleAUCustomViewBase");

    if ((  AppleAUCustomViewBase && [view isKindOfClass:  AppleAUCustomViewBase]) ||
        (CAAppleAUCustomViewBase && [view isKindOfClass:CAAppleAUCustomViewBase]))
    {
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

    NSURL    *viewURL       = (__bridge NSURL    *)(viewInfo->mCocoaAUViewBundleLocation);
    NSString *viewClassName = (__bridge NSString *)(viewInfo->mCocoaAUViewClass[0]);

    Class viewClass = [[NSBundle bundleWithURL:viewURL] classNamed:viewClassName];

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

    [_effectView setAutoresizingMask:0];
    [[self window] setFrame:windowFrame display:NO animate:NO];
    [_effectView setFrame:[[[self window] contentView] bounds]];
    [_effectView setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];
}


- (void) _handleViewFrameDidChange:(NSNotification *)note
{
    if (!_inViewFrameCallback && ![[self window] inLiveResize]) {
        _inViewFrameCallback = YES;

        NSRect contentLayoutRect = [[self window] contentLayoutRect];
        NSRect effectViewFrame   = [_effectView frame];

        [self _resizeWindowWithOldSize:contentLayoutRect.size newSize:effectViewFrame.size];

        _inViewFrameCallback = NO;
    }
}

@end
