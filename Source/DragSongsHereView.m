// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "DragSongsHereView.h"


@implementation DragSongsHereView


- (void) drawRect:(NSRect)dirtyRect
{
    NSImage *image = [NSImage imageNamed:@"DragSongsHere"];
    
    CGRect bounds = [self bounds];
    
    CGRect fromRect = CGRectZero;
    fromRect.size = [image size];
    
    CGRect toRect = [self bounds];
    toRect.size = fromRect.size;
    toRect.origin.x = round((bounds.size.width  - toRect.size.width)  / 2.0);
    toRect.origin.y = round((bounds.size.height - toRect.size.height) / 2.0);
    
    [[NSColor secondaryLabelColor] set];
    NSRectFill(toRect);
    
    [image drawInRect:toRect fromRect:fromRect operation:NSCompositingOperationDestinationIn fraction:1.0];
}


@end
