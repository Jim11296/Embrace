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
- (void) updateInsertionPointWorkaround:(BOOL)yn;

- (void) updateSelectedColorWorkaround:(BOOL)yn;
- (void) willDrawInsertionPointAboveRow:(NSInteger)row;

@property (nonatomic, readonly) NSInteger rowWithMouseInside;

@end


@protocol TrackTableViewDelegate <NSTableViewDelegate>
@optional
- (void) trackTableView:(TrackTableView *)tableView isModifyingViaDrag:(BOOL)isModifyingViaDrag;
@end