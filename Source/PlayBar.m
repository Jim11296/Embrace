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

        [_activeBar    setBackgroundColor:[GetRGBColor(0x707070, 1.0) CGColor]];
        [_inactiveBar  setBackgroundColor:[GetRGBColor(0xc0c0c0, 1.0) CGColor]];
        [_playhead     setBackgroundColor:[GetRGBColor(0x000000, 1.0) CGColor]];
        [_bottomBorder setBackgroundColor:[GetRGBColor(0x0, 0.15) CGColor]];

        [self setWantsLayer:YES];
        [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
        [[self layer] setMasksToBounds:YES];
        
        [[self layer] addSublayer:_bottomBorder];
        [[self layer] addSublayer:_inactiveBar];
        [[self layer] addSublayer:_activeBar];
        [[self layer] addSublayer:_playhead];
    }
    
    return self;
}

/*

- (void) drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    NSRect bounds = [self bounds];

    CGFloat barHeight = 5;

    NSRect barRect = bounds;
    barRect.size.height = barHeight;
    barRect.origin.y = 0;

    CGFloat midX = bounds.size.width * _percentage;
    
    NSRect leftRect, rightRect;
    NSDivideRect(bounds, &leftRect, &rightRect, midX - bounds.origin.x, NSMinXEdge);

    NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRect:barRect];
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext saveGraphicsState];

    [GetRGBColor(0x0, 0.66) set];
    [[NSBezierPath bezierPathWithRect:leftRect] addClip];
    [roundedPath fill];

    [NSGraphicsContext restoreGraphicsState];
    
    [GetRGBColor(0x0, 0.15) set];
    [[NSBezierPath bezierPathWithRect:rightRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
}

*/

- (void) layout
{
    [super layout];

    NSRect bounds = [self bounds];

    NSRect barFrame = bounds;
    barFrame.size.height = 2;

    NSRect bottomFrame = bounds;
    bottomFrame.size.height = 1;

    NSRect playheadFrame = bounds;
    playheadFrame.size.height = 4;

    if (!_playing) {
        barFrame.origin.y = -barFrame.size.height;
        playheadFrame.origin.y = -playheadFrame.size.height;
    }

    

    CGFloat midX = bounds.size.width * _percentage;
    
    NSRect leftRect, rightRect;
    NSDivideRect(barFrame, &leftRect, &rightRect, midX - barFrame.origin.x, NSMinXEdge);

    CGFloat scale = [[self window] backingScaleFactor];

    playheadFrame.origin.x = round((bounds.size.width - 2) * _percentage * scale) / scale;
    playheadFrame.size.width = 2;
    
    [_activeBar setFrame:leftRect];
    [_inactiveBar setFrame:rightRect];
    [_playhead setFrame:playheadFrame];
    [_bottomBorder setFrame:bottomFrame];
}


- (void) setPercentage:(float)percentage
{
    if (_percentage != percentage) {
        if (isnan(percentage)) percentage = 0;
        _percentage = percentage;
        [self setNeedsLayout:YES];
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
