//
//  MainWindow.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "MainWindow.h"


@implementation MainWindowContentView
@end


@implementation MainWindow {
    NSView *_contentWrapper;
    NSView *_actualContentView;
    BOOL _preventWindowFrameChange;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) _updateBackgroundColor:(NSNotification *)note
{
    NSColor *backgroundColor;
    
    if ([self isMainWindow]) {
        backgroundColor = [NSColor colorWithCalibratedWhite:(0xF8 / 255.0) alpha:1.0];
    } else {
        backgroundColor = [NSColor colorWithCalibratedWhite:(0xFF / 255.0) alpha:1.0];
    }

    [self setBackgroundColor:backgroundColor];
}


- (void) setupWithHeaderView:(NSView *)headerView mainView:(NSView *)mainView
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateBackgroundColor:) name:NSWindowDidBecomeMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateBackgroundColor:) name:NSWindowDidResignMainNotification object:nil];

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
    
    NSRect mainViewFrame = [mainView frame];
    mainViewFrame.size.height -= contentTopPadding;
    [mainView setFrame:mainViewFrame];
    
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


@end