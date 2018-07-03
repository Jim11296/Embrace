//
//  SimpleProgressBar.m
//  Embrace
//
//  Created by Ricci Adams on 2017-06-25.
//  Copyright (c) 2017 Ricci Adams. All rights reserved.
//

#import "SetlistProgressBar.h"


static void sBlendComponents(CGFloat *a, CGFloat *b, CGFloat fraction, CGFloat *output)
{
    if      (fraction > 1) fraction = 1;
    else if (fraction < 0) fraction = 0;
    
    CGFloat iFraction = 1.0 - fraction;

    output[0] = (b[0] * fraction) + (a[0] * iFraction);
    output[1] = (b[1] * fraction) + (a[1] * iFraction);
    output[2] = (b[2] * fraction) + (a[2] * iFraction);
    output[3] = (b[3] * fraction) + (a[3] * iFraction);
}


@interface SetlistProgressBar () <CALayerDelegate>
@end


@implementation SetlistProgressBar {
    CALayer *_leftCapLayer;
    CALayer *_leftBarLayer;
    CALayer *_rightBarLayer;
    CALayer *_rightCapLayer;

    CGColorSpaceRef _colorSpace;
    CGColorRef _leftColor;
    CGColorRef _rightColor;

    CGFloat _leftCapFillWidth;
    CGFloat _rightCapFillWidth;

    CGFloat _unfilledComponents[4];
    CGFloat _filledComponents[4];
    CGFloat _redComponents[4];
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
    
    _rounded = YES;

    _leftCapLayer  = [CALayer layer];
    _leftBarLayer  = [CALayer layer];
    _rightBarLayer = [CALayer layer];
    _rightCapLayer = [CALayer layer];

    [_leftCapLayer  setDelegate:self];
    [_rightCapLayer setDelegate:self];
    [_rightBarLayer setDelegate:self];
    [_leftBarLayer  setDelegate:self];

    [_leftCapLayer  setNeedsDisplay];
    [_rightCapLayer setNeedsDisplay];
   
    [[self layer] addSublayer:_leftCapLayer];
    [[self layer] addSublayer:_leftBarLayer];
    [[self layer] addSublayer:_rightBarLayer];
    [[self layer] addSublayer:_rightCapLayer];

    _colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

    [self _updateColorComponents];
}


- (void) dealloc
{
    CGColorRelease(_leftColor);
    _leftColor = NULL;

    CGColorRelease(_rightColor);
    _rightColor = NULL;
    
    CGColorSpaceRelease(_colorSpace);
    _colorSpace = NULL;
}


- (void) layout
{
    NSRect bounds = [self bounds];
    CGFloat scale = [[self window] backingScaleFactor];

    CGFloat fillWidth = round(_percentage * bounds.size.width * scale) / scale;
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

    CGRect leftBarFrame, rightBarFrame;
    CGRectDivide(barFrame, &leftBarFrame, &rightBarFrame, mainFillWidth, CGRectMinXEdge);

    [_leftCapLayer  setFrame:CGRectMake(0, 0, capWidth, capWidth)];
    [_leftBarLayer  setFrame:leftBarFrame];
    [_rightBarLayer setFrame:rightBarFrame];
    [_rightCapLayer setFrame:CGRectMake(bounds.size.width - capWidth, 0, capWidth, capWidth)];

    // Opt-out of Auto Layout unless we are on macOS 10.11
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_12) {
        [super layout]; 
    }
}


- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self _inheritContentsScaleFromWindow:[self window]];
}


- (void) viewDidChangeEffectiveAppearance
{
    [self _updateColorComponents];
    
    
    [_leftCapLayer  setNeedsDisplay];
    [_rightCapLayer setNeedsDisplay];
}


- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [self _updateColorComponents];
}


#pragma mark - CALayer Delegate

- (BOOL) layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
    [self _inheritContentsScaleFromWindow:window];
    return (layer == _leftCapLayer || layer == _rightCapLayer);
}


- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    CGRect bounds = [layer bounds];
    
    if (_rounded) {
        CGRect circleRect = bounds;
        CGRect squareRect = circleRect;
        squareRect.size.width /= 2.0;
        squareRect.origin.x += (layer == _rightCapLayer) ? 0.0 : squareRect.size.width;

        CGContextBeginPath(context);
        CGContextAddEllipseInRect(context, circleRect);
        CGContextAddRect(context, squareRect);
        CGContextClip(context);    
    }
    
    CGFloat fillWidth = (layer == _rightCapLayer) ? _rightCapFillWidth : _leftCapFillWidth;
    
    CGRect leftRect, rightRect;
    CGRectDivide(bounds, &leftRect, &rightRect, fillWidth, CGRectMinXEdge);

    if (_leftColor) {
        CGContextSetFillColorWithColor(context, _leftColor);
        CGContextFillRect(context, leftRect);
    }

    if (_rightColor) {
        CGContextSetFillColorWithColor(context, _rightColor);
        CGContextFillRect(context, rightRect);
    }
}


