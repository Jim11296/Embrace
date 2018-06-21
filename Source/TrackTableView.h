//
//  TrackTableView.h
//  Embrace
//
//  Created by Ricci Adams on 2014-02-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>


extern NSString * const EmbraceLockedTrackPasteboardType;
extern NSString * const EmbraceQueuedTrackPasteboardType;


@interface TrackTableView : NSTableView
@property (nonatomic, readonly) NSInteger rowWithMouseInside;
@property (nonatomic, readonly) NSColor *playingTextColor;
@end


@protocol TrackTableViewDelegate <NSTableViewDelegate>
@optional
- (void) trackTableView:(TrackTableView *)tableView isModifyingViaDrag:(BOOL)isModifyingViaDrag;
@end
