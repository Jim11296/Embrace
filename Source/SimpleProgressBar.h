// (c) 2017-2018 Ricci Adams.  All rights reserved.

#import <AppKit/AppKit.h>


@interface SimpleProgressBar : NSView <EmbraceWindowListener>

@property (nonatomic) CGFloat percentage;

@property (nonatomic, getter=isRounded) BOOL rounded;

@end
