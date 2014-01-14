//
//  PlayBar.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "PlayBar.h"

@implementation PlayBar

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    NSRect bounds = [self bounds];

    CGFloat barHeight = 5;

    NSRect barRect = NSInsetRect(bounds, 1, 0);
    barRect.size.height = barHeight;
    barRect.origin.y = round((bounds.size.height - barRect.size.height) / 2);

    CGFloat midX = bounds.size.width * _percentage;
    
    NSRect leftRect, rightRect;
    NSDivideRect(bounds, &leftRect, &rightRect, midX - bounds.origin.x, NSMinXEdge);

    CGFloat radius = barRect.size.height > barRect.size.width ? barRect.size.width : barRect.size.height;
    radius /= 2;

    NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:barRect xRadius:radius yRadius:radius];

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


- (void) setPercentage:(float)percentage
{
    if (_percentage != percentage) {
        if (isnan(percentage)) percentage = 0;
        _percentage = percentage;
        [self setNeedsDisplay:YES];
    }
}


@end
