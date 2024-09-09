// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>

@class Track;


@interface WaveformView : NSView <CALayerDelegate>

- (void) redisplay;

@property (nonatomic, strong) Track *track;

@property (nonatomic) float percentage;
@property (nonatomic) NSColor *inactiveWaveformColor;
@property (nonatomic) NSColor *activeWaveformColor;

@end
