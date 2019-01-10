// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import "TrackTableRowView.h"


@implementation TrackTableRowView


- (void) drawSelectionInRect:(NSRect)dirtyRect
{
    if ([self interiorBackgroundStyle] == NSBackgroundStyleEmphasized) {
        if (@available(macOS 10.14, *)) {
            [[NSColor selectedContentBackgroundColor] set];
        } else {
            [[NSColor alternateSelectedControlColor] set];
        }
    } else {
        if (@available(macOS 10.14, *)) {
            [[NSColor unemphasizedSelectedContentBackgroundColor] set];
        } else {
            [[NSColor secondarySelectedControlColor] set];
        }

    }

    NSRectFillUsingOperation([self bounds], NSCompositingOperationSourceOver);
}


- (void) drawSeparatorInRect:(NSRect)dirtyRect
{
    if ([self isSelected]) return;

    CGFloat scale = [[self window] backingScaleFactor];
    if (!scale) scale = 1;
    
    CGFloat onePixel = 1.0 / scale;
    
    CGRect rect = [self bounds];
    rect.origin.y = rect.size.height - onePixel;
    rect.size.height = onePixel;
    
    NSRectClip(dirtyRect);
    [[NSColor colorNamed:@"SetlistSeparator"] set];
    NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
}


@end
