// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>

@class Track;

@interface TrackTableCellView : NSTableCellView

- (void) revealTime;
- (void) updateColors;

@property (nonatomic, readonly) Track *track;

@property (nonatomic, assign, getter=isExpandedPlayedTrack) BOOL expandedPlayedTrack;

@end
