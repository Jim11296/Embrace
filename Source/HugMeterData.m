// (c) 2018-2019 Ricci Adams.  All rights reserved.

#import "HugMeterData.h"

@implementation HugMeterData

- (instancetype) initWithStruct:(HugMeterDataStruct)meterData
{
    if ((self = [super init])) {

        _peakLevel = meterData.peakLevel;
        _heldLevel = meterData.heldLevel;
        _limiterActive = meterData.limiterActive;
    }
    
    return self;
}


- (NSUInteger) hash
{
    return [@(_peakLevel) hash] ^
           [@(_heldLevel) hash] ^
           [@(_limiterActive) hash];
}


- (BOOL) isEqual:(id)otherObject
{
    if (![otherObject isKindOfClass:[HugMeterData class]]) {
        return NO;
    }
    
    HugMeterData *otherData = (HugMeterData *)otherObject;
    
    return _peakLevel     == otherData->_peakLevel &&
           _heldLevel     == otherData->_heldLevel &&
           _limiterActive == otherData->_limiterActive;

}


@end
