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
    CGFloat scale  = [[self window] backingScaleFactor];
    CGRect  bounds = [self bounds];

    CGFloat onePixel = scale > 1 ? 0.5 : 1;

    CGRect insetBounds = bounds;

    // Dark Aqua adds a translucent bezel, pull in by one pixel to match
    if (@available(macOS 10.14, *)) {
        if (IsAppearanceDarkAqua(self) && (scale > 1)) {
            insetBounds = CGRectInset(bounds, onePixel, 0);
        }
    }

    if (_backgroundColor) {
        [_backgroundColor set];
        NSRectFill(bounds);
    }

    void (^fillRect)(NSRect, NSColor *, NSColor *) = ^(NSRect rect, NSColor *lineColor, NSColor *dashBackgroundColor) {
        if (dashBackgroundColor) {
            [dashBackgroundColor set];
            NSRectFill(rect);
        
            [lineColor set];

            NSRect dashRect = rect;
            dashRect.size.width = 2;

            for (CGFloat x = rect.origin.x; x < rect.size.width; ) {
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
        NSRect  rect   = bounds;
        CGFloat height = _topBorderHeight;

        if (height <= 0) {
            height = onePixel;
            rect = insetBounds;
        }

        rect.origin.y = bounds.size.height - height;
        rect.size.height = height;
        
        fillRect(rect, _topBorderColor, _topDashBackgroundColor);
    }
    
    if (_bottomBorderColor) {
        NSRect  rect   = bounds;
        CGFloat height = _bottomBorderHeight;

        if (height <= 0) {
            height = onePixel;
            rect = insetBounds;
        }

        rect.size.height = height;

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
