//
//  PlayBar.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PlayBar : NSView <CALayerDelegate>

@property (nonatomic) float percentage;
@property (nonatomic, getter=isPlaying) BOOL playing;

@end
