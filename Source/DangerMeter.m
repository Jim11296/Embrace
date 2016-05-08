//
//  LevelMeter.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "DangerMeter.h"
#import "Player.h"


static const CGFloat sOvalWidth   = 5;
static const CGFloat sOvalSpacing = 1;


@implementation DangerMeter {
    NSTimer *_timer;
    double _dangerLevel;
    double _decayedLevel;
    CFAbsoluteTime _dangerTime;
}

- (void) drawRect:(NSRect)dirtyRect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];

    if (!_metering) return;

    NSRect bounds = [self bounds];
    bounds = NSInsetRect(bounds, 1, 0);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextSetFillColorSpace(context, colorSpace);

    const CGFloat totalWidth = (sOvalWidth * 5) + (sOvalSpacing * 4);

    NSRect firstRect = NSMakeRect(
        bounds.origin.x + (bounds.size.width - totalWidth),
        round((bounds.size.height - sOvalWidth) / 2),
        sOvalWidth,
        sOvalWidth
    );

    CGFloat dangerLevel = _decayedLevel;

    void (^drawOval)(CGFloat, NSInteger) = ^(CGFloat x, NSInteger ovalIndex) {
        NSRect rect = firstRect;
        rect.origin.x += x;

        CGFloat ovalLevel = (dangerLevel * 5) - ovalIndex;
        if (ovalLevel < 0) ovalLevel = 0;
        if (ovalLevel > 1) ovalLevel = 1;

        CGFloat inactiveColor[] = { (0xc6 / 255.f), (0xc6 / 255.f), (0xc6 / 255.f), 1.0 };
        CGFloat activeColor[]   = { (0x70 / 255.f), (0x70 / 255.f), (0x70 / 255.f), 1.0 };

        const CGFloat red[]  = { 1, 0, 0, 1 };

        CGContextSaveGState(context);

        CGContextAddEllipseInRect(context, rect);
        CGContextClip(context);
        
        CGContextAddRect(context, rect);
        CGContextAddEllipseInRect(context, CGRectInset(rect, 1, 1));
        CGContextSetFillColor(context, inactiveColor);
        CGContextEOFillPath(context);

        CGContextSetAlpha(context, ovalLevel);
        CGContextSetFillColor(context, activeColor);
        CGContextFillRect(context, rect);

        CGContextSetAlpha(context, dangerLevel * ovalLevel);
        CGContextSetFillColor(context, red);
        CGContextFillRect(context, rect);

        CGContextRestoreGState(context);
    };
    
    CGFloat x = 0;
    drawOval(x, 0);

    x += (sOvalWidth + sOvalSpacing);
    drawOval(x, 1);

    x += (sOvalWidth + sOvalSpacing);
    drawOval(x, 2);

    x += (sOvalWidth + sOvalSpacing);
    drawOval(x, 3);

    x += (sOvalWidth + sOvalSpacing);
    drawOval(x, 4);
}


- (void) _recomputeDecayedLevel
{
    CFAbsoluteTime now     = CFAbsoluteTimeGetCurrent();

    CFAbsoluteTime holdTime = ceil(_dangerLevel * 5);
    CFAbsoluteTime elapsed = (now - _dangerTime) - holdTime;

    double decayedLevel = 0;

    if (elapsed < 0) {
        decayedLevel = _dangerLevel;
    } else {
        // We hold for 1 second, and then decay 0.2 (1 oval) per second
        double dangerDecay = elapsed * 0.2;

        decayedLevel = (_dangerLevel - dangerDecay);
        if (decayedLevel < 0) decayedLevel = 0;
    }
    
    
    if (decayedLevel != _decayedLevel) {
        _decayedLevel = decayedLevel;
        [self setNeedsDisplay:YES];
    }
    
    if (_decayedLevel == 0) {
        [_timer invalidate];
        _timer = nil;

    } else if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:(1/30.0) target:self selector:@selector(_recomputeDecayedLevel) userInfo:nil repeats:YES];
    }
}


- (void) addDangerPeak:(Float32)dangerPeak lastOverloadTime:(NSTimeInterval)lastOverloadTime
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime dangerTime = now;
    
    double dangerLevel = dangerPeak - 0.2;
    if (dangerLevel < 0) dangerLevel = 0;
    
    if ((lastOverloadTime - 5) > now) {
        dangerLevel = 1.0;
        dangerTime = lastOverloadTime;
    } 

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
