// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "ViewTrackController.h"
#import "WaveformView.h"
#import "Track.h"

@interface ViewTrackController ()
@property (nonatomic, weak) IBOutlet WaveformView *waveformView;
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

    [[self waveformView] setTrack:_track];
}


@end
