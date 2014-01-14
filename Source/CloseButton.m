//
//  MainButton.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "CloseButton.h"

@implementation CloseButton {
    BOOL _highlighted;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [self _setupCloseButton];
    return self;
}


- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [self _setupCloseButton];
    return self;
}


- (void) _setupCloseButton
{
    NSTrackingAreaOptions options = NSTrackingInVisibleRect|NSTrackingActiveInKeyWindow|NSTrackingMouseEnteredAndExited;
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];

    [self addTrackingArea: trackingArea];

    [self setAlphaValue:0];
}


- (void) drawRect:(NSRect)dirtyRect
{
    NSImage *image;

    if (_highlighted) {
        image = [NSImage imageNamed:@"close_pressed"];
    } else {
        image = [NSImage imageNamed:@"close_normal"];
    }

    NSRect bounds = [self bounds];
    
    NSRect rect = NSZeroRect;
    rect.size = [image size];
    rect.origin.x = round((bounds.size.width - rect.size.width) / 2);
    rect.origin.y = round((bounds.size.height - rect.size.height) / 2);
    
    [image drawInRect:rect];
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) mouseEntered:(NSEvent *)theEvent
{
    [self _setHighlighted:NO];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [[self animator] setAlphaValue:1];
    } completionHandler:nil];
}


- (void) mouseExited:(NSEvent *)theEvent
{
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [[self animator] setAlphaValue:0];
    } completionHandler:nil];
}


- (void) _setHighlighted:(BOOL)highlighted
{
    if (_highlighted != highlighted) {
        _highlighted = highlighted;
        [self setNeedsDisplay:YES];
    }
}


- (void) mouseDown:(NSEvent *)theEvent
{
    [super mouseDown:theEvent];
    [self _setHighlighted:YES];
}

- (void) mouseUp:(NSEvent *)theEvent
{
    [super mouseUp:theEvent];
    [self _setHighlighted:NO];
}


@end
