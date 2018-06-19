//
//  LevelMeter.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "DangerMeter.h"

static void sBlendComponents(CGFloat *a, CGFloat *b, CGFloat fraction, CGFloat *output)
{
    if      (fraction > 1) fraction = 1;
    else if (fraction < 0) fraction = 0;
    
    CGFloat iFraction = 1.0 - fraction;

    output[0] = (b[0] * fraction) + (a[0] * iFraction);
    output[1] = (b[1] * fraction) + (a[1] * iFraction);
    output[2] = (b[2] * fraction) + (a[2] * iFraction);
    output[3] = (b[3] * fraction) + (a[3] * iFraction);
}



@implementation DangerMeter {
    NSTimer *_timer;

    double _dangerLevel;
    double _decayedLevel;
    double _overloadLevel;
    double _redLevel;

    NSTimeInterval _dangerTime;
    NSTimeInterval _overloadTime;
   
    CGColorSpaceRef _colorSpace;
    CGFloat _unfilledComponents[4];
    CGFloat _filledComponents[4];
    CGFloat _redComponents[4];
}


- (instancetype) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self _commonDangerMeterInit];
    }
    
    return self;
}


- (instancetype) initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self _commonDangerMeterInit];
    }
    
    return self;
}


- (void) _commonDangerMeterInit
{
    _colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    [self _updateColors];
}


- (void) dealloc
{
    CGColorSpaceRelease(_colorSpace);
    _colorSpace = NULL;
}


- (void) viewDidChangeEffectiveAppearance
{
    [self _updateColors];
}


- (void) drawRect:(NSRect)dirtyRect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];

    NSRect bounds = [self bounds];
    CGFloat scale = [[self window] backingScaleFactor];

    NSRect barRect = CGRectMake(7, 4, bounds.size.width - 7, 4);
    NSRect overloadRect = barRect;
    
    barRect.size.width -= 6;
    overloadRect.size.width =  4;
    overloadRect.origin.x   = CGRectGetMaxX(barRect) + 2;

    CGFloat barComponents[4];
    sBlendComponents(_filledComponents, _redComponents, _redLevel, barComponents);

    CGFloat overloadComponents[4];
    sBlendComponents(_unfilledComponents, _redComponents, _overloadLevel, overloadComponents);

    CGContextSetFillColorSpace(context, _colorSpace);

    // Draw bolt
    {
        CGContextBeginPath(context);
        CGContextMoveToPoint(   context, 3, 11);
        CGContextAddLineToPoint(context, 3, 7);
        CGContextAddLineToPoint(context, 5, 7);
        CGContextAddLineToPoint(context, 3, 1);
        CGContextAddLineToPoint(context, 3, 5);
        CGContextAddLineToPoint(context, 1, 5);

        CGContextSetFillColor(context, (_metering ? barComponents : _unfilledComponents));
        CGContextFillPath(context);
    }
    
    // Draw overload dot
    {
        CGContextSetFillColor(context, overloadComponents);
        CGContextBeginPath(context);
        CGContextAddEllipseInRect(context, overloadRect);
        CGContextFillPath(context);
    }

    // Draw bar
    {
        NSBezierPath *barPath = [NSBezierPath bezierPathWithRoundedRect:barRect xRadius:2 yRadius:2];
        [barPath addClip];

        CGFloat filledWidth      = barRect.size.width * _decayedLevel;
        CGFloat filledWidthFloor = floor(filledWidth * scale) / scale;

        CGRect leftRect = barRect;
        leftRect.size.width = filledWidthFloor;

        CGContextSetFillColor(context, barComponents);
        CGContextFillRect(context, leftRect);

        CGRect middleRect = barRect;
        middleRect.origin.x = CGRectGetMaxX(leftRect);
        middleRect.size.width = 0;
    
        CGFloat middleAlpha = (filledWidth - filledWidthFloor) * scale;
        if (middleAlpha > (1 / 256.0)) {
            middleRect.size.width = 1.0 / scale;

            CGFloat components[4];
            sBlendComponents(_unfilledComponents, barComponents, middleAlpha, components);

            CGContextSetFillColor(context, components);
            NSRectFill(middleRect);
        }
        
        CGRect rightRect = barRect;
        rightRect.origin.x = CGRectGetMaxX(middleRect);
        rightRect.size.width = CGRectGetMaxX(barRect) - rightRect.origin.x;

        CGContextSetFillColor(context, _unfilledComponents);
        CGContextFillRect(context, rightRect);
    }
}


#pragma mark - Window Listener

- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [self _updateColors];
}


#pragma mark - Private Methods

- (void) _updateColors
{
    BOOL isMainWindow = [[self window] isMainWindow];

    NSColor *unfilledColor = [Theme colorNamed:@"MeterUnfilled"];
    NSColor *redColor      = [Theme colorNamed:@"MeterRed"];
    NSColor *filledColor   = nil;

    if (isMainWindow) {
        filledColor = [Theme colorNamed:@"MeterFilledMain"];
    } else {
        filledColor = [Theme colorNamed:@"MeterFilled"];
    }
    
    NSColorSpace *sRGBColorSpace = [NSColorSpace sRGBColorSpace];
    unfilledColor = [unfilledColor colorUsingColorSpace:sRGBColorSpace];
    redColor      = [redColor      colorUsingColorSpace:sRGBColorSpace];
    filledColor   = [filledColor   colorUsingColorSpace:sRGBColorSpace];
    
    if (IsAppearanceDarkAqua(self)) {
        CGFloat alpha = [[Theme colorNamed:@"MeterDarkAlpha"] alphaComponent];
        
        unfilledColor = GetColorWithMultipliedAlpha(unfilledColor, alpha);
        filledColor   = GetColorWithMultipliedAlpha(filledColor,   alpha);
    }
    
    [unfilledColor getComponents:_unfilledComponents];
    [filledColor   getComponents:_filledComponents];
    [redColor      getComponents:_redComponents];
    
    [self setNeedsDisplay:YES];
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
    
    if (overloadLevel < 0) overloadLevel = 0;
    
    CGFloat redLevel = (decayedLevel * 2.0) - 1.0;
    if (redLevel < 0) redLevel = 0;

    if (_decayedLevel  != decayedLevel  ||
        _overloadLevel != overloadLevel ||
        _redLevel      != redLevel
    ) {
        _decayedLevel  = decayedLevel;
        _overloadLevel = overloadLevel;
        _redLevel      = redLevel;

        [self setNeedsDisplay:YES];
    }
    
    if (_decayedLevel == 0 && _overloadLevel == 0) {
        [_timer invalidate];
        _timer = nil;

    } else if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:(1/30.0) target:self selector:@selector(_recomputeDecayedLevel) userInfo:nil repeats:YES];
    }
}


#pragma mark - Public Methods

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
        [self _recomputeDecayedLevel];
        
        [self setNeedsDisplay:YES];
    }
}


@end
