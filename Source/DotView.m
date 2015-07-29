//
//  StripeView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-07.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "DotView.h"

@implementation DotView

- (void) drawRect:(NSRect)dirtyRect
{
    CGFloat scale = [[self window] backingScaleFactor];

    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    CGRect rect = [self bounds];

    if (scale > 1) {
        rect.size.width  -= 0.5;
        rect.size.height -= 0.5;
    }
    
    [_borderColor set];
    CGContextFillEllipseInRect(context, rect);

    [_fillColor set];
    CGContextFillEllipseInRect(context, CGRectInset(rect, 1, 1));

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
