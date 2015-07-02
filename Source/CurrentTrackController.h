//
//  LegacyCurrentTrackController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-21.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

@class WaveformView, Player;

@interface CurrentTrackController : NSWindowController <NSMenuDelegate>

@property (nonatomic, weak) Player *player;

@end
