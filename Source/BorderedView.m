//
//  BorderedView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-07.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "BorderedView.h"

@implementation BorderedView

- (void) drawRect:(NSRect)dirtyRect
{
    CGFloat scale = [[self window] backingScaleFactor];
    NSRect bounds = [self bounds];

    if (_backgroundColor) {
        [_backgroundColor set];
        NSRectFill(bounds);
    }

    if (_backgroundGradientTopColor || _backgroundGradientBottomColor) {
        NSGradient *g = [[NSGradient alloc] initWithStartingColor:_backgroundGradientTopColor endingColor:_backgroundGradientBottomColor];
        [g drawInRect:bounds angle:-90];
    }

    CGFloat onePixel = scale > 1 ? 0.5 : 1;

    void (^fillRect)(NSRect, NSColor *, NSColor *) = ^(NSRect rect, NSColor *lineColor, NSColor *dashBackgroundColor) {
        if (dashBackgroundColor) {
            [dashBackgroundColor set];
            NSRectFill(rect);
        
            [lineColor set];

            NSRect dashRect = rect;
            dashRect.size.width = 2;

            for (CGFloat x = 0; x < rect.size.width; ) {
                dashRect.origin.x = x;

                if (scale > 1) {
                    [[NSBezierPath bezierPathWithOvalInRect:dashRect] fill];
                } else {
                    NSRectFill(dashRect);
                }

                x += dashRect.size.width * 2;
            }

        } else {
            [lineColor set];
            NSRectFill(rect);
        }
    };
    
    if (_topBorderColor) {
        CGFloat height = _topBorderHeight;
        if (height <= 0) height = onePixel;
        
        NSRect rect = NSMakeRect(0, bounds.size.height - height, bounds.size.width, height);
        rect.size.width -= _topBorderLeftInset + _topBorderRightInset;
        rect.origin.x += _topBorderLeftInset;
        
        fillRect(rect, _topBorderColor, _topDashBackgroundColor);
    }
    
    if (_bottomBorderColor) {
        CGFloat height = _bottomBorderHeight;
        if (height <= 0) height = onePixel;

        NSRect rect = NSMakeRect(0, 0, bounds.size.width, height);
        rect.size.width -= _bottomBorderLeftInset + _bottomBorderRightInset;
        rect.origin.x += _bottomBorderLeftInset;

        fillRect(rect, _bottomBorderColor, _bottomDashBackgroundColor);
    }
}


#pragma mark - Accessors

- (void) setBackgroundColor:(NSColor *)backgroundColor
{
    if (_backgroundColor != backgroundColor) {
        _backgroundColor = backgroundColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setBackgroundGradientBottomColor:(NSColor *)backgroundGradientBottomColor
{
    if (_backgroundGradientBottomColor != backgroundGradientBottomColor) {
        _backgroundGradientBottomColor = backgroundGradientBottomColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setBackgroundGradientTopColor:(NSColor *)backgroundGradientTopColor
{
    if (_backgroundGradientTopColor != backgroundGradientTopColor) {
        _backgroundGradientTopColor = backgroundGradientTopColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setTopBorderColor:(NSColor *)topBorderColor
{
    if (_topBorderColor != topBorderColor) {
        _topBorderColor = topBorderColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setTopBorderHeight:(CGFloat)topBorderHeight
{
    if (_topBorderHeight != topBorderHeight) {
        _topBorderHeight = topBorderHeight;
        [self setNeedsDisplay:YES];
    }
}


- (void) setTopBorderLeftInset:(CGFloat)topBorderLeftInset
{
    if (_topBorderLeftInset != topBorderLeftInset) {
        _topBorderLeftInset = topBorderLeftInset;
        [self setNeedsDisplay:YES];
    }
}


- (void) setTopBorderRightInset:(CGFloat)topBorderRightInset
{
    if (_topBorderRightInset != topBorderRightInset) {
        _topBorderRightInset = topBorderRightInset;
        [self setNeedsDisplay:YES];
    }
}


- (void) setBottomBorderColor:(NSColor *)bottomBorderColor
{
    if (_bottomBorderColor != bottomBorderColor) {
        _bottomBorderColor = bottomBorderColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setBottomBorderHeight:(CGFloat)bottomBorderHeight
{
    if (_bottomBorderHeight != bottomBorderHeight) {
        _bottomBorderHeight = bottomBorderHeight;
        [self setNeedsDisplay:YES];
    }
}


- (void) setBottomBorderLeftInset:(CGFloat)bottomBorderLeftInset
{
    if (_bottomBorderLeftInset != bottomBorderLeftInset) {
        _bottomBorderLeftInset = bottomBorderLeftInset;
        [self setNeedsDisplay:YES];
    }
}


- (void) setBottomBorderRightInset:(CGFloat)bottomBorderRightInset
{
    if (_bottomBorderRightInset != bottomBorderRightInset) {
        _bottomBorderRightInset = bottomBorderRightInset;
        [self setNeedsDisplay:YES];
    }
}


- (void) setTopDashBackgroundColor:(NSColor *)topDashBackgroundColor
{
    if (_topDashBackgroundColor != topDashBackgroundColor) {
        _topDashBackgroundColor = topDashBackgroundColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setBottomDashBackgroundColor:(NSColor *)bottomDashBackgroundColor
{
    if (_bottomDashBackgroundColor != bottomDashBackgroundColor) {
        _bottomDashBackgroundColor = bottomDashBackgroundColor;
        [self setNeedsDisplay:YES];
    }
}


@end
