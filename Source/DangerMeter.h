// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>


@interface DangerMeter : NSView <EmbraceWindowListener>

@property (nonatomic, getter=isMetering) BOOL metering;

- (void) addDangerPeak:(Float32)dangerPeak lastOverloadTime:(NSTimeInterval)lastOverloadTime;

@end
