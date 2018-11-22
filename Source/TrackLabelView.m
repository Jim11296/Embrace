// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "TrackLabelView.h"


static NSColor *sGetBorderColorForTrackLabel(TrackLabel trackLabel)
{
    NSColorName name = nil;

    if      (trackLabel == TrackLabelRed)    name = @"TrackLabelRedBorder";
    else if (trackLabel == TrackLabelOrange) name = @"TrackLabelOrangeBorder";
    else if (trackLabel == TrackLabelYellow) name = @"TrackLabelYellowBorder";
    else if (trackLabel == TrackLabelGreen)  name = @"TrackLabelGreenBorder";
    else if (trackLabel == TrackLabelBlue)   name = @"TrackLabelBlueBorder";
    else if (trackLabel == TrackLabelPurple) name = @"TrackLabelPurpleBorder";
    
    return name ? [Theme colorNamed:name] : nil;
}


static NSColor *sGetFillColorForTrackLabel(TrackLabel trackLabel)
{
    NSColorName name = nil;

    if      (trackLabel == TrackLabelRed)    name = @"TrackLabelRedFill";
    else if (trackLabel == TrackLabelOrange) name = @"TrackLabelOrangeFill";
    else if (trackLabel == TrackLabelYellow) name = @"TrackLabelYellowFill";
    else if (trackLabel == TrackLabelGreen)  name = @"TrackLabelGreenFill";
    else if (trackLabel == TrackLabelBlue)   name = @"TrackLabelBlueFill";
    else if (trackLabel == TrackLabelPurple) name = @"TrackLabelPurpleFill";
    
    return name ? [Theme colorNamed:name] : nil;
}


@implementation TrackLabelView

- (void) drawRect:(NSRect)dirtyRect
{
    if (_label == TrackLabelNone) return;

    NSColor *borderColor = sGetBorderColorForTrackLabel(_label);
    NSColor *fillColor   = sGetFillColorForTrackLabel(_label);
   
    CGFloat scale = [[self window] backingScaleFactor];

    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    CGRect rect = [self bounds];

    if (_style == TrackLabelViewDot) {
        if (scale > 1) {
            rect.size.width  -= 0.5;
            rect.size.height -= 0.5;
        }
        
        [(_needsWhiteBorder ? [NSColor whiteColor] : borderColor) set];
        CGContextFillEllipseInRect(context, rect);

        [fillColor set];
        CGContextFillEllipseInRect(context, CGRectInset(rect, 1, 1));

    } else {
        CGRect leftRect   = rect;
        CGRect bottomRect = rect;

        CGFloat onePixel = scale > 1 ? 0.5 : 1;

        if (fillColor) {
            [fillColor set];
            NSRectFill(rect);
        }
        
        if (borderColor) {
            [borderColor set];
            bottomRect.size.height = onePixel;
            NSRectFill(bottomRect);
            
            leftRect.size.width = onePixel;
            NSRectFill(leftRect);
        }
    }
}


#pragma mark - Accessors

- (void) setStyle:(TrackLabelViewStyle)style
{
    if (_style != style) {
        _style = style;
        [self setNeedsDisplay:YES];
    }
}


- (void) setLabel:(TrackLabel)label
{
    if (_label != label) {
        _label = label;
        [self setNeedsDisplay:YES];
    }
}


- (void) setNeedsWhiteBorder:(BOOL)needsWhiteBorder
{
    if (_needsWhiteBorder != needsWhiteBorder) {
        _needsWhiteBorder = needsWhiteBorder;
        [self setNeedsDisplay:YES];
    }
}


@end
