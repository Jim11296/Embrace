//
//  WhiteSlider.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WhiteSlider.h"


@implementation WhiteSlider


- (void) mouseDown:(NSEvent *)theEvent
{
    [_dragDelegate whiteSliderDidStartDrag:self];
    
    _doubleValueBeforeDrag = [self doubleValue];
    [super mouseDown:theEvent];
    
    [_dragDelegate whiteSliderDidEndDrag:self];
}


- (void) windowDidUpdateMain:(NSWindow *)window
{
    [self setNeedsDisplay:YES];
}


@end


@implementation WhiteSliderCell {
    NSRect _cellFrame;
}

- (NSRect) knobRectFlipped:(BOOL)flipped
{
    NSRect result = [super knobRectFlipped:flipped];

    result = NSInsetRect(result, 4, 4);

    return result;
}


- (void) drawKnob:(NSRect)knobRect
{
    BOOL isMainWindow = [[[self controlView] window] isMainWindow];
    
    NSShadow *shadow = [[NSShadow alloc] init];
    
    if (isMainWindow) {
        [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.2]];
        [shadow setShadowOffset:NSMakeSize(0, -1)];
        [shadow setShadowBlurRadius:2];
    } else {
        [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.45]];
        [shadow setShadowOffset:NSMakeSize(0, 0)];
        [shadow setShadowBlurRadius:1];
    }

    [shadow set];
    
    [[NSColor whiteColor] set];
    [[NSBezierPath bezierPathWithOvalInRect:knobRect] fill];
    
    if (isMainWindow) {
        NSShadow *shadow2 = [[NSShadow alloc] init];
        [shadow2 setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.65]];
        [shadow2 setShadowOffset:NSMakeSize(0, 0)];
        [shadow2 setShadowBlurRadius:1];
        [shadow2 set];

        CGFloat startColor = (0xf0 / 255.0);
        CGFloat endColor   = (0xff / 255.0);

        if ([self isHighlighted]) {
            startColor = (0xe0 / 255.0);
            endColor   = (0xf0 / 255.0);
        }

        NSGradient *g = [[NSGradient alloc] initWithColors:@[
            [NSColor colorWithCalibratedWhite:startColor alpha:1.0],
            [NSColor colorWithCalibratedWhite:endColor alpha:1.0],
        ]];

        [g drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:knobRect] angle:-90];
    }
}


- (void) drawBarInside:(NSRect)aRect flipped:(BOOL)flipped
{
    NSRect knobRect = [self knobRectFlipped:flipped];
    
    CGFloat midX = NSMidX(knobRect);
    
    NSRect leftRect, rightRect;
    NSDivideRect(_cellFrame, &leftRect, &rightRect, midX - _cellFrame.origin.x, NSMinXEdge);
    
    CGFloat radius = aRect.size.height > aRect.size.width ? aRect.size.width : aRect.size.height;
    radius /= 2;
    
    NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:aRect xRadius:radius yRadius:radius];
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext saveGraphicsState];
    
    [GetRGBColor(0x686868, 1.0) set];
    [[NSBezierPath bezierPathWithRect:leftRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [GetRGBColor(0xababab, 1.0) set];
    [[NSBezierPath bezierPathWithRect:rightRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
}


- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    _cellFrame = cellFrame;
    
    NSInteger numberOfTickMarks = [self numberOfTickMarks];
    [self setNumberOfTickMarks:0];
    
    [super drawWithFrame:cellFrame inView:controlView];
    
    [self setNumberOfTickMarks:numberOfTickMarks];
}


@end
