//
//  ViewTrackController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-02.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "ViewTrackController.h"
#import "WaveformView.h"
#import "Track.h"

@interface ViewTrackController ()

@end


@implementation ViewTrackController

- (id) initWithTrack:(Track *)track
{
    if ((self = [super init])) {
        _track = track;
    }
    
    return self;
}

- (NSString *) windowNibName
{
    return @"ViewTrackWindow";
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    
    if ([_track title]) {
        [[self window] setTitle:[_track title]];
    }

    [[self waveformView] setShowsDebugInformation:YES];
    [[self waveformView] setTrack:_track];
}


@end
