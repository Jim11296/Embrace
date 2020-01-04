// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@class Track;

@interface TrackTableCellView : NSTableCellView

- (void) revealTime;
- (void) updateColors;

@property (nonatomic, readonly) Track *track;

@property (nonatomic, assign, getter=isExpandedPlayedTrack) BOOL expandedPlayedTrack;

@end
