//
//  SimpleProgressBar.m
//  Embrace
//
//  Created by Ricci Adams on 2017-06-25.
//  Copyright (c) 2017 Ricci Adams. All rights reserved.
//

#import "SimpleProgressBar.h"


@implementation SimpleProgressBar {
    CGColorRef _unfilledColor;
    CGColorRef _filledColor;
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


- (void) dealloc
{
    CGColorRelease(_unfilledColor);
    _unfilledColor = NULL;

    CGColorRelease(_filledColor);
    _filledColor = NULL;
}


- (void) _commonSimpleProgressBarInit
{
    _rounded = YES;
    [self _updateColors];
}


- (void) drawRect:(NSRect)dirtyRect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];

    CGRect bounds = [self bounds];
    CGFloat scale = [[self window] backingScaleFactor];

    if (_rounded) {
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:(bounds.size.height / 2) yRadius:(bounds.size.height / 2)];
        [path addClip];
    }
    
    CGFloat filledWidth = round(bounds.size.width * _percentage * scale) / scale;

    NSRect leftRect, rightRect;
    NSDivideRect(bounds, &leftRect, &rightRect, filledWidth, NSMinXEdge);

    if (_filledColor) {
        CGContextSetFillColorWithColor(context, _filledColor);
        CGContextFillRect(context, leftRect);
    }

    if (_unfilledColor) {
        CGContextSetFillColorWithColor(context, _unfilledColor);
        CGContextFillRect(context, rightRect);
    }
}


- (void) viewDidChangeEffectiveAppearance
{
    [self _updateColors];
}


- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [self _updateColors];
}


- (void) _updateColors
{
    BOOL isMainWindow = [[self window] isMainWindow];

    NSColor *unfilledColor = [Theme colorNamed:@"MeterUnfilled"];
    NSColor *filledColor   = [Theme colorNamed:@"MeterFilled"];
    
    if (isMainWindow) {
        filledColor = [Theme colorNamed:@"MeterFilledMain"];
    }

    if (IsAppearanceDarkAqua(self)) {
        CGFloat alpha = [[Theme colorNamed:@"MeterDarkAlpha"] alphaComponent];

        unfilledColor = GetColorWithMultipliedAlpha(unfilledColor, alpha);
        filledColor   = GetColorWithMultipliedAlpha(filledColor,   alpha);
    }
    
    CGColorRelease(_unfilledColor);
    _unfilledColor = CGColorRetain([unfilledColor CGColor]);

    CGColorRelease(_filledColor);
    _filledColor = CGColorRetain([filledColor CGColor]);

    [self setNeedsDisplay:YES];
}


#pragma mark - Accessors

- (void) setPercentage:(CGFloat)percentage
{
    if (_percentage != percentage) {
        _percentage = percentage;
        [self setNeedsDisplay:YES];
    }
}


- (void) setRounded:(BOOL)rounded
{
    if (_rounded != rounded) {
        _rounded = rounded;
        [self setNeedsDisplay:YES];
    }
}


@end

