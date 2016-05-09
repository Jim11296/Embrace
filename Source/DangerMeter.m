//
//  LevelMeter.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "DangerMeter.h"
#import "Player.h"


@implementation DangerMeter {
    NSTimer *_timer;
    double _dangerLevel;
    double _decayedLevel;
    double _overloadLevel;

    NSTimeInterval _dangerTime;
    NSTimeInterval _overloadTime;
}


- (void) drawRect:(NSRect)dirtyRect
{

    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];

    NSRect bounds = [self bounds];
    bounds = NSInsetRect(bounds, 1, 0);

    CGFloat barHeight = 4;

    CGFloat level = _decayedLevel;

    CGFloat colorLevel = (level * 2.0) - 1.0;
    if (colorLevel < 0) colorLevel = 0;

    CGFloat activeColor[] = {
        ((0x70 / 255.f) * (1.0 - colorLevel)) + colorLevel,
         (0x70 / 255.f) * (1.0 - colorLevel),
         (0x70 / 255.f) * (1.0 - colorLevel),
        1.0
    };
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextSetFillColorSpace(context, colorSpace);

    NSRect barRect = bounds;
    barRect.size.height = barHeight;
    barRect.origin.y = round((bounds.size.height - barRect.size.height) / 2);

    NSPoint boltPoint = NSMakePoint(1, barRect.origin.y + 7);
    
    barRect.size.width -= 6;
    barRect.origin.x += 6;
   
    NSRect overloadRect = barRect;
    
    barRect.size.width -= 6;
    
    overloadRect.size.width =  4;
    overloadRect.origin.x   = CGRectGetMaxX(barRect) + 2;

    // Draw bolt in activeColor
    {
        CGFloat x = boltPoint.x;
        CGFloat y = boltPoint.y;

        CGContextMoveToPoint(   context, x + 2, y     );
        CGContextAddLineToPoint(context, x + 2, y - 4 );
        CGContextAddLineToPoint(context, x + 4, y - 4 );
        CGContextAddLineToPoint(context, x + 2, y - 10);
        CGContextAddLineToPoint(context, x + 2, y - 6 );
        CGContextAddLineToPoint(context, x,     y - 6 );
        CGContextAddLineToPoint(context, x,     y - 6 );
        CGContextClosePath(context);

        if (_metering) {
            CGContextSetFillColor(context, activeColor);
        } else {
            [GetRGBColor(0x000000, 0.15) set];
        }

        CGContextFillPath(context);
    }

    // Draw bar
    {
        NSRect leftRect, rightRect;

        if (_metering) {
            CGFloat levelX = (level * barRect.size.width);
            if (levelX < 0) levelX = 0;

            NSDivideRect(barRect, &leftRect, &rightRect, levelX, NSMinXEdge);
        } else {
            rightRect = leftRect = barRect;
        }

        CGFloat radius = barRect.size.height > barRect.size.width ? barRect.size.width : barRect.size.height;
        radius /= 2;

        NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:barRect xRadius:radius yRadius:radius];

        [NSGraphicsContext saveGraphicsState];

        [GetRGBColor(0x000000, 0.15) set];
        [[NSBezierPath bezierPathWithRect:rightRect] addClip];
        [roundedPath fill];

        [NSGraphicsContext restoreGraphicsState];

        if (_metering) {
            [NSGraphicsContext saveGraphicsState];

            CGContextSetFillColor(context, activeColor);
            [[NSBezierPath bezierPathWithRect:leftRect] addClip];
            [roundedPath fill];

            [NSGraphicsContext restoreGraphicsState];
        }
    }
        
    // Draw overload dot
    {
        CGContextSaveGState(context);
    
        CGContextAddEllipseInRect(context, overloadRect);
        CGContextClip(context);

        [GetRGBColor(0x000000, 0.15) set];
        CGContextFillRect(context, overloadRect);
        
        if (_metering) {
            [GetRGBColor(0xff0000, _overloadLevel) set];
            CGContextFillRect(context, overloadRect);
        }

        CGContextRestoreGState(context);
    }

    CGColorSpaceRelease(colorSpace);
}


- (void) _recomputeDecayedLevel
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval dangerElapsed   = (now - _dangerTime)   - 1;
    NSTimeInterval overloadElapsed = (now - _overloadTime) - 5;

    double decayedLevel  = 0;
    double overloadLevel = 0;

    if (dangerElapsed < 0) {
        decayedLevel = _dangerLevel;
    } else {
        // We hold for 1 second, and then decay 0.2 per second
        double dangerDecay = dangerElapsed * 0.2;

        decayedLevel = (_dangerLevel - dangerDecay);
        if (decayedLevel < 0) decayedLevel = 0;
    }

    if (overloadElapsed < 0) {
        overloadLevel = 1;
    } else {
        overloadLevel = 1 - (overloadElapsed * 0.2);
    }
    
    if ((decayedLevel != _decayedLevel) || (overloadLevel != _overloadLevel)) {
        _decayedLevel  = decayedLevel;
        _overloadLevel = overloadLevel;
        [self setNeedsDisplay:YES];
    }
    
    if (_decayedLevel == 0 && _overloadLevel == 0) {
        [_timer invalidate];
        _timer = nil;

    } else if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:(1/30.0) target:self selector:@selector(_recomputeDecayedLevel) userInfo:nil repeats:YES];
    }
}


- (void) addDangerPeak:(Float32)dangerPeak lastOverloadTime:(NSTimeInterval)lastOverloadTime
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval dangerTime = now;
    
    double dangerLevel = dangerPeak;
    if (dangerLevel < 0) dangerLevel = 0;
    
    if ((now - lastOverloadTime) < 5) {
        dangerLevel = 1.0;
        dangerTime = lastOverloadTime;
    } 

    _overloadTime = lastOverloadTime;

    if (dangerLevel > _decayedLevel) {
        _dangerLevel = dangerLevel;
        _dangerTime  = dangerTime;

        [self _recomputeDecayedLevel];
    }
}


- (void) setMetering:(BOOL)metering
{
    if (_metering != metering) {
        _metering = metering;
        _decayedLevel = _dangerLevel = _dangerTime = 0;
        [self setNeedsDisplay:YES];
    }
}


@end
