//
//  TrackTableView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackTableView.h"
#import "TrackTableCellView.h"


@implementation TrackTableView

- (NSMenu *) menuForEvent:(NSEvent *)theEvent
{
    NSEventType type = [theEvent type];
    
    if (type == NSRightMouseDown || type == NSRightMouseUp ||
        type == NSLeftMouseDown  || type == NSLeftMouseUp  ||
        type == NSOtherMouseDown || type == NSOtherMouseUp)
    {
        NSPoint location = [theEvent locationInWindow];
        
        location = [self convertPoint:location fromView:nil];
        NSInteger row = [self rowAtPoint:location];
        
        if (row >= 0) {
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            return [self menu];
        } else {
            [self deselectAll:self];
            return nil;
        }
    }


    return [super menuForEvent:theEvent];
}


- (void) updateInsertionPointWorkaround:(BOOL)yn
{
    [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
        NSInteger numberOfColumns = [rowView numberOfColumns];

        BOOL workaround = yn && (row == 0);

        for (NSInteger i = 0; i < numberOfColumns; i++) {
            id view = [rowView viewAtColumn:i];

            if ([view respondsToSelector:@selector(setDrawsInsertionPointWorkaround:)]) {
                [view setDrawsInsertionPointWorkaround:workaround];
            }
        }
    }];
}


- (NSDragOperation) draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    if (context == NSDraggingContextOutsideApplication) {
        return NSDragOperationDelete;
    }
    
    return NSDragOperationMove;
}


- (NSImage *) dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset
{
    return [NSImage imageNamed:@"drag_icon"];
}


- (void) draggingExited:(id <NSDraggingInfo>)sender
{
    [super draggingExited:sender];
    [self updateInsertionPointWorkaround:NO];
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
