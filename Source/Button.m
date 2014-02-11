//
//  MainButton.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Button.h"

@implementation Button {
    BOOL _highlighted;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [self _setupColors];
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [self _setupColors];
    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) _setupColors
{
    _alertColor    = GetRGBColor(0xc00000, 1.0);
    _normalColor   = GetRGBColor(0x1866E9, 1.0);
    _activeColor   = GetRGBColor(0x0a48b1, 1.0);
    _inactiveColor = GetRGBColor(0x000000, 0.5);
    _disabledColor = GetRGBColor(0x000000, 0.25);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSWindowDidBecomeMainNotification        object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSApplicationDidResignActiveNotification object:nil];
}


- (void) _update:(NSNotification *)note
{
    [self setNeedsDisplay:YES];
}


- (void) drawRect:(NSRect)dirtyRect
{
    NSImage *image = [self image];
    
    NSColor *color = _normalColor;
    NSRect bounds = [self bounds];

    if ([self isAlert]) {
        color = _alertColor;

    } else if (![self isEnabled]) {
        color = _disabledColor;

    } else if (![[self window] isMainWindow] || ![NSApp isActive]) {
        color = _inactiveColor;
    
    } else if ([[self cell] isHighlighted]) {
        color = _activeColor;
    }
    
    NSRect rect = NSZeroRect;
    rect.size = [image size];
    rect.origin.x = round((bounds.size.width - rect.size.width) / 2);
    rect.origin.y = round((bounds.size.height - rect.size.height) / 2);
    
    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:YES hints:nil];
    
    [color set];
    NSRectFillUsingOperation([self bounds], NSCompositeSourceIn);
}


- (void) setAlert:(BOOL)alert
{
    if (_alert != alert) {
        _alert = alert;
        [self setNeedsDisplay];
    }
}


@end
