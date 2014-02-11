//
//  Scheduler.h
//  Embrace
//
//  Created by Ricci Adams on 2014-02-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Track;

@interface TrackScheduler : NSObject

- (id) initWithTrack:(Track *)track streamDescription:(AudioStreamBasicDescription)streamDescription;


- (void) startSchedulingWithAudioUnit:(AudioUnit)audioUnit timeStamp:(AudioTimeStamp)timeStamp;
- (void) stopScheduling:(AudioUnit)audioUnit;

@property (nonatomic, readonly) Track *track;
@property (nonatomic, readonly) AudioStreamBasicDescription streamDescription;


@end
