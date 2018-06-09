//
//  StripeView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-07.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "StripeView.h"

@implementation StripeView

- (void) drawRect:(NSRect)dirtyRect
{
    CGFloat scale = [[self window] backingScaleFactor];
    NSRect bounds = [self bounds];

    CGRect leftRect   = bounds;
    CGRect bottomRect = bounds;

    CGFloat onePixel = scale > 1 ? 0.5 : 1;

    if (_fillColor) {
        [_fillColor set];
        NSRectFill(bounds);
    }
    
    if (_borderColor) {
        [_borderColor set];
        bottomRect.size.height = onePixel;
        NSRectFill(bottomRect);
        
        leftRect.size.width = onePixel;
        NSRectFill(leftRect);
    }
}


#pragma mark - Accessors

- (void) setBorderColor:(NSColor *)borderColor
{
    if (_borderColor != borderColor) {
        _borderColor = borderColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setFillColor:(NSColor *)fillColor
{
    if (_fillColor != fillColor) {
        _fillColor = fillColor;
        [self setNeedsDisplay:YES];
    }
}


@end
