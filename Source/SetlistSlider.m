// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "SetlistSlider.h"



@implementation SetlistSlider

- (void) mouseDown:(NSEvent *)theEvent
{
    [_dragDelegate sliderDidStartDrag:self];
    [super mouseDown:theEvent];
    [_dragDelegate sliderDidEndDrag:self];
}


- (void) windowDidUpdateMain:(NSWindow *)window
{
    [self setNeedsDisplay:YES];
}


- (NSRect) knobRect
{
    return [[self cell] knobRectFlipped:NO];
}


- (BOOL) acceptsFirstMouse:(nullable NSEvent *)event
{
    return NO;
}


@end


@implementation SetlistSliderCell {
    NSRect _cellFrame;
}


//
//- (void) drawKnob:(NSRect)inKnobRect
//{
//    CGFloat knobThickness = [self knobThickness];
//
//    CGRect outKnobRect = CGRectMake(
//        inKnobRect.origin.x + ((inKnobRect.size.width  - knobThickness) / 2.0),
//        inKnobRect.origin.y + ((inKnobRect.size.height - knobThickness) / 2.0),
//        knobThickness,
//        knobThickness
//    );
//    
////    outKnobRect.origin.y -= 2.0;
//
//    [SetlistSlider drawKnobWithView:[self controlView] rect:outKnobRect highlighted:[self isHighlighted]];
//}
//*/

- (void) drawBarInside:(NSRect)aRect flipped:(BOOL)flipped
{
    BOOL isMainWindow = [[[self controlView] window] isMainWindow];
//
//    aRect = NSInsetRect(aRect, 4, 0);
//    aRect.origin.y += 2.0;

    NSRect knobRect = [self knobRectFlipped:flipped];
        
    CGFloat midX = NSMidX(knobRect);
    
    NSRect leftRect, rightRect;
    NSDivideRect(aRect, &leftRect, &rightRect, midX - aRect.origin.x, NSMinXEdge);
    
    CGFloat radius = aRect.size.height > aRect.size.width ? aRect.size.width : aRect.size.height;
    radius /= 2;
    
    NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:aRect xRadius:radius yRadius:radius];
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext saveGraphicsState];
  
    NSColor *activeColor = [NSColor colorNamed:isMainWindow ? @"MeterFilledMain" : @"MeterFilled"];
    [activeColor set];

    [[NSBezierPath bezierPathWithRect:leftRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [[NSColor colorNamed:@"MeterUnfilled"] set];
    [[NSBezierPath bezierPathWithRect:rightRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
}


- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSInteger numberOfTickMarks = [self numberOfTickMarks];
    [self setNumberOfTickMarks:0];

    [super drawWithFrame:cellFrame inView:controlView];
        
    [self setNumberOfTickMarks:numberOfTickMarks];
}




@end
