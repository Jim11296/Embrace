// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "TrackTableRowView.h"
#import "TrackTableView.h"


@implementation TrackTableRowView


- (void) drawSelectionInRect:(NSRect)dirtyRect
{
    BOOL emphasized = ([self interiorBackgroundStyle] == NSBackgroundStyleEmphasized);

    [TrackTableViewGetRowHighlightColor(emphasized) set];

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
