// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "DragSongsHereView.h"


@implementation DragSongsHereView

- (BOOL) wantsUpdateLayer
{
    return YES;
}


- (void) updateLayer
{
    [[self layer] setContents:[NSImage imageNamed:@"DragSongsHere"]];
}

@end
