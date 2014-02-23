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

- (void) showEndTime;

@property (nonatomic, readonly) Track *track;

@property (nonatomic, weak) IBOutlet BorderedView *borderedView;

@property (nonatomic, weak) IBOutlet NSTextField *titleField;
@property (nonatomic, weak) IBOutlet NSTextField *durationField;
@property (nonatomic, weak) IBOutlet NSTextField *artistField;
@property (nonatomic, weak) IBOutlet NSTextField *tonalityAndBPMField;

@property (nonatomic, assign, getter=isSelected) BOOL selected;

@property (nonatomic, assign) BOOL drawsInsertionPointWorkaround;

@end
