// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>
#import "AudioFile.h"

@class Track;

@interface TrackScheduler : NSObject

- (id) initWithTrack:(Track *)track outputFormat:(AudioStreamBasicDescription)outputFormat;

- (BOOL) setup;

- (BOOL) startSchedulingWithAudioUnit:(AudioUnit)audioUnit timeStamp:(AudioTimeStamp)timeStamp;
- (void) stopScheduling:(AudioUnit)audioUnit;

- (AudioFileError) audioFileError;

@property (nonatomic, readonly) Track *track;
@property (nonatomic, readonly) AudioStreamBasicDescription clientFormat;

@end
