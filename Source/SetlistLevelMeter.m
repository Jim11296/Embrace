// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "SetlistLevelMeter.h"
#import "SetlistProgressBar.h"


@interface SetlistLevelMeterPeakDot : NSView
@end


@interface SetlistLevelMeterLimiterDot : NSView
@property (nonatomic, getter=isOn) BOOL on;
@end


@implementation SetlistLevelMeter {
    SetlistProgressBar *_leftChannelBar;
    SetlistProgressBar *_rightChannelBar;

    SetlistLevelMeterPeakDot    *_leftPeakDot;
    SetlistLevelMeterPeakDot    *_rightPeakDot;

    SetlistLevelMeterLimiterDot *_leftLimiterDot;
    SetlistLevelMeterLimiterDot *_rightLimiterDot;
}


- (instancetype) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self _commonLevelMeterInit];
    }
    
    return self;
}


- (instancetype) initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self _commonLevelMeterInit];
    }
    
    return self;
}


- (void) _commonLevelMeterInit
{
    [self setWantsLayer:YES];
    [self setLayer:[CALayer layer]];
    [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
    [self setAutoresizesSubviews:NO];

    _leftAveragePower = _rightAveragePower = _leftPeakPower = _rightPeakPower = -INFINITY;

    _leftChannelBar  = [[SetlistProgressBar alloc] initWithFrame:CGRectZero];
    _rightChannelBar = [[SetlistProgressBar alloc] initWithFrame:CGRectZero];
    
    _leftPeakDot     = [[SetlistLevelMeterPeakDot alloc] initWithFrame:CGRectZero];
    _rightPeakDot    = [[SetlistLevelMeterPeakDot alloc] initWithFrame:CGRectZero];

    _leftLimiterDot  = [[SetlistLevelMeterLimiterDot alloc] initWithFrame:CGRectZero];
    _rightLimiterDot = [[SetlistLevelMeterLimiterDot alloc] initWithFrame:CGRectZero];

    [_leftPeakDot  setHidden:YES];
    [_rightPeakDot setHidden:YES];
    
    [self addSubview:_leftChannelBar];
    [self addSubview:_rightChannelBar];

    [self addSubview:_leftPeakDot];
    [self addSubview:_rightPeakDot];

    [self addSubview:_leftLimiterDot];
    [self addSubview:_rightLimiterDot];
}


- (void) layout
{
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

    // Opt-out of Auto Layout unless we are on macOS 10.11
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_12) {
        [super layout]; 
    }
}


#pragma mark - Window Listener

- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [_leftChannelBar  windowDidUpdateMain:window];
    [_rightChannelBar windowDidUpdateMain:window];
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
        
        [_leftLimiterDot  setOn:_limiterActive];
        [_rightLimiterDot setOn:_limiterActive];

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
        
        [_leftPeakDot  setHidden:!metering];
        [_rightPeakDot setHidden:!metering];

        [_leftLimiterDot  setOn:NO];
        [_rightLimiterDot setOn:NO];
    }
}


@end


@implementation SetlistLevelMeterPeakDot


- (void) drawRect:(CGRect)rect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    
    [[Theme colorNamed:@"MeterMarker"] set];
    CGContextFillEllipseInRect(context, [self bounds]);
}


@end


@implementation SetlistLevelMeterLimiterDot


- (void) drawRect:(CGRect)rect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];

    if (_on) {
        [[Theme colorNamed:@"MeterRed"] set];

    } else {
        NSColor *color = [Theme colorNamed:@"MeterUnfilled"];

        if (IsAppearanceDarkAqua(self)) {
            CGFloat alpha = [[Theme colorNamed:@"MeterDarkAlpha"] alphaComponent];
            color = GetColorWithMultipliedAlpha(color, alpha);
        }

        [color set];
    }
    
    CGContextFillEllipseInRect(context, [self bounds]);
}


- (void) setOn:(BOOL)on
{
    if (_on != on) {
        _on = on;
        [self setNeedsDisplay:YES];
    }
}


@end
