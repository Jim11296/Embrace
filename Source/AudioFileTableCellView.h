//
//  SongTableViewCell.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TrackTableCellView.h"

@class ActionButton, BorderedView;

@interface AudioFileTableCellView : TrackTableCellView

@property (nonatomic, weak) IBOutlet NSTextField *artistField;

@end
