//
//  TrackTableView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackTableView.h"

@implementation TrackTableView

- (NSDragOperation) draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    if (context == NSDraggingContextOutsideApplication) {
        return NSDragOperationDelete;
    }
    
    return NSDragOperationMove;
}


- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset
{
    return [NSImage imageNamed:@"drag_icon"];
}


- (void) draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint
{
    NSRect frame = [[self window] frame];

    if (NSPointInRect(screenPoint, frame)) {
        [session setAnimatesToStartingPositionsOnCancelOrFail:YES];
        [[NSCursor arrowCursor] set];

    } else {
        [[NSCursor disappearingItemCursor] set];
        [session setAnimatesToStartingPositionsOnCancelOrFail:NO];
    }

}


@end
