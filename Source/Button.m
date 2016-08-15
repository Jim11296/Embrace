//
//  MainButton.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Button.h"
#import "MainIconView.h"
#import "NoDropImageView.h"

@implementation Button {
    BOOL _highlighted;
    MainIconView *_iconView;
    NSImageView  *_backgroundView;
}


- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [self _setupButton];
    return self;
}


- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [self _setupButton];
    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) _setupButton
{
    _alertColor       = GetRGBColor(0xff0000, 1.0);
    _alertActiveColor = GetRGBColor(0xc00000, 1.0);
    _normalColor      = GetRGBColor(0x737373, 1.0);
    _activeColor      = GetRGBColor(0x4c4c4c, 1.0);
    _inactiveColor    = GetRGBColor(0xb2b2b2, 1.0);
    _disabledColor    = GetRGBColor(0xb2b2b2, 1.0);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSWindowDidBecomeMainNotification        object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSApplicationDidResignActiveNotification object:nil];

    _backgroundView = [[NoDropImageView alloc] initWithFrame:[self bounds]];
    [self addSubview:_backgroundView];
    
    [_backgroundView setImage:[NSImage imageNamed:@"ButtonNormal"]];
    [_backgroundView setImageScaling:NSImageScaleNone];
    
    _iconView = [[MainIconView alloc] initWithFrame:[self bounds]];
    [self addSubview:_iconView];

    [self setWantsLayer:YES];
    [[self layer] setMasksToBounds:NO];
    
    [self setButtonType:NSMomentaryChangeButton];
    
    [self _update:nil];
}


- (void) layout
{
    [super layout];
    [_iconView setFrame:[self bounds]];
}


- (void) mouseDown:(NSEvent *)theEvent
{
    _highlighted = YES;
    [self _update:nil];

    [super mouseDown:theEvent];

    _highlighted = NO;
    [self _update:nil];
}


- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self _update:nil];
}


- (void) windowDidUpdateMain:(NSWindow *)window
{
    [self _update:nil];
}


- (void) _update:(NSNotification *)note
{
    NSColor *color = _normalColor;

    BOOL isInactive = ![[self window] isMainWindow] || ![NSApp isActive];
    
    if (![self isEnabled]) {
        color = _disabledColor;

    } else if (isInactive) {
        color = _inactiveColor;

    } else if ([self isAlert]) {
        color = _highlighted ? _alertActiveColor : _alertColor;

    } else if (_highlighted) {
        color = _activeColor;
    }

    [_iconView setImage:[self image]];
    [_iconView setTintColor:color];
    
    if (isInactive) {
        [_backgroundView setImage:[NSImage imageNamed:@"ButtonInactive"]];
    } else if (_highlighted) {
        [_backgroundView setImage:[NSImage imageNamed:@"ButtonPressed"]];
    } else {
        [_backgroundView setImage:[NSImage imageNamed:@"ButtonNormal"]];
    }

    [_backgroundView setHidden:_iconOnly];
}


- (void) setEnabled:(BOOL)flag
{
    [super setEnabled:flag];
    [self _update:nil];
}


- (void) drawRect:(NSRect)dirtyRect
{ }


- (void) setAlert:(BOOL)alert
{
    if (_alert != alert) {
        _alert = alert;
        [self _update:nil];
    }
}


- (void) setAlertColor:(NSColor *)alertColor
{
    if (_alertColor != alertColor) {
        _alertColor = alertColor;
        [self _update:nil];
    }
}


- (void) setIconOnly:(BOOL)iconOnly
{
    if (_iconOnly != iconOnly) {
        _iconOnly = iconOnly;
        [self _update:nil];
    }
}


- (void) performOpenAnimationToImage:(NSImage *)image enabled:(BOOL)enabled
{
    [_iconView performAnimation:MainIconAnimationTypeOpen image:image tintColor:enabled ? _normalColor : _inactiveColor];
}


- (void) performPopAnimation:(BOOL)isPopIn toImage:(NSImage *)image alert:(BOOL)alert
{
    [_iconView performAnimation:(isPopIn ? MainIconAnimationTypeSubtlePopIn : MainIconAnimationTypeSubtlePopOut)
                          image: image
                      tintColor: alert ? _alertColor : _normalColor];
}


- (void) setWiggling:(BOOL)wiggling
{
    [_iconView setWiggling:wiggling];
}


- (BOOL) isWiggling
{
    return [_iconView isWiggling];
}


- (void) setImage:(NSImage *)image
{
    [super setImage:image];
    [self _update:nil];
}


@end

