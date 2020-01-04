// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "SetlistMeterView.h"
#import "SetlistProgressBar.h"
#import "HugMeterData.h"

@interface SetlistMeterViewHeldDot : NSView
@end


@interface SetlistMeterViewLimiterDot : NSView
@property (nonatomic, getter=isOn) BOOL on;
@end


@implementation SetlistMeterView {
    SetlistProgressBar *_leftChannelBar;
    SetlistProgressBar *_rightChannelBar;

    SetlistMeterViewHeldDot *_leftHeldDot;
    SetlistMeterViewHeldDot *_rightHeldDot;

    SetlistMeterViewLimiterDot *_leftLimiterDot;
    SetlistMeterViewLimiterDot *_rightLimiterDot;

    float _leftPeakLevel;
    float _leftHeldLevel;
    BOOL  _leftLimiterActive;

    float _rightPeakLevel;
    float _rightHeldLevel;
    BOOL  _rightLimiterActive;
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

    _leftChannelBar  = [[SetlistProgressBar alloc] initWithFrame:CGRectZero];
    _rightChannelBar = [[SetlistProgressBar alloc] initWithFrame:CGRectZero];
    
    _leftHeldDot     = [[SetlistMeterViewHeldDot alloc] initWithFrame:CGRectZero];
    _rightHeldDot    = [[SetlistMeterViewHeldDot alloc] initWithFrame:CGRectZero];

    _leftLimiterDot  = [[SetlistMeterViewLimiterDot alloc] initWithFrame:CGRectZero];
    _rightLimiterDot = [[SetlistMeterViewLimiterDot alloc] initWithFrame:CGRectZero];

    [_leftHeldDot  setHidden:YES];
    [_rightHeldDot setHidden:YES];
    
    [self addSubview:_leftChannelBar];
    [self addSubview:_rightChannelBar];

    [self addSubview:_leftHeldDot];
    [self addSubview:_rightHeldDot];

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
   
    void (^layoutHeldDot)(NSView *, NSRect, float) = ^(NSView *peakDot, NSRect channelFrame, float level) {
        float power = cbrt(level);
        
        CGFloat peakX = power * (channelFrame.size.width - 2);
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

    layoutHeldDot(_leftHeldDot,  leftChannelFrame,  [_leftMeterData heldLevel]);
    layoutHeldDot(_rightHeldDot, rightChannelFrame, [_rightMeterData heldLevel]);
}


#pragma mark - Window Listener

- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [_leftChannelBar  windowDidUpdateMain:window];
    [_rightChannelBar windowDidUpdateMain:window];
}


#pragma mark - Accessors

- (void) setLeftMeterData: (HugMeterData *) leftMeterData
           rightMeterData: (HugMeterData *) rightMeterData
{
    if (leftMeterData  != _leftMeterData ||
        rightMeterData != _rightMeterData ||
        ![leftMeterData  isEqual:_leftMeterData] ||
        ![rightMeterData isEqual:_rightMeterData]
    ) {
        _leftMeterData  = leftMeterData;
        _rightMeterData = rightMeterData;

        CGFloat leftPercent  = cbrt([leftMeterData  peakLevel]);
        CGFloat rightPercent = cbrt([rightMeterData peakLevel]);

        [_leftChannelBar  setPercentage:leftPercent];
        [_rightChannelBar setPercentage:rightPercent];
        
        [_leftLimiterDot  setOn:[leftMeterData  isLimiterActive]];
        [_rightLimiterDot setOn:[rightMeterData isLimiterActive]];

        [self setNeedsLayout:YES];
    }
}


- (void) setMetering:(BOOL)metering
{
    if (_metering != metering) {
        _metering = metering;
        _leftMeterData  = nil;
        _rightMeterData = nil;
        
        [_leftChannelBar  setPercentage:0];
        [_rightChannelBar setPercentage:0];
        
        [_leftHeldDot  setHidden:!metering];
        [_rightHeldDot setHidden:!metering];

        [_leftLimiterDot  setOn:NO];
        [_rightLimiterDot setOn:NO];

        [self setNeedsLayout:YES];
    }
}


@end


@implementation SetlistMeterViewHeldDot


- (void) drawRect:(CGRect)rect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    
    [[NSColor colorNamed:@"MeterMarker"] set];
    CGContextFillEllipseInRect(context, [self bounds]);
}


@end


@implementation SetlistMeterViewLimiterDot


- (void) drawRect:(CGRect)rect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];

    if (_on) {
        [[NSColor colorNamed:@"MeterRed"] set];

    } else {
        NSColor *color = [NSColor colorNamed:@"MeterUnfilled"];

        if (IsAppearanceDarkAqua(self)) {
            CGFloat alpha = [[NSColor colorNamed:@"MeterDarkAlpha"] alphaComponent];
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
