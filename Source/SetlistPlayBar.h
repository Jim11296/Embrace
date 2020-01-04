// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>


@interface SetlistPlayBar : NSView <EmbraceWindowListener>

@property (nonatomic) float percentage;
@property (nonatomic, getter=isPlaying) BOOL playing;

@end
