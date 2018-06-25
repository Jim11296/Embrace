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
    
    [self setAutoresizesSubviews:NO];
    
    [self addSubview:_hairlineView];
    [self addSubview:_progressBar];
    [self addSubview:_playhead];
        
    [self _updateColors];
}


- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    [self _updateColors];
}


- (void) viewDidChangeEffectiveAppearance
{
    [self _updateColors];
}


- (void) layout
{
    if (@available(macOS 10.12, *)) {
        // Opt-out of Auto Layout
    } else {
        [super layout]; 
    }

    NSRect bounds = [self bounds];
    CGFloat scale = [[self window] backingScaleFactor];

    NSRect barFrame = bounds;
    barFrame.size.height = 3;

    NSRect bottomFrame = bounds;
    bottomFrame.size.height = (1.0 / scale);

    NSRect playheadFrame = bounds;
    playheadFrame.size.height = 7;

    [self _updatePlayheadX];
    
    NSRect leftRect, rightRect;
    NSDivideRect(barFrame, &leftRect, &rightRect, _playheadX - barFrame.origin.x, NSMinXEdge);

    playheadFrame.origin.x   = _playheadX;
    playheadFrame.origin.y   = 0;
    playheadFrame.size.width = 2;
    
    [_progressBar  setHidden:!_playing];
    [_playhead     setHidden:!_playing];
    [_hairlineView setHidden: _playing];

    [_progressBar  setFrame:barFrame];
    [_playhead     setFrame:playheadFrame];
    [_hairlineView setFrame:bottomFrame];
}



#pragma mark - Private Methods

- (void) _updateColors
{
//    NSColor *inactiveColor = [Theme colorNamed:@"MeterUnfilled"];
//    NSColor *dotColor      = [Theme colorNamed:@"MeterMarker"];
//
//
//    [_bottomBorder setBackgroundColor:[inactiveColor CGColor]];
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
        [self setNeedsLayout:YES];
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
