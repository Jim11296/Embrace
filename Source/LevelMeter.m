//
//  LevelMeter.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "LevelMeter.h"
#import "Player.h"


@implementation LevelMeter

- (void) drawRect:(NSRect)dirtyRect
{
    NSRect bounds = [self bounds];
    CGFloat barHeight = 3;

    bounds = NSInsetRect(bounds, 1, 0);

    void (^drawMeter)(NSRect, float, float) = ^(NSRect rect, float average, float peak) {
        BOOL didClip = NO;

        if (average > 0) {
            didClip = YES;
            average = 0;
        }
        
        if (peak > 0) {
            didClip = YES;
            peak = 0;
        }
    
        CGFloat averageX = (60 + average) * ( bounds.size.width      / 60);
        CGFloat peakX    = (60 + peak)    * ((bounds.size.width - 2) / 60);
        
        if (averageX < 0) averageX = 0;
        if (peakX    < 0) peakX = 0;
        
        peakX += 1;
        
        NSRect leftRect, rightRect;
        if (_metering) {
            NSDivideRect(rect, &leftRect, &rightRect, averageX, NSMinXEdge);
        } else {
            rightRect = leftRect = rect;
        }

        CGFloat radius = rect.size.height > rect.size.width ? rect.size.width : rect.size.height;
        radius /= 2;

        NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];

        [NSGraphicsContext saveGraphicsState];

        if (_metering) {
            [NSGraphicsContext saveGraphicsState];

            [GetRGBColor(0x0, 0.66) set];
            [[NSBezierPath bezierPathWithRect:leftRect] addClip];
            [roundedPath fill];

            [NSGraphicsContext restoreGraphicsState];
        }

        [GetRGBColor(0x0, 0.15) set];
        [[NSBezierPath bezierPathWithRect:rightRect] addClip];
        [roundedPath fill];
        
        [NSGraphicsContext restoreGraphicsState];
        
        if (_metering) {
            rect.origin.x = peakX - 1;
            rect.size.width = 3;
        
            if (didClip) {
                [[NSColor redColor] set];
            } else {
                [[NSColor blackColor] set];
            }

            [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
        }
    };
	

    NSRect leftChannelBar = bounds;
    leftChannelBar.size.height = barHeight;
    leftChannelBar.origin.y = round((bounds.size.height - leftChannelBar.size.height) / 2);

    NSRect rightChannelBar = leftChannelBar;
    rightChannelBar.origin.y -= 4;

    if (_metering) {
        drawMeter(leftChannelBar,  _leftAveragePower, _leftPeakPower);
        drawMeter(rightChannelBar, _rightAveragePower, _rightPeakPower);
    } else {
        drawMeter(leftChannelBar,  0, 0);
        drawMeter(rightChannelBar, 0, 0);
    }
}


- (void) setLeftAveragePower: (Float32) leftAveragePower
           rightAveragePower: (Float32) rightAveragePower
               leftPeakPower: (Float32) leftPeakPower
              rightPeakPower: (Float32) rightPeakPower
{
    if (_leftAveragePower  != leftAveragePower  ||
        _rightAveragePower != rightAveragePower ||
        _leftPeakPower     != leftPeakPower     ||
        _rightPeakPower    != rightPeakPower)
    {
        _leftAveragePower  = leftAveragePower;
        _rightAveragePower = rightAveragePower;
        _leftPeakPower     = leftPeakPower;
        _rightPeakPower    = rightPeakPower;
        
        [self setNeedsDisplay:YES];
    }
}


- (void) setMetering:(BOOL)metering
{
    if (_metering != metering) {
        _metering = metering;
        [self setNeedsDisplay:YES];
    }
}


@end
