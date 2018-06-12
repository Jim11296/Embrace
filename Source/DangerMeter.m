//
//  LevelMeter.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "DangerMeter.h"
#import "Player.h"

#import "SimpleProgressBar.h"
#import "SimpleProgressDot.h"


@implementation DangerMeter {
    NSTimer *_timer;
    double _dangerLevel;
    double _decayedLevel;
    double _overloadLevel;

    NSTimeInterval _dangerTime;
    NSTimeInterval _overloadTime;

    SimpleProgressDot *_boltDot;
    SimpleProgressBar *_dangerBar;
    SimpleProgressDot *_overloadDot;
}



- (instancetype) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self _setupDangerMeter];
    }
    
    return self;
}


- (instancetype) initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self _setupDangerMeter];
    }
    
    return self;
}


- (void) _setupDangerMeter
{
    [self setWantsLayer:YES];
    [self setLayer:[CALayer layer]];
    [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
    [self setAutoresizesSubviews:NO];

    NSColor *inactiveColor = [Theme colorNamed:@"MeterInactive"];
    NSColor *tintColor     = [Theme colorNamed:@"MeterPeak"];
    
    NSBezierPath *boltPath = [NSBezierPath bezierPath];
    [boltPath moveToPoint:NSMakePoint(2, 10)];
    [boltPath lineToPoint:NSMakePoint(2, 6)];
    [boltPath lineToPoint:NSMakePoint(4, 6)];
    [boltPath lineToPoint:NSMakePoint(2, 0)];
    [boltPath lineToPoint:NSMakePoint(2, 4)];
    [boltPath lineToPoint:NSMakePoint(0, 4)];
    [boltPath closePath];

    _boltDot     = [[SimpleProgressDot alloc] initWithFrame:CGRectZero];
    _dangerBar   = [[SimpleProgressBar alloc] initWithFrame:CGRectZero];
    _overloadDot = [[SimpleProgressDot alloc] initWithFrame:CGRectZero];

    [_boltDot     setInactiveColor:inactiveColor];
    [_dangerBar   setInactiveColor:inactiveColor];
    [_overloadDot setInactiveColor:inactiveColor];

    [_boltDot     setTintColor:tintColor];
    [_dangerBar   setTintColor:tintColor];
    [_overloadDot setTintColor:tintColor];
   
    [_boltDot setPath:boltPath];
    
    [self addSubview:_boltDot];
    [self addSubview:_dangerBar];
    [self addSubview:_overloadDot];
}


- (void) layout
{
    if (@available(macOS 10.12, *)) {
        // Opt-out of Auto Layout
    } else {
        [super layout]; 
    }

    NSRect bounds = [self bounds];

    CGFloat barY = round((bounds.size.height - 4) / 2);

    NSRect barRect = CGRectMake(7, barY, bounds.size.width - 7, 4);
    NSRect overloadRect = barRect;
    
    barRect.size.width -= 6;
    overloadRect.size.width =  4;
    overloadRect.origin.x   = CGRectGetMaxX(barRect) + 2;

    [_boltDot     setFrame:CGRectMake(1, barY - 3, 4, 10)];
    [_dangerBar   setFrame:barRect];
    [_overloadDot setFrame:overloadRect];
}


#pragma mark - Window Listener

- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    BOOL     isMainWindow = [[self window] isMainWindow];
    NSColor *activeColor  = [Theme colorNamed:isMainWindow ? @"MeterActiveMain" : @"MeterActive"];
    
    [_boltDot   setActiveColor:activeColor];
    [_dangerBar setActiveColor:activeColor]; 
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
    
    _decayedLevel  = decayedLevel;
    _overloadLevel = overloadLevel;
    
    CGFloat tintLevel = (decayedLevel * 2.0) - 1.0;
    if (tintLevel < 0) tintLevel = 0;

    [_boltDot   setPercentage:_metering ? 1.0 : 0.0];
    [_dangerBar setPercentage:_decayedLevel];
    [_dangerBar setTintLevel:tintLevel];
    [_boltDot   setTintLevel:tintLevel];

    [_overloadDot setTintLevel:_overloadLevel];
    
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
    }
}


@end
