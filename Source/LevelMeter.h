//
//  LevelMeter.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

@interface LevelMeter : NSView

- (void) updateWithTrack:(Track *)track;

@end
