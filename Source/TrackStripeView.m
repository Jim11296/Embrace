//  Copyright (c) 2014-2018 Ricci Adams. All rights reserved.


#import "TrackStripeView.h"


@implementation TrackStripeView

- (BOOL) isOpaque
{
    return YES;
}


- (void) drawRect:(NSRect)dirtyRect
{
    CGFloat scale  = [[self window] backingScaleFactor];
    CGRect  bounds = [self bounds];

    CGRect insetBounds = GetInsetBounds(self);

    if (_solidColor) {
        [_solidColor set];
        NSRectFill(bounds);
    }

    if (_dashColor) {
        [_dashColor set];

        NSRect dashRect = insetBounds;
        dashRect.size.width = bounds.size.height;

        while (dashRect.origin.x < insetBounds.size.width) {
            if (scale > 1) {
                [[NSBezierPath bezierPathWithOvalInRect:dashRect] fill];
            } else {
                NSRectFill(dashRect);
            }

            dashRect.origin.x += (dashRect.size.width * 2);
        }
    }
}


#pragma mark - Accessors

- (void) setSolidColor:(NSColor *)solidColor
{
    if (_solidColor != solidColor) {
        _solidColor = solidColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setDashColor:(NSColor *)dashColor
{
    if (_dashColor != dashColor) {
        _dashColor = dashColor;
        [self setNeedsDisplay:YES];
    }
}


@end