#pragma mark - Private Methods

- (void) _inheritContentsScaleFromWindow:(NSWindow *)window
{
    CGFloat contentsScale = [window backingScaleFactor];

    if (contentsScale) {
        [_leftCapLayer  setContentsScale:contentsScale];
        [_rightCapLayer setContentsScale:contentsScale];
    }
}


- (void) _updateColorComponents
{
    PerformWithAppearance([self effectiveAppearance], ^{
        BOOL isMainWindow = [[self window] isMainWindow];

        NSColor *unfilledColor = [Theme colorNamed:@"MeterUnfilled"];
        NSColor *filledColor   = [Theme colorNamed:@"MeterFilled"];
        NSColor *redColor      = [Theme colorNamed:@"MeterRed"];
    
        if (isMainWindow) {
            filledColor = [Theme colorNamed:@"MeterFilledMain"];
        }

        if (IsAppearanceDarkAqua(self)) {
            CGFloat alpha = [[Theme colorNamed:@"MeterDarkAlpha"] alphaComponent];

            unfilledColor = GetColorWithMultipliedAlpha(unfilledColor, alpha);
            filledColor   = GetColorWithMultipliedAlpha(filledColor,   alpha);
        }

        NSColorSpace *sRGBColorSpace = [NSColorSpace sRGBColorSpace];
        unfilledColor = [unfilledColor colorUsingColorSpace:sRGBColorSpace];
        filledColor   = [filledColor   colorUsingColorSpace:sRGBColorSpace];
        redColor      = [redColor      colorUsingColorSpace:sRGBColorSpace];

        [unfilledColor getComponents:_unfilledComponents];
        [filledColor   getComponents:_filledComponents];
        [redColor      getComponents:_redComponents];
    });
    
    [self _updateColors];
}


- (void) _updateColors
{
    CGFloat leftComponents[4];
    sBlendComponents(_filledComponents, _redComponents, _redLevel, leftComponents);

    CGColorRelease(_leftColor);
    _leftColor = CGColorCreate(_colorSpace, leftComponents);

    CGColorRelease(_rightColor);
    _rightColor = CGColorCreate(_colorSpace, _unfilledComponents);

    [_leftBarLayer  setBackgroundColor:_leftColor];
    [_rightBarLayer setBackgroundColor:_rightColor];

    if (_leftCapFillWidth  > 0) [_leftCapLayer  setNeedsDisplay];
    if (_rightCapFillWidth > 0) [_rightCapLayer setNeedsDisplay];

    [_leftBarLayer  setBackgroundColor:_leftColor];
    [_rightBarLayer setBackgroundColor:_rightColor];
}


#pragma mark - Public Methods

- (void) setFilledColorWithRedLevel:(CGFloat)redLevel inContext:(CGContextRef)context
{
    CGFloat components[4];
    sBlendComponents(_filledComponents, _redComponents, redLevel, components);
    
    CGContextSetFillColorSpace(context, _colorSpace);
    CGContextSetFillColor(context, components);
}


- (void) setUnfilledColorWithRedLevel:(CGFloat)redLevel inContext:(CGContextRef)context
{
    CGFloat components[4];
    sBlendComponents(_unfilledComponents, _redComponents, redLevel, components);
    
    CGContextSetFillColorSpace(context, _colorSpace);
    CGContextSetFillColor(context, components);
}


#pragma mark - Accessors

- (void) setPercentage:(CGFloat)percentage
{
    if (_percentage != percentage) {
        _percentage = percentage;
        [self setNeedsLayout:YES];
    }
}


- (void) setRounded:(BOOL)rounded
{
    if (_rounded != rounded) {
        _rounded = rounded;
        [_leftBarLayer  setNeedsDisplay];
        [_rightBarLayer setNeedsDisplay];
    }
}


- (void) setRedLevel:(CGFloat)redLevel
{
    if (_redLevel != redLevel) {
        _redLevel = redLevel;
        [self _updateColors];
    }
}


@end
