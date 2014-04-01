//
//  CurrentTrackController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-21.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "CurrentTrackController.h"
#import "Player.h"
#import "WhiteWindow.h"
#import "WaveformView.h"
#import "CloseButton.h"

@interface CurrentTrackController () <PlayerListener, NSWindowDelegate>
@end


@implementation CurrentTrackController {
    NSTrackingArea *_closeButtonTrackingArea;
}

- (NSString *) windowNibName
{
    return @"CurrentTrackWindow";
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[Player sharedInstance] removeObserver:self forKeyPath:@"currentTrack"];
    
    [[self mainView] removeTrackingArea:_closeButtonTrackingArea];
}


- (void) mouseEntered:(NSEvent *)theEvent
{
    [[(WhiteWindow *)[self window] closeButton] setForceVisible:YES];
}


- (void) mouseExited:(NSEvent *)theEvent
{
    [[(WhiteWindow *)[self window] closeButton] setForceVisible:NO];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _player) {
        if ([keyPath isEqualToString:@"currentTrack"]) {
            [self _updateTrack];
        }
    }
}


- (void) _updateTrack
{
    Track *track = [[Player sharedInstance] currentTrack];

    if (track) {
        [[self waveformView] setTrack:track];

        [[self waveformView] setHidden:NO];
        [[self leftLabel]    setHidden:NO];
        [[self rightLabel]   setHidden:NO];

        [[self noTrackLabel] setHidden:YES];

    } else {
        [[self waveformView] setHidden:YES];
        [[self leftLabel]    setHidden:YES];
        [[self rightLabel]   setHidden:YES];

        [[self noTrackLabel] setHidden:NO];
    }
}


- (void) loadWindow
{
    [super loadWindow];

    NSRect contentRect = [[self childWindow] frame];
    NSUInteger styleMask = NSTitledWindowMask|NSClosableWindowMask|NSResizableWindowMask|NSTexturedBackgroundWindowMask;

    WhiteWindow *window = [[WhiteWindow alloc] initWithContentRect:contentRect styleMask:styleMask backing:NSBackingStoreBuffered defer:NO];
    [window setupAsParentWindow];

    [self setWindow:window];
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    NSWindow *parentWindow = [self window];
    NSWindow *childWindow  = [self childWindow];

    [parentWindow setDelegate:self];
    [parentWindow setFrameAutosaveName:@"CurrentTrackWindow"];

    if (![parentWindow setFrameUsingName:@"CurrentTrackWindow"]) {
        NSScreen *screen = [[NSScreen screens] firstObject];
        
        NSRect screenFrame = [screen visibleFrame];

        NSRect windowFrame = NSMakeRect(0, screenFrame.origin.y, 0, 64);

        windowFrame.size.width = screenFrame.size.width - 32;
        windowFrame.origin.x = round((screenFrame.size.width - windowFrame.size.width) / 2);
        windowFrame.origin.x += screenFrame.origin.x;
    
        [[self window] setFrame:windowFrame display:NO];
    }
    
    [childWindow setIgnoresMouseEvents:YES];
    [childWindow setBackgroundColor:[NSColor clearColor]];
    [childWindow setOpaque:NO];

    Player *player = [Player sharedInstance];
    [self setPlayer:[Player sharedInstance]];

    [player addObserver:self forKeyPath:@"currentTrack" options:0 context:NULL];

    [self _updateTrack];
    
    [[self mainView] setPostsBoundsChangedNotifications:YES];
    
    [[Player sharedInstance] addListener:self];

    [self _updateTrack];

    [parentWindow setMinSize:[childWindow minSize]];

    NSTrackingAreaOptions options = NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect;
    _closeButtonTrackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];

    [[self mainView] addTrackingArea:_closeButtonTrackingArea];

    [[self window] setExcludedFromWindowsMenu:YES];
}


- (void) windowWillClose:(NSNotification *)notification;
{
    if ([notification object] == [self childWindow]) {
        [[self window] orderOut:self];
    } else {
        [[self childWindow] orderOut:self];
    }
}


- (IBAction) showWindow:(id)sender
{
    NSDisableScreenUpdates();

    [[self window] addChildWindow:[self childWindow] ordered:NSWindowAbove];
    [[self window] setFrame:[[self window] frame] display:YES];

    [super showWindow:sender];
    [[self childWindow] orderFront:self];
    
    NSEnableScreenUpdates();
}


- (void) player:(Player *)player didUpdatePlaying:(BOOL)playing { }
- (void) player:(Player *)player didUpdateIssue:(PlayerIssue)issue { }
- (void) player:(Player *)player didUpdateVolume:(double)volume { }
- (void) player:(Player *)player didInterruptPlaybackWithReason:(PlayerInterruptionReason)reason { }

- (void) playerDidTick:(Player *)player
{
    [[self waveformView] setPercentage:[player percentage]];
}


@end
