// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Cocoa/Cocoa.h>


@interface SetlistPlayBar : NSView <EmbraceWindowListener>

@property (nonatomic) float percentage;
@property (nonatomic, getter=isPlaying) BOOL playing;

@end
