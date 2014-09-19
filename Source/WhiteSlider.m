//
//  WhiteSlider.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WhiteSlider.h"

static BOOL sNeedsMountainLionWorkaround()
{
    return floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_8;
}


@implementation WhiteSlider


- (void) mouseDown:(NSEvent *)theEvent
{
    [_dragDelegate whiteSliderDidStartDrag:self];
    
    _doubleValueBeforeDrag = [self doubleValue];
    [super mouseDown:theEvent];
    
    [_dragDelegate whiteSliderDidEndDrag:self];
}


- (void) setNeedsDisplayInRect:(NSRect)invalidRect
{
    if (sNeedsMountainLionWorkaround()) {
        [super setNeedsDisplayInRect:[self bounds]];
    } else {
        [super setNeedsDisplayInRect:invalidRect];
    }
}


@end


@implementation WhiteSliderCell {
    NSRect _cellFrame;
}

- (NSRect) knobRectFlipped:(BOOL)flipped
{
    NSRect result = [super knobRectFlipped:flipped];

    result = NSInsetRect(result, 4, 4);

    if (sNeedsMountainLionWorkaround()) {
        result.origin.y = 3;
    }

    return result;
}


- (void) drawKnob:(NSRect)knobRect
{
    [[NSColor whiteColor] set];
    
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.20]];
    [shadow setShadowOffset:NSMakeSize(0, -1)];
    [shadow setShadowBlurRadius:2];
    [shadow set];
    
    [[NSBezierPath bezierPathWithOvalInRect:knobRect] fill];
    
    NSShadow *shadow2 = [[NSShadow alloc] init];
    [shadow2 setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.65]];
    [shadow2 setShadowOffset:NSMakeSize(0, 0)];
    [shadow2 setShadowBlurRadius:1];
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
    [NSGraphicsContext saveGraphicsState];
    
    [GetRGBColor(0x686868, 1.0) set];
    [[NSBezierPath bezierPathWithRect:leftRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [GetRGBColor(0xababab, 1.0) set];
    [[NSBezierPath bezierPathWithRect:rightRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];

/*
    NSBezierPath *fullPath = [NSBezierPath bezierPathWithRect:CGRectInset(aRect, -4, -4)];
    
    [fullPath appendBezierPath:[NSBezierPath bezierPathWithRect:aRect]];
    [fullPath setWindingRule:NSEvenOddWindingRule];
    
    [roundedPath addClip];

    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.15]];
    [shadow setShadowOffset:NSMakeSize(0, -0.5)];
    [shadow setShadowBlurRadius:1];
    [shadow set];

    [fullPath fill];
*/

    [NSGraphicsContext restoreGraphicsState];
}


- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    _cellFrame = cellFrame;
    
    NSInteger numberOfTickMarks = [self numberOfTickMarks];
    [self setNumberOfTickMarks:0];
    
    if (sNeedsMountainLionWorkaround()) {
        [super drawWithFrame:cellFrame inView:controlView];
        
        NSShadow *noShadow = [[NSShadow alloc] init];
        [noShadow set];
        
        NSRect knobRect = [self knobRectFlipped:[controlView isFlipped]];
        
        cellFrame = [self drawingRectForBounds: cellFrame];
        [[NSColor clearColor] set];
        NSRectFill(cellFrame);
        
        NSRect trackRect = NSInsetRect(cellFrame, 3, 0);
        trackRect.origin.y = 8;
        trackRect.size.height = 5;

        if (numberOfTickMarks > 0) {
            trackRect.origin.y += 2;
            knobRect.origin.y  += 2;
        }
        
        [self drawBarInside:trackRect flipped:[controlView isFlipped]];
        [self drawKnob:knobRect];
        
    } else {
        [super drawWithFrame:cellFrame inView:controlView];
    }
    
    [self setNumberOfTickMarks:numberOfTickMarks];
}


@end
