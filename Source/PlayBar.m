// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "PlayBar.h"
#import "SimpleProgressBar.h"
#import "HairlineView.h"


@interface PlayBarPlayhead : NSView
@end


@implementation PlayBar {
    PlayBarPlayhead   *_playhead;
    HairlineView      *_hairlineView;
    SimpleProgressBar *_progressBar;
    
    CGFloat  _playheadX;
}


- (id) initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        [self _commonPlayBarInit];
    }
    
    return self;
}


- (id) initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder])) {
        [self _commonPlayBarInit];
    }
    
    return self;
}


- (void) _commonPlayBarInit
{
    _progressBar = [[SimpleProgressBar alloc] initWithFrame:[self bounds]];
    [_progressBar setRounded:NO];

    _playhead     = [[PlayBarPlayhead alloc] initWithFrame:CGRectZero];
    _hairlineView = [[HairlineView alloc] initWithFrame:CGRectZero];

    [_hairlineView setBorderColor:[Theme colorNamed:@"SetlistSeparator"]];
    [_hairlineView setLayoutAttribute:NSLayoutAttributeBottom];

    [self setWantsLayer:YES];
    [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];

    [self setAutoresizesSubviews:NO];
    
    [self addSubview:_hairlineView];
    [self addSubview:_progressBar];
    [self addSubview:_playhead];
        
    [self _updateHidden];
}


- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [_progressBar windowDidUpdateMain:window];
}


- (void) layout
{
    NSRect bounds = [self bounds];

    NSRect barFrame = bounds;
    barFrame.size.height = 3;

    NSRect bottomFrame = bounds;
    bottomFrame.size.height = 1;

    [_progressBar  setFrame:barFrame];
    [_hairlineView setFrame:bottomFrame];

    [self _updatePlayheadX];
    [_playhead setFrame:CGRectMake(_playheadX, 0, 2, 7)];

    // Opt-out of Auto Layout unless we are on macOS 10.11
    if (NSAppKitVersionNumber < NSAppKitVersionNumber10_12) {
        [super layout]; 
    }
}


#pragma mark - Private Methods

- (void) _updateHidden
{
    [_progressBar  setHidden:!_playing];
    [_playhead     setHidden:!_playing];
    [_hairlineView setHidden: _playing];
}


- (void) _updatePlayheadX
{
    NSRect bounds = [self bounds];
    CGFloat scale = [[self window] backingScaleFactor];
    _playheadX = round((bounds.size.width - 2) * _percentage * scale) / scale;
}


#pragma mark - Accessors

- (void) setPercentage:(float)percentage
{
    if (_percentage != percentage) {
        if (isnan(percentage)) percentage = 0;
        _percentage = percentage;

        [_progressBar setPercentage:percentage];

        CGFloat oldPlayheadX = _playheadX;
        [self _updatePlayheadX];
        
        if (oldPlayheadX != _playheadX) {
            [self setNeedsLayout:YES];
        }
    }
}


- (void) setPlaying:(BOOL)playing
{
    if (_playing != playing) {
        _playing = playing;
        [self _updateHidden];
    }
}


@end


@implementation PlayBarPlayhead

- (void) drawRect:(NSRect)dirtyRect
{
    NSColor *markerColor = [Theme colorNamed:@"MeterMarker"];

    CGRect frame = [self bounds];

    frame.origin.y    -= 2.0;
    frame.size.height += 2.0;

    [markerColor set];
    [[NSBezierPath bezierPathWithRoundedRect:frame xRadius:1 yRadius:1] fill];

}

@end
