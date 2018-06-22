//  Copyright (c) 2014-2018 Ricci Adams. All rights reserved.


#import <Cocoa/Cocoa.h>

@interface PlayBar : NSView <CALayerDelegate, EmbraceWindowListener>

@property (nonatomic) float percentage;
@property (nonatomic, getter=isPlaying) BOOL playing;

@end
