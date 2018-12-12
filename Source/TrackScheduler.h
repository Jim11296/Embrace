// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>
#import "HugAudioFile.h"

#if 0
@class Track;

@interface TrackScheduler : NSObject

- (id) initWithTrack:(Track *)track;

- (BOOL) setup;

- (BOOL) startSchedulingWithAudioUnit:(AudioUnit)audioUnit paddingInSeconds:(NSTimeInterval)paddingInSeconds;
- (void) stopScheduling:(AudioUnit)audioUnit;


- (NSTimeInterval) timeElapsed;
- (NSInteger) samplesPlayed;
- (BOOL) isDone;

@property (nonatomic, readonly) Track *track;
@property (nonatomic, readonly) AudioStreamBasicDescription clientFormat;
@property (nonatomic, readonly) NSError *error;

@end

#endif

