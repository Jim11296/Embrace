// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "SetlistPlayBar.h"
#import "SetlistProgressBar.h"
#import "HairlineView.h"


@interface SetlistPlayBarPlayhead : NSView
@end


@implementation SetlistPlayBar {
    SetlistPlayBarPlayhead *_playhead;
    HairlineView           *_hairlineView;
    SetlistProgressBar     *_progressBar;
    
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
    _progressBar = [[SetlistProgressBar alloc] initWithFrame:[self bounds]];
    [_progressBar setRounded:NO];

    _playhead     = [[SetlistPlayBarPlayhead alloc] initWithFrame:CGRectZero];
    _hairlineView = [[HairlineView alloc] initWithFrame:CGRectZero];

    [_hairlineView setBorderColor:[NSColor colorNamed:@"SetlistSeparator"]];
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

    NSRect barFrame = GetInsetBounds(self);
    barFrame.size.height = 3;

    NSRect bottomFrame = bounds;
    bottomFrame.size.height = 1;

    [_progressBar  setFrame:barFrame];
    [_hairlineView setFrame:bottomFrame];
    

    [self _updatePlayheadX];
    [_playhead setFrame:CGRectMake(_playheadX, 0, 2, 7)];
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


@implementation SetlistPlayBarPlayhead

- (void) drawRect:(NSRect)dirtyRect
{
    NSColor *markerColor = [NSColor colorNamed:@"MeterMarker"];

    CGRect frame = [self bounds];

    frame.origin.y    -= 2.0;
    frame.size.height += 2.0;

    [markerColor set];
    [[NSBezierPath bezierPathWithRoundedRect:frame xRadius:1 yRadius:1] fill];
}

@end
