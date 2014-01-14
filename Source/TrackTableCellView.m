//
//  SongTableViewCell.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackTableCellView.h"
#import "Track.h"
#import "BorderedView.h"

@implementation TrackTableCellView {
    NSArray *_observedKeyPaths;
    id       _observedObject;
}

- (void) dealloc
{
    [self _removeObservers];
}


- (void) _removeObservers
{
    for (NSString *keyPath in _observedKeyPaths) {
        [_observedObject removeObserver:self forKeyPath:keyPath context:NULL];
    }

    _observedKeyPaths = nil;
    _observedObject   = nil;
}

- (Track *) track
{
    return (Track *)[self objectValue];
}


- (NSColor *) topTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if (trackStatus == TrackStatusPlaying || trackStatus == TrackStatusPadding) {
        return GetRGBColor(0x1866e9, 1.0);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.5);
    }
    
    return [NSColor blackColor];
}


- (NSColor *) bottomTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if (trackStatus == TrackStatusPlaying || trackStatus == TrackStatusPadding) {
        return GetRGBColor(0x1866e9, 0.5);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.5);
    }
    
    return GetRGBColor(0x000000, 0.66);
}



- (void) update
{
    Track *track = [self track];
    if (!track) return;

    [[self titleField]    setTextColor:[self topTextColor]];
    [[self durationField] setTextColor:[self topTextColor]];


    NSString *durationString = [track playDurationString];
    if (!durationString) durationString = @"";
    [[self durationField] setStringValue:durationString];

    NSColor *bottomBorderColor = [NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0];
    CGFloat bottomBorderHeight = -1;
    BOOL usesDashes = NO;
    
    if ([track pausesAfterPlaying] && ([track trackStatus] != TrackStatusPlayed)) {
        bottomBorderColor = [NSColor redColor];
        bottomBorderHeight = 2;
        usesDashes = YES;
    }
    
    [[self borderedView] setBottomBorderColor:bottomBorderColor];
    [[self borderedView] setBottomBorderHeight:bottomBorderHeight];
    [[self borderedView] setUsesDashes:usesDashes];

    if (_selected) {
        [[self borderedView] setBackgroundColor:GetRGBColor(0xecf2fe, 1.0)];
    } else {
        [[self borderedView] setBackgroundColor:nil];
    }
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _observedObject) {
        if ([_observedKeyPaths containsObject:keyPath]) {
            [self update];
        }
    }
}


- (void) setObjectValue:(id)objectValue
{
    [self _removeObservers];

    [super setObjectValue:objectValue];
    [self update];
    
    _observedKeyPaths = [self keyPathsToObserve];
    _observedObject   = objectValue;

    for (NSString *keyPath in _observedKeyPaths) {
        [_observedObject addObserver:self forKeyPath:keyPath options:0 context:NULL];
    }
}

- (NSArray *) keyPathsToObserve
{
    return @[ @"trackStatus", @"playDurationString", @"pausesAfterPlaying" ];
}

- (void) setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    [self update];
}

- (void) setSelected:(BOOL)selected
{
    if (_selected != selected) {
        _selected = selected;
        [self update];
    }
}


@end
