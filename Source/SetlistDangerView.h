// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Cocoa/Cocoa.h>


@interface SetlistDangerView : NSView <EmbraceWindowListener>

@property (nonatomic, getter=isMetering) BOOL metering;

- (void) addDangerPeak:(Float32)dangerPeak lastOverloadTime:(NSTimeInterval)lastOverloadTime;

@end
