//
//  SimpleProgressBar.m
//  Embrace
//
//  Created by Ricci Adams on 2017-06-25.
//  Copyright (c) 2017 Ricci Adams. All rights reserved.
//

#import "SimpleProgressBar.h"


@interface SimpleProgressBar () <CALayerDelegate>
@end


@implementation SimpleProgressBar {
    NSColor *_fillColor;

    CALayer *_leftCapLayer;
    CALayer *_inactiveBarLayer;
    CALayer *_activeBarLayer;
    CALayer *_rightCapLayer;

    CGFloat _leftCapFillWidth;
    CGFloat _rightCapFillWidth;
}


- (id) initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        [self _commonSimpleProgressBarInit];
    }
    
    return self;
}


- (id) initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self _commonSimpleProgressBarInit];
    }

    return self;
}


- (void) _commonSimpleProgressBarInit
{
    [self setWantsLayer:YES];
    [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
    [[self layer] setMasksToBounds:YES];
    [self setAutoresizesSubviews:NO];

    [self setNeedsLayout:YES];

    _leftCapLayer     = [CALayer layer];
    _inactiveBarLayer = [CALayer layer];
    _activeBarLayer   = [CALayer layer];
    _rightCapLayer    = [CALayer layer];

    [_leftCapLayer     setDelegate:self];
    [_rightCapLayer    setDelegate:self];
    [_inactiveBarLayer setDelegate:self];
    [_activeBarLayer   setDelegate:self];

    [_leftCapLayer  setNeedsDisplay];
    [_rightCapLayer setNeedsDisplay];
   
    [[self layer] addSublayer:_leftCapLayer];
    [[self layer] addSublayer:_inactiveBarLayer];
    [[self layer] addSublayer:_activeBarLayer];
    [[self layer] addSublayer:_rightCapLayer];

    _inactiveColor = [Theme colorNamed:@"MeterInactive"];
    _activeColor   = [Theme colorNamed:@"MeterActive"];
    [_inactiveBarLayer setBackgroundColor:[_inactiveColor CGColor]];

    [self _updateFillColor];
}


- (void) layout
{
    if (@available(macOS 10.12, *)) {
        // Opt-out of Auto Layout
    } else {
        [super layout]; 
    }

    NSRect bounds = [self bounds];

    CGFloat fillWidth = _percentage * bounds.size.width;
    CGFloat capWidth  = bounds.size.height;
    CGRect  barFrame  = CGRectInset(bounds, capWidth, 0);

    CGFloat mainFillWidth;

    // Compute left cap fill width
    {
        CGFloat leftCapFillWidth = fillWidth;
        if (leftCapFillWidth > capWidth) leftCapFillWidth = capWidth;
        fillWidth -= leftCapFillWidth;

        if (_leftCapFillWidth != leftCapFillWidth) {
            _leftCapFillWidth = leftCapFillWidth;
            [_leftCapLayer setNeedsDisplay];
        }
    }

    // Compute main fill width
    {
        mainFillWidth = fillWidth;
        if (mainFillWidth > barFrame.size.width) mainFillWidth = barFrame.size.width;
        fillWidth -= mainFillWidth;
    }

    // Compute right fill width
    {
        CGFloat rightCapFillWidth = fillWidth;

        if (_rightCapFillWidth != rightCapFillWidth) {
            _rightCapFillWidth = rightCapFillWidth;
            [_rightCapLayer setNeedsDisplay];
        }
    }

    [_leftCapLayer     setFrame:CGRectMake(0, 0, capWidth, capWidth)];
    [_inactiveBarLayer setFrame:barFrame];
    [_rightCapLayer    setFrame:CGRectMake(bounds.size.width - capWidth, 0, capWidth, capWidth)];

    barFrame.size.width = mainFillWidth;
    [_activeBarLayer setFrame:barFrame];
}


- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self _inheritContentsScaleFromWindow:[self window]];
}


#pragma mark - CALayer Delegate

- (BOOL) layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
    [self _inheritContentsScaleFromWindow:window];
    return (layer == _leftCapLayer || layer == _rightCapLayer);
}


- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    NSGraphicsContext *oldContext = [NSGraphicsContext currentContext];
    
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO]];

    CGRect bounds = [layer bounds];
    
    CGRect maskRect = bounds;
    maskRect.size.width *= 2;

    CGFloat fillWidth;

    if (layer == _rightCapLayer) {
        maskRect.origin.x -= bounds.size.width;
        fillWidth = _rightCapFillWidth;
    } else {
        fillWidth = _leftCapFillWidth;
    }

    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:maskRect xRadius:(bounds.size.height / 2) yRadius:(bounds.size.height / 2)];
    [path addClip];
    
    CGRect frame = bounds;

    [_inactiveColor set];
    CGContextFillRect(context, frame);
    
    frame.size.width = fillWidth;

    [_fillColor set];
    CGContextFillRect(context, frame);

    [NSGraphicsContext setCurrentContext:oldContext];
}


#pragma mark - Private Methods

- (void) _inheritContentsScaleFromWindow:(NSWindow *)window
{
    CGFloat contentsScale = [window backingScaleFactor];

    if (contentsScale) {
        [_leftCapLayer setContentsScale:contentsScale];
        [_rightCapLayer setContentsScale:contentsScale];
    }
}


- (void) _updateFillColor
{
    NSColor *fillColor = _activeColor;
    
    if (_tintColor) {
        fillColor = [fillColor blendedColorWithFraction:_tintLevel ofColor:_tintColor];
    }

    if (_leftCapFillWidth  > 0) [_leftCapLayer  setNeedsDisplay];
    if (_rightCapFillWidth > 0) [_rightCapLayer setNeedsDisplay];
    
    _fillColor = fillColor;

    [_activeBarLayer setBackgroundColor:[fillColor CGColor]];
}


#pragma mark - Accessors

- (void) setPercentage:(CGFloat)percentage
{
    if (_percentage != percentage) {
        _percentage = percentage;
        [self setNeedsLayout:YES];
    }
}


- (void) setInactiveColor:(NSColor *)inactiveColor
{
    if (_inactiveColor != inactiveColor) {
        _inactiveColor = inactiveColor;

        [_inactiveBarLayer setBackgroundColor:[inactiveColor CGColor]];

        [_leftCapLayer  setNeedsDisplay];
        [_rightCapLayer setNeedsDisplay];
    }
}


- (void) setActiveColor:(NSColor *)activeColor
{
    if (_activeColor != activeColor) {
        _activeColor = activeColor;
        [self _updateFillColor];
    }
}


- (void) setTintColor:(NSColor *)tintColor
{
    if (_tintColor != tintColor) {
        _tintColor = tintColor;
        [self _updateFillColor];
    }
}


- (void) setTintLevel:(CGFloat)tintLevel
{
    if (_tintLevel != tintLevel) {
        _tintLevel = tintLevel;
        [self _updateFillColor];
    }
}


@end
