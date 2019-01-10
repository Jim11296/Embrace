// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>


@interface SetlistPlayBar : NSView <EmbraceWindowListener>

@property (nonatomic) float percentage;
@property (nonatomic, getter=isPlaying) BOOL playing;

@end
