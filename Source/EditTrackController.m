//
//  EditTrackController.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "EditTrackController.h"
#import "Waveform.h"
#import "Track.h"
#import "WaveformView.h"

@implementation EditTrackController {
    Waveform *_waveform;
}


- (id) initWithTrack:(Track *)track
{
    if ((self = [super init])) {
        _track = track;
        _waveform = [[Waveform alloc] initWithFileURL:[_track fileURL]];
    }
    
    return self;
}


- (NSString *) windowNibName
{
    return @"EditTrackWindow";
}


- (void) windowDidLoad
{
    [[self waveformView] setWaveform:_waveform];
}


@end
