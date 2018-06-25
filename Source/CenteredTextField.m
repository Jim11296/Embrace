// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "CenteredTextField.h"

@implementation CenteredTextField

@end


@implementation CenteredTextFieldCell

- (NSRect) drawingRectForBounds:(NSRect)theRect
{
	NSRect newRect = [super drawingRectForBounds:theRect];

    NSSize textSize = [self cellSizeForBounds:theRect];

    // Center that in the proposed rect
    float heightDelta = newRect.size.height - textSize.height;	
    if (heightDelta > 0)
    {
        newRect.size.height -= heightDelta;
        newRect.origin.y += (heightDelta / 2) - 2;
    }
	
	return newRect;
}
@end
