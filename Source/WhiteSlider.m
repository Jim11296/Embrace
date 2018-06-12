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
    [super mouseDown:theEvent];
    [_dragDelegate whiteSliderDidEndDrag:self];
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
    
    NSColor *start = nil;
    NSColor *end   = nil;
    
    NSShadow *shadow1 = nil;
    NSShadow *shadow2 = nil;
        
    if (isMainWindow) {
        shadow1 = [Theme shadowNamed:@"KnobMain1"];
        shadow2 = [Theme shadowNamed:@"KnobMain2"];
    } else {
        shadow1 = [Theme shadowNamed:@"Knob"];
    }

    if ([self isHighlighted]) {
        start = [Theme colorNamed:@"KnobPressed1"];
        end   = [Theme colorNamed:@"KnobPressed2"];

    } else if (isMainWindow) {
        start = [Theme colorNamed:@"KnobMain1"];
        end   = [Theme colorNamed:@"KnobMain2"];

    } else {
        start = [Theme colorNamed:@"KnobResigned1"];
        end   = [Theme colorNamed:@"KnobResigned2"];
    }

    [shadow1 set];
    [start set];

    [[NSBezierPath bezierPathWithOvalInRect:knobRect] fill];
    
    if (shadow2 && start && end) {
        [shadow2 set];

        NSGradient *g = [[NSGradient alloc] initWithColors:@[ start, end ]];
        [g drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:knobRect] angle:90];
    }
}


- (void) drawBarInside:(NSRect)aRect flipped:(BOOL)flipped
{
    BOOL isMainWindow = [[[self controlView] window] isMainWindow];

    NSRect knobRect = [self knobRectFlipped:flipped];
    
    CGFloat midX = NSMidX(knobRect);
    
    NSRect leftRect, rightRect;
    NSDivideRect(_cellFrame, &leftRect, &rightRect, midX - _cellFrame.origin.x, NSMinXEdge);
    
    CGFloat radius = aRect.size.height > aRect.size.width ? aRect.size.width : aRect.size.height;
    radius /= 2;
    
    NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:aRect xRadius:radius yRadius:radius];
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext saveGraphicsState];
  
    NSColor *activeColor = [Theme colorNamed:isMainWindow ? @"MeterActiveMain" : @"MeterActive"];
    [activeColor set];

    [[NSBezierPath bezierPathWithRect:leftRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [[Theme colorNamed:@"MeterInactive"] set];
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
