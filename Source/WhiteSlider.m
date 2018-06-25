// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "WhiteSlider.h"


static NSShadow *sShadow(CGFloat alpha, CGFloat yOffset, CGFloat blurRadius)
{
    NSShadow *shadow = [[NSShadow alloc] init];
    
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:alpha]];
    [shadow setShadowOffset:NSMakeSize(0, -yOffset)];
    [shadow setShadowBlurRadius:blurRadius];

    return shadow;
}


@implementation WhiteSlider

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

    [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
    
    if (shadow2 && start && end) {
        [shadow2 set];

        NSGradient *g = [[NSGradient alloc] initWithColors:@[ start, end ]];
        [g drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:rect] angle:90];
    }
}


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
    [WhiteSlider drawKnobWithView:[self controlView] rect:knobRect highlighted:[self isHighlighted]];
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
  
    NSColor *activeColor = [Theme colorNamed:isMainWindow ? @"MeterFilledMain" : @"MeterFilled"];
    [activeColor set];

    [[NSBezierPath bezierPathWithRect:leftRect] addClip];
    [roundedPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
    
    [[Theme colorNamed:@"MeterUnfilled"] set];
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
        CGFloat alpha = [[Theme colorNamed:@"MeterDarkAlpha"] alphaComponent];
        
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
