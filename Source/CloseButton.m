//
//  MainButton.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "CloseButton.h"

@implementation CloseButton {
    BOOL _mouseInside;
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
    NSTrackingAreaOptions options = NSTrackingInVisibleRect|NSTrackingActiveAlways|NSTrackingMouseEnteredAndExited;
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];

    [self addTrackingArea: trackingArea];

    [self setAlphaValue:0];
}


- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}


- (void) drawRect:(NSRect)dirtyRect
{
    NSImage *image;

    if (![[self window] isMainWindow]) {
        image = [NSImage imageNamed:@"close_button_inactive"];
    
    } else if (_highlighted) {
        image = [NSImage imageNamed:@"close_button_pressed"];

    } else if (_mouseInside) {
        image = [NSImage imageNamed:@"close_button_hover"];

    } else {
        image = [NSImage imageNamed:@"close_button_normal"];
    }

    NSRect bounds = [self bounds];
    
    NSRect rect = NSZeroRect;
    rect.size = [image size];
    rect.origin.x = round((bounds.size.width - rect.size.width) / 2);
    rect.origin.y = round((bounds.size.height - rect.size.height) / 2);
    
    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:YES hints:nil];
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) windowDidUpdateMain:(NSWindow *)window
{
    [self setNeedsDisplay:YES];
}


- (void) _updateVisibility
{
    BOOL visible = _mouseInside || _alwaysVisible;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [[self animator] setAlphaValue:(visible ? 1.0 : 0.0)];
    } completionHandler:nil];
}


- (void) mouseEntered:(NSEvent *)theEvent
{
    _mouseInside = YES;
    [self _setHighlighted:NO];
    [self setNeedsDisplay:YES];
}


- (void) mouseExited:(NSEvent *)theEvent
{
    _mouseInside = NO;
    [self setNeedsDisplay:YES];
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
    [self _setHighlighted:YES];
    [super mouseDown:theEvent];
}


- (void) mouseUp:(NSEvent *)theEvent
{
    [self _setHighlighted:NO];
    [super mouseUp:theEvent];
}


- (void) setAlwaysVisible:(BOOL)alwaysVisible
{
    if (_alwaysVisible != alwaysVisible) {
        _alwaysVisible = alwaysVisible;
        [self _updateVisibility];
    }
}

@end
