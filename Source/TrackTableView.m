//
//  TrackTableView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackTableView.h"
#import "TrackTableCellView.h"

NSString * const EmbraceLockedTrackPasteboardType = @"com.iccir.Embrace.Track.Locked";
NSString * const EmbraceQueuedTrackPasteboardType = @"com.iccir.Embrace.Track.Queued";


@implementation TrackTableView {
    NSHashTable       *_cellsWithMouseInside;
    NSMutableIndexSet *_rowsNeedingUpdatedHeight;
}

- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    _rowWithMouseInside = NSNotFound;
}


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
        
        if ([[self selectedRowIndexes] containsIndex:row]) {
            return [self menu];

        } else if (row >= 0) {
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            return [self menu];

        } else {
            [self deselectAll:self];
            return nil;
        }
    }


    return [super menuForEvent:theEvent];
}

- (void) updateSelectedColorWorkaround:(BOOL)yn
{
    [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
        NSInteger numberOfColumns = [rowView numberOfColumns];

        for (NSInteger i = 0; i < numberOfColumns; i++) {
            id view = [rowView viewAtColumn:i];

            if ([view respondsToSelector:@selector(setDrawsLighterSelectedBackground:)]) {
                [view setDrawsLighterSelectedBackground:yn];
            }
        }
    }];
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


- (void) willDrawInsertionPointAboveRow:(NSInteger)row
{
    [[self selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        if ((index == row) || (index == (row - 1))) {
            [self updateSelectedColorWorkaround:YES];
        }
    }];
}


- (NSDragOperation) draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    if (context == NSDraggingContextOutsideApplication) {
        return NSDragOperationDelete;
    }
    
    return NSDragOperationCopy|NSDragOperationGeneric;
}


- (NSImage *) dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset
{
    return [NSImage imageNamed:@"DragIcon"];
}


- (void) draggingExited:(id <NSDraggingInfo>)sender
{
    [super draggingExited:sender];
    [self updateInsertionPointWorkaround:NO];
}


- (void) draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint
{
    NSRect frame = [[self window] frame];

    BOOL isLockedTrack = [[session draggingPasteboard] dataForType:EmbraceLockedTrackPasteboardType] != nil;

    if (NSPointInRect(screenPoint, frame)) {
        [session setAnimatesToStartingPositionsOnCancelOrFail:YES];

    } else {
        if (isLockedTrack) {
            [[NSCursor operationNotAllowedCursor] set];
            [session setAnimatesToStartingPositionsOnCancelOrFail:YES];

        } else {
            [[NSCursor disappearingItemCursor] set];
            [session setAnimatesToStartingPositionsOnCancelOrFail:NO];
        }
    }
}


- (void) _dispatchHeightUpdate
{
    if ([_rowsNeedingUpdatedHeight count]) {
        [self beginUpdates];

        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
            [[rowView viewAtColumn:0] setExpandedPlayedTrack:(row == _rowWithMouseInside)];
        }];

        [self noteHeightOfRowsWithIndexesChanged:_rowsNeedingUpdatedHeight];
        [self endUpdates];
    }

    _rowsNeedingUpdatedHeight = nil;
}


- (void) _trackTableViewCell:(TrackTableCellView *)cellView mouseInside:(BOOL)mouseInside
{
    if (!_cellsWithMouseInside) {
        _cellsWithMouseInside = [NSHashTable weakObjectsHashTable];
    }

    if (!_rowsNeedingUpdatedHeight) {
        _rowsNeedingUpdatedHeight = [NSMutableIndexSet indexSet];
    }

    NSInteger row = [self rowForView:cellView];
    if (row != NSNotFound) {
        [_rowsNeedingUpdatedHeight addIndex:row];
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dispatchHeightUpdate) object:nil];
    [self performSelector:@selector(_dispatchHeightUpdate) withObject:nil afterDelay:0.2];

    if (mouseInside) {
        [_cellsWithMouseInside addObject:cellView];
    } else {
        [_cellsWithMouseInside removeObject:cellView];
    }

    NSInteger rowWithMouseInside = _rowWithMouseInside;
    NSInteger count = [_cellsWithMouseInside count];

    if (count == 1) {
        rowWithMouseInside = [self rowForView:[_cellsWithMouseInside anyObject]];
    } else if (count == 0) {
        rowWithMouseInside = NSNotFound;
    }

    _rowWithMouseInside = rowWithMouseInside;
}


@end
