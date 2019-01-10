// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import "EditSystemEffectController.h"
#import "Effect.h"
#import "EffectAdditions.h"
#import "EffectType.h"
#import <objc/runtime.h>

#import <CoreAudioKit/CoreAudioKit.h>

@interface EditSystemEffectController ()

@property (nonatomic, weak) IBOutlet NSToolbar *toolbar;

@property (nonatomic, weak) IBOutlet NSToolbarItem *modeToolbarItem;
@property (nonatomic, weak) IBOutlet NSSegmentedControl *modeControl;

@end


@implementation EditSystemEffectController {
    NSView *_effectView;
    NSViewController *_effectViewController;
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

    __weak id weakSelf = self;

    [[effect audioUnit] requestViewControllerWithCompletionHandler:^(AUViewControllerBase *viewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf _didReceiveViewController:viewController];
        });
    }];
}


#pragma mark - Private Methods

- (void) _didReceiveViewController:(NSViewController *)vc
{
    NSWindow *window = [self window];

    NSRect contentLayoutRect = [window contentLayoutRect];
        
    NSViewController *contentViewController = [self contentViewController];
    
    [contentViewController addChildViewController:vc];
    
    NSView *effectView = [vc view];
    _effectView = effectView;
    _effectViewController = vc;
    
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
