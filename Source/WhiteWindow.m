//
//  MainWindow.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WhiteWindow.h"
#import "CloseButton.h"


@implementation WhiteWindow

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

    NSColor *backgroundColor;
    
    if (isMainWindow) {
        backgroundColor = [NSColor colorWithCalibratedWhite:(0xF8 / 255.0) alpha:1.0];
    } else {
        backgroundColor = [NSColor colorWithCalibratedWhite:(0xFF / 255.0) alpha:1.0];
    }

    [self setBackgroundColor:backgroundColor];

    for (NSView *view in _hiddenViewsWhenInactive) {
        [view setHidden:!isMainWindow];
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


- (void) setupWithHeaderView:(NSView *)headerView mainView:(NSView *)mainView
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateActiveness:) name:NSWindowDidBecomeMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateActiveness:) name:NSWindowDidResignMainNotification object:nil];

    NSButton *miniaturizeButton = [self standardWindowButton:NSWindowMiniaturizeButton];
    NSButton *zoomButton        = [self standardWindowButton:NSWindowZoomButton];
    NSButton *closeButton       = [self standardWindowButton:NSWindowCloseButton];

    NSColor *backgroundColor = [NSColor colorWithCalibratedWhite:(0xF8 / 255.0) alpha:1.0];

    [self setMovableByWindowBackground:YES];
    [self setTitle:@""];
    [self setBackgroundColor:backgroundColor];
    [self setHasShadow:YES];

    [miniaturizeButton setHidden:YES];
    [zoomButton setHidden:YES];
    [closeButton setHidden:YES];

    NSRect frame = [self frame];
    frame.origin = NSZeroPoint;
    
    NSView *contentView = [self contentView];

    NSSize windowSize = [self frame].size;
    NSSize contentSize = [contentView frame].size;
    NSSize headerSize  = [headerView frame].size;
    
    CGFloat titlebarHeight = windowSize.height - contentSize.height;
    CGFloat contentTopPadding = headerSize.height - titlebarHeight;
    
    if (headerView) {
        NSRect headerFrame = [headerView frame];
        headerFrame.origin.y = contentSize.height - contentTopPadding;
        headerFrame.origin.x = 0;
        headerFrame.size.width = frame.size.width;

        NSView *frameView = [contentView superview];
        [frameView addSubview:headerView];
        [headerView setFrame:headerFrame];

        [headerView setWantsLayer:YES];
        [contentView setWantsLayer:YES];
    }


    if (mainView) {
        NSRect headerRect = [headerView convertRect:[headerView bounds] toView:contentView];
        
        NSRect mainViewFrame = [[self contentView] bounds];
        mainViewFrame.size.height = NSMinY(headerRect);
        [mainView setFrame:mainViewFrame];
        
        [[self contentView] addSubview:mainView];
    }


    NSView *closeButtonSuperview = headerView ? headerView : [contentView superview];
    NSRect  closeButtonFrame = NSMakeRect(4, 0, 12, 12);
    
    closeButtonFrame.origin.y = [closeButtonSuperview bounds].size.height - 16;
    
    CloseButton *whiteCloseButton = [[CloseButton alloc] initWithFrame:closeButtonFrame];
    [whiteCloseButton setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
    [closeButtonSuperview addSubview:whiteCloseButton];
    
    [whiteCloseButton setTarget:self];
    [whiteCloseButton setAction:@selector(_handleCloseButton:)];

    _closeButton = whiteCloseButton;
}


- (void) setupAsParentWindow
{
    [self setupWithHeaderView:nil mainView:nil];
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


- (void) setHiddenViewsWhenInactive:(NSArray *)hiddenViewsWhenInactive
{
    if (_hiddenViewsWhenInactive != hiddenViewsWhenInactive) {
        for (NSView *view in _hiddenViewsWhenInactive) {
            [view setHidden:NO];
        }

        _hiddenViewsWhenInactive = hiddenViewsWhenInactive;
        
        [self _updateActiveness:nil];
    }
}


@end