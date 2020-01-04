// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>


@interface SetlistDangerView : NSView <EmbraceWindowListener>

@property (nonatomic, getter=isMetering) BOOL metering;

- (void) addDangerPeak:(Float32)dangerPeak lastOverloadTime:(NSTimeInterval)lastOverloadTime;

@end
