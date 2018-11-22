//
//  SimpleProgressBar.h
//  Embrace
//
//  Created by Ricci Adams on 2017-06-25.
//  Copyright (c) 2017 Ricci Adams. All rights reserved.
//

@interface SetlistProgressBar : NSView <EmbraceWindowListener>

// Optimization for SetlistDangerMeter
- (void) setFilledColorWithRedLevel:(CGFloat)redLevel inContext:(CGContextRef)context;
- (void) setUnfilledColorWithRedLevel:(CGFloat)redLevel inContext:(CGContextRef)context;

@property (nonatomic) CGFloat percentage;
@property (nonatomic) CGFloat redLevel;
@property (nonatomic, getter=isRounded) BOOL rounded;


@end
