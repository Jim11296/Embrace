//
//  WaveformView.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Track;

@interface WaveformView : NSView <CALayerDelegate>

- (void) redisplay;

@property (nonatomic, strong) Track *track;

@property (nonatomic) BOOL showsDebugInformation;

@property (nonatomic) float percentage;
@property (nonatomic) NSColor *inactiveWaveformColor;
@property (nonatomic) NSColor *activeWaveformColor;

@end
