//  Copyright (c) 2014-2018 Ricci Adams. All rights reserved.


#import "HairlineView.h"


@implementation HairlineView


- (void) drawRect:(NSRect)dirtyRect
{
    if (!_borderColor) return;

    CGFloat scale    = [[self window] backingScaleFactor];
    CGFloat onePixel = scale > 1 ? 0.5 : 1;
    CGRect  rect     = GetInsetBounds(self);

    [_borderColor set];

    if (_layoutAttribute == NSLayoutAttributeTop) {
        rect.origin.y = rect.size.height - onePixel;
        NSRectFill(rect);

    } else if (_layoutAttribute == NSLayoutAttributeBottom) {
        rect.origin.y = 0;
        NSRectFill(rect);
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


- (void) setLayoutAttribute:(NSLayoutAttribute)layoutAttribute
{
    if (_layoutAttribute != layoutAttribute) {
        _layoutAttribute = layoutAttribute;
        [self setNeedsDisplay:YES];
    }
}


@end
