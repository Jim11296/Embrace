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

@interface CurrentTrackController () <PlayerListener>
@end


@implementation CurrentTrackController {
    WhiteWindow *_parentWindow;
}

- (NSString *) windowNibName
{
    return @"CurrentTrackWindow";
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[Player sharedInstance] removeObserver:self forKeyPath:@"currentTrack"];
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
    [[self waveformView] setTrack:track];
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    NSRect contentRect = [[self window] frame];
    NSUInteger styleMask = NSTitledWindowMask|NSClosableWindowMask|NSResizableWindowMask|NSTexturedBackgroundWindowMask;

    _parentWindow = [[WhiteWindow alloc] initWithContentRect:contentRect styleMask:styleMask backing:NSBackingStoreBuffered defer:NO];
    [_parentWindow setupAsParentWindow];

    [_parentWindow addChildWindow:[self window] ordered:NSWindowAbove];

    [_parentWindow setFrameAutosaveName:@"CurrentTrackWindow"];

    if (1 || ![_parentWindow setFrameUsingName:@"CurrentTrackWindow"]) {
        NSScreen *screen = [[NSScreen screens] firstObject];
        
        NSRect screenFrame = [screen visibleFrame];

        NSRect windowFrame = NSMakeRect(0, screenFrame.origin.y, 0, 64);

        windowFrame.size.width = screenFrame.size.width - 32;
        windowFrame.origin.x = round((screenFrame.size.width - windowFrame.size.width) / 2);
        windowFrame.origin.x += screenFrame.origin.x;
    
        [_parentWindow setFrame:windowFrame display:NO];
    }
    
    [[self window] setIgnoresMouseEvents:YES];
    [[self window] setBackgroundColor:[NSColor clearColor]];
    [[self window] setOpaque:NO];

    Player *player = [Player sharedInstance];
    [self setPlayer:[Player sharedInstance]];

    [player addObserver:self forKeyPath:@"currentTrack" options:0 context:NULL];

    [self _updateTrack];
    
    [[self mainView] setPostsBoundsChangedNotifications:YES];
    [[self mainView] setFrame:[[[self window] contentView] bounds]];
    
    [[Player sharedInstance] addListener:self];

    [_parentWindow makeKeyAndOrderFront:self];
}


- (void) player:(Player *)player didUpdatePlaying:(BOOL)playing
{

}


- (void) playerDidTick:(Player *)player
{
    [[self waveformView] setPercentage:[player percentage]];
}


@end
