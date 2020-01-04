// (c) 2018-2020 Ricci Adams.  All rights reserved.

#import <AppKit/AppKit.h>


@interface HairlineView : NSView

@property (nonatomic) NSColor *borderColor;

// Either NSLayoutAttributeTop or NSLayoutAttributeBottom, edge where line is attached
@property (nonatomic) NSLayoutAttribute layoutAttribute;

@end
