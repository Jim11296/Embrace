// (c) 2018-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

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

