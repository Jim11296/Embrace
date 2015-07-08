//
//  SongTableViewCell.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ActionButton, BorderedView, Track;

@interface TrackTableCellView : NSTableCellView

- (void) revealEndTime;

@property (nonatomic, readonly) Track *track;
@property (nonatomic, assign, getter=isSelected) BOOL selected;

@property (nonatomic, assign) BOOL drawsInsertionPointWorkaround;
@property (nonatomic, assign) BOOL drawsLighterSelectedBackground;

@property (nonatomic, assign, getter=isExpandedPlayedTrack) BOOL expandedPlayedTrack;

@end
