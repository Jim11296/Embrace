//
//  MainButton.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Button.h"
#import "MainIconView.h"


@implementation Button {
    BOOL _highlighted;
    MainIconView *_iconView;
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
    _alertColor       = GetRGBColor(0xc00000, 1.0);
    _alertActiveColor = GetRGBColor(0xa00000, 1.0);
    _normalColor      = GetRGBColor(0x1866E9, 1.0);
    _activeColor      = GetRGBColor(0x0a48b1, 1.0);
    _inactiveColor    = GetRGBColor(0x000000, 0.5);
    _disabledColor    = GetRGBColor(0x000000, 0.25);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSWindowDidBecomeMainNotification        object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSApplicationDidResignActiveNotification object:nil];

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


- (void) _update:(NSNotification *)note
{
    NSColor *color = _normalColor;

    if (![self isEnabled]) {
        color = _disabledColor;

    } else if (![[self window] isMainWindow] || ![NSApp isActive]) {
        color = _inactiveColor;

    } else if ([self isAlert]) {
        color = _highlighted ? _alertActiveColor : _alertColor;

    } else if (_highlighted) {
        color = _activeColor;
    }

    [_iconView setImage:[self image]];
    [_iconView setTintColor:color];
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


- (void) flipToImage:(NSImage *)image enabled:(BOOL)enabled
{
    [_iconView flipToImage:image tintColor:enabled ? _normalColor : _inactiveColor];
}


- (void) setWiggling:(BOOL)wiggling
{
    if (_wiggling != wiggling) {
        _wiggling = wiggling;

        if (!wiggling) {
            [[self layer] removeAnimationForKey:@"wiggling"];
        } else {
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
            
            CGAffineTransform from = CGAffineTransformMakeScale(1,    1);
            CGAffineTransform to   = CGAffineTransformMakeScale(0.95, 0.95);
            
            [animation setFromValue:[NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(from)]];
            [animation setToValue:[NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(to)]];
            
            [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [animation setRepeatCount:INFINITY];
            [animation setAutoreverses:YES];
            [animation setDuration:0.15];
            
            [[self layer] addAnimation:animation forKey:@"wiggling"];
        }
    }
}


- (void) setImage:(NSImage *)image
{
    [super setImage:image];
    [self _update:nil];
}


@end

