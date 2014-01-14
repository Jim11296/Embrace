//
//  EditController.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WaveformView, Track;

@interface EditTrackController : NSWindowController

- (id) initWithTrack:(Track *)track;

@property (nonatomic, strong) IBOutlet WaveformView *waveformView;
@property (nonatomic, weak) Track *track;

@end
