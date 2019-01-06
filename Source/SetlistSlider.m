// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "SetlistSlider.h"


static NSShadow *sShadow(CGFloat alpha, CGFloat yOffset, CGFloat blurRadius)
{
    NSShadow *shadow = [[NSShadow alloc] init];
    
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:alpha]];
    [shadow setShadowOffset:NSMakeSize(0, -yOffset)];
    [shadow setShadowBlurRadius:blurRadius];

    return shadow;
}


@implementation SetlistSlider

+ (void) drawKnobWithView:(NSView *)view rect:(CGRect)rect highlighted:(BOOL)highlighted
{
    BOOL isMainWindow = [[view window] isMainWindow];
    
    NSColor *start = nil;
    NSColor *end   = nil;
    
    NSShadow *shadow1 = nil;
    NSShadow *shadow2 = nil;
    
    if (IsAppearanceDarkAqua(view)) {
        if (isMainWindow) {
            shadow1 = sShadow( 0.6, 1, 2 );
            shadow2 = sShadow( 0.8, 0, 1 );
        } else {
            shadow1 = sShadow( 0.9, 0, 1 );
        }

    } else {
        if (isMainWindow) {
            shadow1 = sShadow( 0.4, 1, 2 );
            shadow2 = sShadow( 0.6, 0, 1 );
        } else {
            shadow1 = sShadow( 0.45, 0, 1 );
        }

    }

    if (highlighted) {
        start = [NSColor colorNamed:@"KnobPressed1"];
        end   = [NSColor colorNamed:@"KnobPressed2"];

    } else if (isMainWindow) {
        start = [NSColor colorNamed:@"KnobMain1"];
        end   = [NSColor colorNamed:@"KnobMain2"];

    } else {
        start = [NSColor colorNamed:@"KnobResigned1"];
        end   = [NSColor colorNamed:@"KnobResigned2"];
    }

    [shadow1 set];
    [start set];

    [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
    
    if (shadow2 && start && end) {
        [shadow2 set];

        NSGradient *g = [[NSGradient alloc] initWithColors:@[ start, end ]];
        
        CGFloat angle = [view isFlipped] ? 90 : -90;
        [g drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:rect] angle:angle];
    }
}


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


- (NSRect) knobRectFlipped:(BOOL)flipped
{
    NSRect result = [super knobRectFlipped:flipped];

    result = NSInsetRect(result, 4, 4);

    return result;
}


- (void) drawKnob:(NSRect)knobRect
{
    [SetlistSlider drawKnobWithView:[self controlView] rect:knobRect highlighted:[self isHighlighted]];
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
    _cellFrame = cellFrame;
    
    NSInteger numberOfTickMarks = [self numberOfTickMarks];
    [self setNumberOfTickMarks:0];
    
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    BOOL inTransparencyLayer = NO;

    if (IsAppearanceDarkAqua(controlView)) {
        CGFloat alpha = [[NSColor colorNamed:@"MeterDarkAlpha"] alphaComponent];
        
        CGContextSetAlpha(context, alpha);
        CGContextBeginTransparencyLayer(context, NULL);
        inTransparencyLayer = YES;
    }
    
    [super drawWithFrame:cellFrame inView:controlView];
    
    if (inTransparencyLayer) {
        CGContextEndTransparencyLayer(context);
    }
    
    [self setNumberOfTickMarks:numberOfTickMarks];
}


@end
