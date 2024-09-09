// (c) 2017-2024 Ricci Adams
// MIT License (or) 1-clause BSD License


@interface SetlistProgressBar : NSView <EmbraceWindowListener>

// Optimization for SetlistDangerMeter
- (void) setFilledColorWithRedLevel:(CGFloat)redLevel inContext:(CGContextRef)context;
- (void) setUnfilledColorWithRedLevel:(CGFloat)redLevel inContext:(CGContextRef)context;

@property (nonatomic) CGFloat percentage;
@property (nonatomic) CGFloat redLevel;
@property (nonatomic, getter=isRounded) BOOL rounded;


@end
