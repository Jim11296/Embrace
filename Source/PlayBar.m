//
//  PlayBar.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "PlayBar.h"

@implementation PlayBar {
    CALayer *_playhead;
    CALayer *_inactiveBar;
    CALayer *_activeBar;
    CALayer *_bottomBorder;
    
    CGFloat  _playheadX;
}



- (id) initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _playhead     = [CALayer layer];
        _inactiveBar  = [CALayer layer];
        _activeBar    = [CALayer layer];
        _bottomBorder = [CALayer layer];

        [_playhead     setDelegate:self];
        [_inactiveBar  setDelegate:self];
        [_activeBar    setDelegate:self];
        [_bottomBorder setDelegate:self];

        [_playhead setCornerRadius:1];

        [self setWantsLayer:YES];
        [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
        [[self layer] setMasksToBounds:YES];
        [self setAutoresizesSubviews:NO];
        
        [[self layer] addSublayer:_bottomBorder];
        [[self layer] addSublayer:_inactiveBar];
        [[self layer] addSublayer:_activeBar];
        [[self layer] addSublayer:_playhead];
        
        [self _updateColors];
    }
    
    return self;
}


- (void) _updateColors
{
    BOOL isMainWindow = [[self window] isMainWindow];

    NSColor *activeColor   = GetNamedColor(isMainWindow ? @"MeterActiveMain" : @"MeterActive");
    NSColor *inactiveColor = GetNamedColor(@"MeterInactive");
    NSColor *dotColor      = GetNamedColor(@"MeterDot");

    [_activeBar    setBackgroundColor:[activeColor   CGColor]];
    [_inactiveBar  setBackgroundColor:[inactiveColor CGColor]];
    [_playhead     setBackgroundColor:[dotColor      CGColor]];
    [_bottomBorder setBackgroundColor:[inactiveColor CGColor]];
}


- (void) viewDidChangeEffectiveAppearance
{
    [self _updateColors];
}


- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [self _updateColors];
}


- (void) layout
{
    if (@available(macOS 10.12, *)) {
        // Opt-out of Auto Layout
    } else {
        [super layout]; 
    }

    NSRect bounds = [self bounds];

    NSRect barFrame = bounds;
    barFrame.size.height = 3;

    NSRect bottomFrame = bounds;
    bottomFrame.size.height = 1;

    NSRect playheadFrame = bounds;
    playheadFrame.size.height = 8;

    if (!_playing) {
        barFrame.origin.y = -barFrame.size.height;
        playheadFrame.origin.y = -playheadFrame.size.height;
    } else {
        playheadFrame.origin.y = -1;
        bottomFrame.origin.y = -bottomFrame.size.height;
    }

    [self _updatePlayheadX];
    
    NSRect leftRect, rightRect;
    NSDivideRect(barFrame, &leftRect, &rightRect, _playheadX - barFrame.origin.x, NSMinXEdge);

    playheadFrame.origin.x   = _playheadX;
    playheadFrame.size.width = 2;
    
    [_activeBar    setFrame:leftRect];
    [_inactiveBar  setFrame:rightRect];
    [_playhead     setFrame:playheadFrame];
    [_bottomBorder setFrame:bottomFrame];
}



- (void) _updatePlayheadX
{
    NSRect bounds = [self bounds];
    CGFloat scale = [[self window] backingScaleFactor];
    _playheadX = round((bounds.size.width - 2) * _percentage * scale) / scale;
}


- (void) setPercentage:(float)percentage
{
    if (_percentage != percentage) {
        if (isnan(percentage)) percentage = 0;
        _percentage = percentage;

        CGFloat oldPlayheadX = _playheadX;
        [self _updatePlayheadX];
        
        if (oldPlayheadX != _playheadX) {
            [self setNeedsLayout:YES];
        }
    }
}


- (void) setPlaying:(BOOL)playing
{
    if (_playing != playing) {
        _playing = playing;
        [self setNeedsLayout:YES];
    }
}


@end
