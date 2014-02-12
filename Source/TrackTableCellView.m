//
//  SongTableViewCell.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackTableCellView.h"
#import "Track.h"
#import "BorderedView.h"

#define USE_TOP_PLAYING_LINE 0

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


- (BOOL) _tryToPresentContextMenuWithEvent:(NSEvent *)event
{
    NSView *superview = [self superview];
    NSMenu *menu = nil;

    while (superview) {
        if ([superview isKindOfClass:[NSTableView class]]) {
            menu = [superview menu];
            if (menu) break;
        }
        
        superview = [superview superview];
    }
    
    if (menu) {
        [NSMenu popUpContextMenu:menu withEvent:event forView:self];
        return YES;
    }
    
    return NO;

}


- (void) mouseDown:(NSEvent *)theEvent
{
    [super mouseDown:theEvent];

    NSUInteger mask = (NSControlKeyMask | NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask);
    
    if (([theEvent modifierFlags] & mask) == NSControlKeyMask) {
        [self _tryToPresentContextMenuWithEvent:theEvent];
    }
}


- (Track *) track
{
    return (Track *)[self objectValue];
}


- (NSColor *) topTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if (trackStatus == TrackStatusPlaying) {
        return GetRGBColor(0x1866e9, 1.0);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.4);
    }
    
    return [NSColor blackColor];
}


- (NSColor *) bottomTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if (trackStatus == TrackStatusPlaying) {
        return GetRGBColor(0x1866e9, 0.8);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.33);
    }
    
    return GetRGBColor(0x000000, 0.66);
}



- (void) update
{
    Track *track = [self track];
    if (!track) return;

    NSString *titleString = [track title];
    if (!titleString) titleString = @"";
    [[self titleField] setStringValue:titleString];
    [[self titleField] setTextColor:[self topTextColor]];
    
    NSString *durationString = GetStringForTime(round([track playDuration]));
    if (!durationString) durationString = @"";
    [[self durationField] setStringValue:durationString];
    [[self durationField] setTextColor:[self topTextColor]];

    NSColor *bottomBorderColor = [NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0];
    CGFloat bottomBorderHeight = -1;
    BOOL usesDashes = NO;

    if ([track pausesAfterPlaying] && ([track trackStatus] != TrackStatusPlayed)) {
        bottomBorderColor = [NSColor redColor];
        bottomBorderHeight = 2;
        usesDashes = YES;
    }

#if USE_TOP_PLAYING_LINE
    NSColor *topBorderColor = [NSColor clearColor];
    CGFloat topBorderHeight = 0;

    if ([track trackStatus] == TrackStatusPlaying) {
        topBorderColor = [self topTextColor];
        topBorderHeight = 2;
    }

    [[self borderedView] setTopBorderColor:topBorderColor];
    [[self borderedView] setTopBorderHeight:topBorderHeight];
#endif
    
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
    
    _observedKeyPaths = [self keyPathsToObserve];
    _observedObject   = objectValue;

    for (NSString *keyPath in _observedKeyPaths) {
        [_observedObject addObserver:self forKeyPath:keyPath options:0 context:NULL];
    }

    [self update];
}


- (NSArray *) keyPathsToObserve
{
    return @[ @"title", @"artist", @"trackStatus", @"playDuration", @"pausesAfterPlaying" ];
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
