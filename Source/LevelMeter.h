//
//  LevelMeter.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Player;

@interface LevelMeter : NSView

@property (nonatomic, getter=isMetering) BOOL metering;
@property (nonatomic, getter=isVertical) BOOL vertical;


- (void) setLeftAveragePower: (Float32) leftAveragePower
           rightAveragePower: (Float32) rightAveragePower
               leftPeakPower: (Float32) leftPeakPower
              rightPeakPower: (Float32) rightPeakPower
               limiterActive: (BOOL) limiterActive;

@property (nonatomic, readonly) Float32 leftAveragePower;
@property (nonatomic, readonly) Float32 rightAveragePower;
@property (nonatomic, readonly) Float32 leftPeakPower;
@property (nonatomic, readonly) Float32 rightPeakPower;
@property (nonatomic, readonly, getter=isLimiterActive) BOOL limiterActive;

@end
