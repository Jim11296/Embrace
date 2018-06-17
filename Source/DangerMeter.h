//
//  LevelMeter.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DangerMeter : NSView <EmbraceWindowListener>

@property (nonatomic, getter=isMetering) BOOL metering;

- (void) addDangerPeak:(Float32)dangerPeak lastOverloadTime:(NSTimeInterval)lastOverloadTime;

@end
