// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>

@class HugMeterData;

@interface SetlistMeterView : NSView <EmbraceWindowListener>

@property (nonatomic, getter=isMetering) BOOL metering;

- (void) setLeftMeterData:(HugMeterData *)leftMeterData
           rightMeterData:(HugMeterData *)rightMeterData;

@property (nonatomic, readonly) HugMeterData *leftMeterData;
@property (nonatomic, readonly) HugMeterData *rightMeterData;

@end
