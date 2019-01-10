// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>

@class WaveformView, Track;

@interface ViewTrackController : NSWindowController

- (id) initWithTrack:(Track *)track;

@property (nonatomic, strong) Track *track;

@end
