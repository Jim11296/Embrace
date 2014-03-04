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

@property (nonatomic, weak) IBOutlet BorderedView *borderedView;

@property (nonatomic, weak) IBOutlet NSTextField *titleField;
@property (nonatomic, weak) IBOutlet NSTextField *durationField;

@property (nonatomic, weak) IBOutlet NSTextField *lineTwoLeftField;
@property (nonatomic, weak) IBOutlet NSTextField *lineTwoRightField;

@property (nonatomic, weak) IBOutlet NSTextField *lineThreeLeftField;
@property (nonatomic, weak) IBOutlet NSTextField *lineThreeRightField;


@property (nonatomic, assign, getter=isSelected) BOOL selected;

@property (nonatomic, assign) BOOL drawsInsertionPointWorkaround;

@end
