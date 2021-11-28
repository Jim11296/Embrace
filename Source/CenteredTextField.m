// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "CenteredTextField.h"

@implementation CenteredTextField

@end


@implementation CenteredTextFieldCell

- (NSRect) drawingRectForBounds:(NSRect)theRect
{
	NSRect newRect = [super drawingRectForBounds:theRect];

    CGFloat ascender  = [[self font] ascender];
    CGFloat descender = [[self font] descender];

    CGFloat offset = NSHeight(theRect) - (ascender - descender);

    newRect.origin.y += round(offset / 2);
 
	return newRect;
}
@end
