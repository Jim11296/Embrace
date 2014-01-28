//
//  SongTableViewCell.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TrackTableCellView.h"


@interface SilenceTableCellView : TrackTableCellView

@property (nonatomic, weak) IBOutlet NSSlider *slider;

@end
