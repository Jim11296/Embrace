//
//  HugMeterData.h
//  Embrace
//
//  Created by Ricci Adams on 2018-12-04.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct HugMeterDataStruct {
    float peakLevel;
    float heldLevel;
    BOOL  limiterActive;
} HugMeterDataStruct;


@interface HugMeterData : NSObject

- (instancetype) initWithStruct:(HugMeterDataStruct)meterData;

@property (nonatomic, readonly) float peakLevel;
@property (nonatomic, readonly) float heldLevel;
@property (nonatomic, readonly, getter=isLimiterActive) BOOL limiterActive;

@end

