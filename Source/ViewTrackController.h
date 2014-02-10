//
//  ViewTrackController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-02-02.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WaveformView, Track;

@interface ViewTrackController : NSWindowController

- (id) initWithTrack:(Track *)track;

@property (nonatomic, weak) IBOutlet WaveformView *waveformView;

@property (nonatomic, strong) Track *track;

@end
