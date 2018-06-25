// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>


@interface EmbraceButton : NSButton <EmbraceWindowListener>

- (void) performOpenAnimationToImage:(NSImage *)image enabled:(BOOL)enabled;
- (void) performPopAnimation:(BOOL)isPopIn toImage:(NSImage *)image alert:(BOOL)alert;

@property (nonatomic, getter=isAlert) BOOL alert;

@property (nonatomic, assign, getter=isOutlined) BOOL outlined;

@end
