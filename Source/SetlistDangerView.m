// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import "SetlistDangerView.h"
#import "SetlistProgressBar.h"

@interface SetlistDangerView () <CALayerDelegate>
@end


@interface SetlistDangerMeterLight : NSView
@property (nonatomic, weak) SetlistProgressBar *linkedProgressBar;

@property (nonatomic, getter=isOn)   BOOL on;
@property (nonatomic, getter=isBolt) BOOL bolt;
@end

@implementation SetlistDangerMeterLight
@end

@implementation SetlistDangerView {
    CALayer *_boltLight;
    CALayer *_overloadLight;

    SetlistProgressBar *_progressBar;

    NSTimer *_timer;

    double         _dangerLevel;
    NSTimeInterval _dangerTime;
    NSTimeInterval _overloadTime;

    // Updated in _recomputeDecayedLevel
    double _decayedLevel;
    double _overloadLevel;
    double _redLevel;
   
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
    [self setWantsLayer:YES];
    [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];

    _progressBar = [[SetlistProgressBar alloc] initWithFrame:CGRectZero];

    _boltLight = [CALayer layer];
    [_boltLight setNeedsDisplay];
    [_boltLight setDelegate:self];

    _overloadLight = [CALayer layer];
    [_overloadLight setNeedsDisplay];
    [_overloadLight setDelegate:self];

    [[self layer] addSublayer:_boltLight];
    [[self layer] addSublayer:_overloadLight];
    
    [self addSubview:_progressBar];
}


- (BOOL) wantsUpdateLayer
{
    return YES;
}


- (void) updateLayer
{
    // No-op
}


- (void) layout
{
    CGRect bounds = [self bounds];

    CGRect boltRect = CGRectMake(1, 1, 4, 10);

    CGRect barRect = CGRectMake(7, 4, bounds.size.width - 7, 4);
    CGRect overloadRect = barRect;
    
    barRect.size.width -= 6;
    overloadRect.size.width =  4;
    overloadRect.origin.x   = CGRectGetMaxX(barRect) + 2;

    [_boltLight setFrame:boltRect];
    [_progressBar setFrame:barRect];
    [_overloadLight setFrame:overloadRect];
}


- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    if (layer == _boltLight) {
        CGContextBeginPath(context);
        CGContextMoveToPoint(   context, 2, 10);
        CGContextAddLineToPoint(context, 2, 6);
        CGContextAddLineToPoint(context, 4, 6);
        CGContextAddLineToPoint(context, 2, 0);
        CGContextAddLineToPoint(context, 2, 4);
        CGContextAddLineToPoint(context, 0, 4);

        if (_metering) {
            [_progressBar setFilledColorWithRedLevel:_redLevel inContext:context];
        } else {
            [_progressBar setUnfilledColorWithRedLevel:0 inContext:context];
        }

        CGContextFillPath(context);

    } else if (layer == _overloadLight) {
        [_progressBar setUnfilledColorWithRedLevel:_overloadLevel inContext:context];
        CGContextFillEllipseInRect(context, [layer bounds]);
    }
}



- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self _inheritContentsScaleFromWindow:[self window]];
}


- (BOOL) layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
    [self _inheritContentsScaleFromWindow:window];
    return (layer == _boltLight || layer == _overloadLight);
}


- (void) _inheritContentsScaleFromWindow:(NSWindow *)window
{
    CGFloat contentsScale = [window backingScaleFactor];

    if (contentsScale) {
        [_boltLight setContentsScale:contentsScale];
        [_overloadLight setContentsScale:contentsScale];
    }
}


/*
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
*/


#pragma mark - Window Listener

- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [_progressBar windowDidUpdateMain:window];

    [_boltLight setNeedsDisplay];
    [_overloadLight setNeedsDisplay];
}


#pragma mark - Private Methods

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

    if (_decayedLevel != decayedLevel) {
        _decayedLevel = decayedLevel;
        [_progressBar setPercentage:_decayedLevel];
    }

    if (_redLevel != redLevel) {
        _redLevel = redLevel;
        [_progressBar setRedLevel:redLevel];
        [_boltLight setNeedsDisplay];
    }

    if (_overloadLevel != overloadLevel) {
        _overloadLevel = overloadLevel;
        [_overloadLight setNeedsDisplay];
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

        if (lastOverloadTime > dangerTime) {
            dangerTime = lastOverloadTime;
        }
    }

    _overloadTime = lastOverloadTime;

    if (dangerLevel >= _decayedLevel) {
        _dangerLevel = dangerLevel;
        _dangerTime  = dangerTime;

        [self _recomputeDecayedLevel];
    }
}


- (void) setMetering:(BOOL)metering
{
    if (_metering != metering) {
        _metering = metering;
        _dangerLevel = _dangerTime = _overloadTime = 0;

        [self _recomputeDecayedLevel];
        
        [_boltLight setNeedsDisplay];
    }
}


@end

