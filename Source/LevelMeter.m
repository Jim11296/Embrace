//
//  LevelMeter.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "LevelMeter.h"
#import "Track.h"


@implementation LevelMeter {
    NSGradient *_meterGradient;
    float _leftAveragePower;
    float _rightAveragePower;
    float _leftPeakPower;
    float _rightPeakPower;
    
}

- (void) drawRect:(NSRect)dirtyRect
{
    NSRect bounds = [self bounds];
    CGFloat barHeight = 3;

    bounds = NSInsetRect(bounds, 1, 0);

    void (^drawMeter)(NSRect, float, float) = ^(NSRect rect, float average, float peak) {
        CGFloat averageX = (60 + average) * (bounds.size.width / 60);
        CGFloat peakX    = (60 + peak)    * (bounds.size.width / 60);
        
        NSRect leftRect, rightRect;
        NSDivideRect(rect, &leftRect, &rightRect, averageX, NSMinXEdge);

        CGFloat radius = rect.size.height > rect.size.width ? rect.size.width : rect.size.height;
        radius /= 2;

        NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];

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

        rect.origin.x = peakX - 1;
        rect.size.width = 3;
        
        if (!_meterGradient) {
            _meterGradient = [[NSGradient alloc] initWithStartingColor:GetRGBColor(0xFF0000, 1.0) endingColor:GetRGBColor(0x000000, 1.0)];
        }
        
        if (peak > -12) {
            CGFloat greenness = peak / -12;
            [[_meterGradient interpolatedColorAtLocation:greenness] set];
            
        } else {
            [[_meterGradient interpolatedColorAtLocation:1.0] set];
        }
        
        [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
    };
	

    NSRect leftChannelBar = bounds;
    leftChannelBar.size.height = barHeight;
    leftChannelBar.origin.y = round((bounds.size.height - leftChannelBar.size.height) / 2);

    NSRect rightChannelBar = leftChannelBar;
    rightChannelBar.origin.y -= 4;

    drawMeter(leftChannelBar, _leftAveragePower, _leftPeakPower);
    drawMeter(rightChannelBar, _rightAveragePower, _rightPeakPower);
}


- (void) updateWithTrack:(Track *)track
{
    _leftAveragePower  = [track leftAveragePower];
    _rightAveragePower = [track rightAveragePower];
    _leftPeakPower     = [track leftPeakPower];
    _rightPeakPower    = [track rightPeakPower];
    
    [self setNeedsDisplay:YES];
}


@end
