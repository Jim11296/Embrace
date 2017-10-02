//
//  LevelMeter.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "LevelMeter.h"
#import "SimpleProgressDot.h"
#import "SimpleProgressBar.h"


@implementation LevelMeter {
    SimpleProgressBar *_leftChannelBar;
    SimpleProgressBar *_rightChannelBar;
    SimpleProgressDot *_leftPeakDot;
    SimpleProgressDot *_rightPeakDot;
    SimpleProgressDot *_leftLimiterDot;
    SimpleProgressDot *_rightLimiterDot;
}

- (instancetype) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self _setupLevelMeter];
    }
    
    return self;
}


- (instancetype) initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self _setupLevelMeter];
    }
    
    return self;
}


- (void) _setupLevelMeter
{
    [self setWantsLayer:YES];
    [self setLayer:[CALayer layer]];
    [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
    [self setAutoresizesSubviews:NO];

    _leftAveragePower = _rightAveragePower = _leftPeakPower = _rightPeakPower = -INFINITY;

    _leftChannelBar  = [[SimpleProgressBar alloc] initWithFrame:CGRectZero];
    _rightChannelBar = [[SimpleProgressBar alloc] initWithFrame:CGRectZero];
    
    _leftPeakDot     = [[SimpleProgressDot alloc] initWithFrame:CGRectZero];
    _rightPeakDot    = [[SimpleProgressDot alloc] initWithFrame:CGRectZero];

    _leftLimiterDot  = [[SimpleProgressDot alloc] initWithFrame:CGRectZero];
    _rightLimiterDot = [[SimpleProgressDot alloc] initWithFrame:CGRectZero];
    
    [_leftChannelBar  setInactiveColor:GetRGBColor(0x0, 0.15)];
    [_rightChannelBar setInactiveColor:GetRGBColor(0x0, 0.15)];

    [_leftPeakDot  setActiveColor:[NSColor blackColor]];
    [_rightPeakDot setActiveColor:[NSColor blackColor]];
    [_leftPeakDot  setPercentage:1.0];
    [_rightPeakDot setPercentage:1.0];
    [_leftPeakDot  setHidden:YES];
    [_rightPeakDot setHidden:YES];

    [_leftLimiterDot  setInactiveColor:GetRGBColor(0x0, 0.15)];
    [_rightLimiterDot setInactiveColor:GetRGBColor(0x0, 0.15)];
    [_leftLimiterDot  setTintColor:[NSColor redColor]];
    [_rightLimiterDot setTintColor:[NSColor redColor]];
    
    [self addSubview:_leftChannelBar];
    [self addSubview:_rightChannelBar];

    [self addSubview:_leftPeakDot];
    [self addSubview:_rightPeakDot];

    [self addSubview:_leftLimiterDot];
    [self addSubview:_rightLimiterDot];
}


- (void) layout
{
    if (@available(macOS 10.12, *)) {
        // Opt-out of Auto Layout
    } else {
        [super layout]; 
    }
    
    NSRect bounds = [self bounds];
    CGFloat barHeight = 4;

    bounds = NSInsetRect(bounds, 1, 0);

    NSRect leftChannelFrame = bounds;
    leftChannelFrame.size.height = barHeight;
    leftChannelFrame.origin.y = round((bounds.size.height - leftChannelFrame.size.height) / 2);

    NSRect rightChannelFrame = leftChannelFrame;
    rightChannelFrame.origin.y -= 6;

    leftChannelFrame.size.width  -= 4;
    rightChannelFrame.size.width -= 4;

    NSRect leftLimiterFrame  = leftChannelFrame;
    NSRect rightLimiterFrame = rightChannelFrame;
    
    leftLimiterFrame.size.width = rightLimiterFrame.size.width = 4;
    leftLimiterFrame.origin.x   = rightLimiterFrame.origin.x = CGRectGetMaxX(leftChannelFrame) + 1;
   
    void (^layoutPeak)(NSView *, NSRect, Float32) = ^(NSView *peakDot, NSRect channelFrame, Float32 power) {
        CGFloat peakX = (60 + power) * ((channelFrame.size.width - 2) / 60);
        if (peakX < 0) peakX  = 0;

        CGFloat alpha = 0;
        if (peakX < 1) {
            alpha = 0;
        } else if (peakX < 10) {
            alpha = peakX / 10.0;
        } else {
            alpha = 1.0;
        }

        peakX += 1;

        NSRect dotFrame = channelFrame;
        dotFrame.size.width = dotFrame.size.height = 4;
        dotFrame.origin.x = round(peakX - 2);

        [peakDot setAlphaValue:alpha];
        [peakDot setFrame:dotFrame];
    };
    
    [_leftChannelBar  setFrame:leftChannelFrame];
    [_rightChannelBar setFrame:rightChannelFrame];

    [_leftLimiterDot  setFrame:leftLimiterFrame];
    [_rightLimiterDot setFrame:rightLimiterFrame];

    layoutPeak(_leftPeakDot,  leftChannelFrame,  _leftPeakPower);
    layoutPeak(_rightPeakDot, rightChannelFrame, _rightPeakPower);
}


#pragma mark - Window Listener

- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    BOOL     isMainWindow   = [[self window] isMainWindow];
    NSColor *activeBarColor = isMainWindow ? GetRGBColor(0x707070, 1.0) : GetRGBColor(0xA0A0A0, 1.0);

    [_leftChannelBar  setActiveColor:activeBarColor];
    [_rightChannelBar setActiveColor:activeBarColor]; 
}


#pragma mark - Accessors

- (void) setLeftAveragePower: (Float32) leftAveragePower
           rightAveragePower: (Float32) rightAveragePower
               leftPeakPower: (Float32) leftPeakPower
              rightPeakPower: (Float32) rightPeakPower
               limiterActive: (BOOL) limiterActive
{
    if (leftPeakPower     > 0) leftPeakPower     = 0;
    if (rightPeakPower    > 0) rightPeakPower    = 0;
    if (leftAveragePower  > 0) leftAveragePower  = 0;
    if (rightAveragePower > 0) rightAveragePower = 0;

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
        
        CGFloat leftPercent = (60.0 + leftAveragePower) / 60.0;
        if (leftPercent < 0) leftPercent = 0;

        CGFloat rightPercent = (60.0 + rightAveragePower) / 60.0;
        if (rightPercent < 0) rightPercent = 0;
        
        [_leftChannelBar  setPercentage:leftPercent];
        [_rightChannelBar setPercentage:rightPercent];
    
        [_leftLimiterDot  setTintLevel:(_limiterActive ? 1.0 : 0.0)];
        [_rightLimiterDot setTintLevel:(_limiterActive ? 1.0 : 0.0)];
        
        [self setNeedsLayout:YES];
    }
}


- (void) setMetering:(BOOL)metering
{
    if (_metering != metering) {
        _metering = metering;
        _leftAveragePower = _rightAveragePower = _leftPeakPower = _rightPeakPower = -INFINITY;
        _limiterActive = NO;
        
        [_leftChannelBar  setPercentage:0];
        [_rightChannelBar setPercentage:0];
        
        [_leftLimiterDot  setTintLevel:0];
        [_rightLimiterDot setTintLevel:0];

        [_leftPeakDot  setHidden:!metering];
        [_rightPeakDot setHidden:!metering];
        
        [self setNeedsDisplay:YES];
    }
}


@end
