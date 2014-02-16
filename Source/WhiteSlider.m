//
//  WhiteSlider.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WhiteSlider.h"

@implementation WhiteSlider {

}

- (void) mouseDown:(NSEvent *)theEvent
{
    [_dragDelegate whiteSliderDidStartDrag:self];

    _doubleValueBeforeDrag = [self doubleValue];
    [super mouseDown:theEvent];

    [_dragDelegate whiteSliderDidEndDrag:self];
}



@end


@implementation WhiteSliderCell {
    NSRect _cellFrame;
}

- (NSRect) knobRectFlipped:(BOOL)flipped
{
    NSRect result = [super knobRectFlipped:flipped];
    result = NSInsetRect(result, 3, 3);
    return result;
}


- (void) drawKnob:(NSRect)knobRect
{
    [[NSColor whiteColor] set];
    
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.25]];
    [shadow setShadowOffset:NSMakeSize(0, -1)];
    [shadow setShadowBlurRadius:2];
    [shadow set];

    [[NSBezierPath bezierPathWithOvalInRect:knobRect] fill];

    NSShadow *shadow2 = [[NSShadow alloc] init];
    [shadow2 setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.25]];
    [shadow2 setShadowOffset:NSMakeSize(0, 0)];
    [shadow2 setShadowBlurRadius:2];
    [shadow2 set];

    [[NSBezierPath bezierPathWithOvalInRect:knobRect] fill];
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

    [GetRGBColor(0x0, 0.66) set];
    [[NSBezierPath bezierPathWithRect:leftRect] addClip];
    [roundedPath fill];

    [NSGraphicsContext restoreGraphicsState];
    
    [GetRGBColor(0x0, 0.15) set];
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