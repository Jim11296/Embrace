//
//  EmbraceWindow.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "EmbraceWindow.h"
#import "BorderedView.h"

@implementation EmbraceWindow {
    BorderedView   *_headerView;
    BorderedView   *_footerView;
    NSHashTable    *_mainListeners;
    NSVisualEffectView *_effectsView;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) cancelOperation:(id)sender
{
    if ([[self delegate] respondsToSelector:@selector(window:cancelOperation:)]) {
        BOOL result = [(id)[self delegate] window:self cancelOperation:sender];
        if (result) return;
    }

    [super cancelOperation:sender];
}


- (void) _updateActiveness:(NSNotification *)note
{
    BOOL isMainWindow = [self isMainWindow];
    
    if (IsLegacyOS()) {
        NSColor *backgroundColor;

        if (isMainWindow) {
            backgroundColor = [NSColor colorWithCalibratedWhite:(0xe8 / 255.0) alpha:1.0];

            [_headerView setBackgroundGradientTopColor:   GetRGBColor(0xf4f4f4, 1.0)];
            [_headerView setBackgroundGradientBottomColor:GetRGBColor(0xd0d0d0, 1.0)];

        } else {
            backgroundColor = [NSColor colorWithCalibratedWhite:(0xFF / 255.0) alpha:1.0];

            [_headerView setBackgroundGradientTopColor:   GetRGBColor(0xffffff, 1.0)];
            [_headerView setBackgroundGradientBottomColor:GetRGBColor(0xf8f8f8, 1.0)];
        }

        [self setBackgroundColor:backgroundColor];
    }

    if (isMainWindow) {
        [_footerView setBackgroundColor:GetRGBColor(0xe0e0e0, 1.0)];
    } else {
        [_footerView setBackgroundColor:GetRGBColor(0xf6f6f6, 1.0)];
    }


    for (id<MainWindowListener> listener in _mainListeners) {
        [listener windowDidUpdateMain:self];
    }
}


- (void) _handleCloseButton:(id)sender
{
    [self orderOut:sender];
}


- (void) orderOut:(id)sender
{
    [super orderOut:sender];
    
    for (NSWindow *childWindow in [self childWindows]) {
        [childWindow orderOut:sender];
    }
}


- (void) setupWithHeaderView: (BorderedView *) headerView
                    mainView: (NSView *) mainView
                  footerView: (BorderedView *) footerView
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateActiveness:) name:NSWindowDidBecomeMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateActiveness:) name:NSWindowDidResignMainNotification object:nil];

    [self setMovableByWindowBackground:YES];
    [self setTitle:@""];
    [self setHasShadow:YES];

    NSRect frame = [self frame];
    frame.origin = NSZeroPoint;
    
    NSView *contentView = [self contentView];

    NSSize windowSize = [self frame].size;
    NSSize contentSize = [contentView frame].size;
    NSSize headerSize  = [headerView frame].size;
    
    CGFloat titlebarHeight = windowSize.height - contentSize.height;
    CGFloat contentTopPadding = headerSize.height - titlebarHeight;

    [[self standardWindowButton:NSWindowZoomButton] setHidden:YES];
    [[self standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
    
    if (headerView) {
        NSRect headerFrame = [headerView frame];
        headerFrame.origin.x = 0;
        headerFrame.size.width = frame.size.width;

        [headerView setWantsLayer:YES];
        [contentView setWantsLayer:YES];

        if (!IsLegacyOS()) {
            [self setStyleMask:([self styleMask] | NSFullSizeContentViewWindowMask)];
            [self setTitlebarAppearsTransparent:YES];
            [self setTitleVisibility:NSWindowTitleHidden];
 
            NSRect parentBounds = [[self contentView] bounds];
            headerFrame.origin.y = NSMaxY(parentBounds) - headerFrame.size.height;

            [headerView setFrame:headerFrame];
            [[self contentView] addSubview:headerView];

        } else {
            headerFrame.origin.y = contentSize.height - contentTopPadding;

            NSView *frameView = [contentView superview];
            [frameView addSubview:headerView];
            [headerView setFrame:headerFrame];
        }

        _headerView = headerView;
    }

    if (IsLegacyOS() && mainView) {
        NSView *closeButton = [self standardWindowButton:NSWindowCloseButton];
        [[_headerView superview] addSubview:closeButton positioned:NSWindowAbove relativeTo:mainView];
    }

    if (mainView) {
        NSRect headerRect = [headerView convertRect:[headerView bounds] toView:contentView];
        
        NSRect mainViewFrame = [[self contentView] bounds];
        mainViewFrame.size.height = NSMinY(headerRect);
        [mainView setFrame:mainViewFrame];
        
        [[self contentView] addSubview:mainView];
    }
    
    _footerView = footerView;
    
    [self _updateActiveness:nil];
}


- (void) setupAsParentWindow
{
    [self setupWithHeaderView:nil mainView:nil footerView:nil];

    if (!IsLegacyOS()) {
        [self setTitlebarAppearsTransparent:YES];
        [self setTitleVisibility:NSWindowTitleHidden];

        [self setStyleMask:([self styleMask] | NSFullSizeContentViewWindowMask)];
        

        _effectsView = [[NSVisualEffectView alloc] initWithFrame:[[self contentView] bounds]];
        [_effectsView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [_effectsView setState:NSVisualEffectStateActive];

        [[self contentView] addSubview:_effectsView];
        
    }
}


- (void) setFrame:(NSRect)frameRect display:(BOOL)flag
{
    [super setFrame:frameRect display:flag];
    
    for (NSWindow *childWindow in [self childWindows]) {
        [childWindow setFrame:NSInsetRect(frameRect, 2, 2) display:flag];
    }
}

- (void) addChildWindow:(NSWindow *)childWin ordered:(NSWindowOrderingMode)place
{
    [super addChildWindow:childWin ordered:place];
}


- (void) addMainListener:(id<MainWindowListener>)listener
{
    if (!_mainListeners) {
        _mainListeners = [NSHashTable weakObjectsHashTable];
    }
    
    [_mainListeners addObject:listener];
}


- (NSArray *) mainListeners
{
    return [_mainListeners allObjects];
}


@end