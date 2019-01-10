// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@class Track;


@interface WaveformView : NSView <CALayerDelegate>

- (void) redisplay;

@property (nonatomic, strong) Track *track;

@property (nonatomic) float percentage;
@property (nonatomic) NSColor *inactiveWaveformColor;
@property (nonatomic) NSColor *activeWaveformColor;

@end
