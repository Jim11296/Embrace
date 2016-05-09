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
    CGFloat barHeight = 4;

    bounds = NSInsetRect(bounds, 1, 0);

    void (^drawLimiter)(NSRect) = ^(NSRect rect) {
        NSBezierPath *roundedPath = [NSBezierPath bezierPathWithOvalInRect:rect];
        
        if (_limiterActive) {
            [[NSColor redColor] set];
        } else {
            [GetRGBColor(0xc6c6c6, 1.0) set];
        }
        
        [roundedPath fill];
    };

    void (^drawMeter)(NSRect, float, float) = ^(NSRect rect, float average, float peak) {
        if (average > 0) average = 0;
        if (peak > 0)    peak = 0;
    
        CGFloat averageX = (60 + average) * ( rect.size.width      / 60);
        CGFloat peakX    = (60 + peak)    * ((rect.size.width - 2) / 60);
        
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

            [GetRGBColor(0x707070, 1.0) set];
            [[NSBezierPath bezierPathWithRect:leftRect] addClip];
            [roundedPath fill];

            [NSGraphicsContext restoreGraphicsState];
        }

        [GetRGBColor(0x0, 0.15) set];
        [[NSBezierPath bezierPathWithRect:rightRect] addClip];
        [roundedPath fill];
        
        [NSGraphicsContext restoreGraphicsState];
        
        if (_metering) {
            rect.origin.x = peakX - 2;
            rect.size.width = 4;
        
            if (peakX < 1) {
                [[NSColor clearColor] set];
            } else if (peakX < 10) {
                [GetRGBColor(0x0, (peakX / 10.0)) set];
            } else {
                [GetRGBColor(0x0, 1.0) set];
            }

            [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
        }
    };
	

    NSRect leftChannelBar = bounds;
    leftChannelBar.size.height = barHeight;
    leftChannelBar.origin.y = round((bounds.size.height - leftChannelBar.size.height) / 2);

    NSRect rightChannelBar = leftChannelBar;
    rightChannelBar.origin.y -= 6;

    NSRect leftLimiter = leftChannelBar;
    NSRect rightLimiter = rightChannelBar;
    
    leftChannelBar.size.width  -= 4;
    rightChannelBar.size.width -= 4;
    
    leftLimiter.size.width = rightLimiter.size.width = 4;
    leftLimiter.origin.x   = rightLimiter.origin.x = CGRectGetMaxX(leftChannelBar) + 1;

    if (_metering) {
        drawMeter(leftChannelBar,  _leftAveragePower,  _leftPeakPower);
        drawMeter(rightChannelBar, _rightAveragePower, _rightPeakPower);
        
        drawLimiter(leftLimiter);
        drawLimiter(rightLimiter);
        
    } else {
        drawMeter(leftChannelBar,  0, 0);
        drawMeter(rightChannelBar, 0, 0);

        drawLimiter(leftLimiter);
        drawLimiter(rightLimiter);
    }
}


- (void) setLeftAveragePower: (Float32) leftAveragePower
           rightAveragePower: (Float32) rightAveragePower
               leftPeakPower: (Float32) leftPeakPower
              rightPeakPower: (Float32) rightPeakPower
               limiterActive: (BOOL) limiterActive
{
    if (_leftAveragePower  != leftAveragePower  ||
        _rightAveragePower != rightAveragePower ||
        _leftPeakPower     != leftPeakPower     ||
        _rightPeakPower    != rightPeakPower    ||
        _limiterActive     != limiterActive)
    {
        _leftAveragePower  = leftAveragePower;
        _rightAveragePower = rightAveragePower;
        _leftPeakPower     = leftPeakPower;
        _rightPeakPower    = rightPeakPower;
        _limiterActive     = limiterActive;
        
        [self setNeedsDisplay:YES];
    }
}


- (void) setMetering:(BOOL)metering
{
    if (_metering != metering) {
        _metering = metering;
        _leftAveragePower = _rightAveragePower = _leftPeakPower = _rightPeakPower = -INFINITY;
        _limiterActive = NO;
        [self setNeedsDisplay:YES];
    }
}


@end
