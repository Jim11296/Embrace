// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import "TrackTableView.h"
#import "TrackTableCellView.h"
#import "Preferences.h"

NSString * const EmbraceLockedTrackPasteboardType = @"com.iccir.Embrace.Track.Locked";
NSString * const EmbraceQueuedTrackPasteboardType = @"com.iccir.Embrace.Track.Queued";


extern NSColor * const TrackTableViewGetPlayingTextColor(void)
{
    if ([[Preferences sharedInstance] highlightColorType] == HighlightColorTypeSystem) {
        if (@available(macOS 10.14, *)) {
            BOOL darkAqua = IsAppearanceDarkAqua(nil);

            NSColor *color = [[NSColor selectedContentBackgroundColor] colorUsingType:NSColorTypeComponentBased];
            
            CGFloat saturation = 0;
            
            if ([[color colorSpace] colorSpaceModel] == NSColorSpaceModelRGB) {
                [color getHue:NULL saturation:&saturation brightness:NULL alpha:NULL];
            }

            if (saturation > 0.1) {
                if (darkAqua) {
                    return [[NSColor whiteColor] blendedColorWithFraction:0.5 ofColor:color];
                } else {
                    return [[NSColor blackColor] blendedColorWithFraction:0.9 ofColor:color];
                }
            }
        }
    }
    
    return [NSColor colorNamed:@"SetlistPlayingText"];
}


extern NSColor * const TrackTableViewGetRowHighlightColor(BOOL emphasized)
{
    if (emphasized) {
        if ([[Preferences sharedInstance] highlightColorType] == HighlightColorTypeSystem) {
            if (@available(macOS 10.14, *)) {
                return [NSColor selectedContentBackgroundColor];
            } else {
                return [NSColor secondarySelectedControlColor];
            }
        }

        return [NSColor colorNamed:@"SetlistHighlightBackground"];

    } else {
        if (@available(macOS 10.14, *)) {
            return [NSColor unemphasizedSelectedContentBackgroundColor];
        } else {
            return [NSColor alternateSelectedControlColor];
        }
    }
}


@implementation TrackTableView {
    NSHashTable       *_cellsWithMouseInside;
    NSMutableIndexSet *_rowsNeedingUpdatedHeight;

    BOOL _dragInside;
    BOOL _inLocalDrag;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    _rowWithMouseInside = NSNotFound;
}


- (NSMenu *) menuForEvent:(NSEvent *)theEvent
{
    NSEventType type = [theEvent type];
    
    if (type == NSEventTypeRightMouseDown || type == NSEventTypeRightMouseUp ||
        type == NSEventTypeLeftMouseDown  || type == NSEventTypeLeftMouseUp  ||
        type == NSEventTypeOtherMouseDown || type == NSEventTypeOtherMouseUp)
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


#pragma mark - Private Methods

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
    [self performSelector:@selector(_dispatchHeightUpdate) withObject:nil afterDelay:0.25];

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


- (void) drawGridInClipRect:(NSRect)clipRect
{
    // Do nothing
}


#pragma mark - Dragging

- (void) _updateDrag
{
    id delegate = [self delegate];

    if ([delegate respondsToSelector:@selector(trackTableView:isModifyingViaDrag:)]) {
        [delegate trackTableView:self isModifyingViaDrag:(_inLocalDrag || _dragInside)];
    }
}


- (void) draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint
{
    if ([[NSTableView class] instancesRespondToSelector:@selector(draggingSession:willBeginAtPoint:)]) {
        [super draggingSession:session willBeginAtPoint:screenPoint];
    }

    _inLocalDrag = YES;
    [self _updateDrag];
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


- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender;
{
    NSDragOperation result = [super draggingEntered:sender];

    _dragInside = YES;
    [self _updateDrag];

    return result;
}


- (void) draggingExited:(id <NSDraggingInfo>)sender
{
    if ([[NSTableView class] instancesRespondToSelector:@selector(draggingExited:)]) {
        [super draggingExited:sender];
    }

    _dragInside = NO;
    [self _updateDrag];
}


- (void) draggingEnded:(id <NSDraggingInfo>)sender
{
    if ([[NSTableView class] instancesRespondToSelector:@selector(draggingEnded:)]) {
        [super draggingEnded:sender];
    }
    
    _dragInside = NO;
    _inLocalDrag = NO;
    [self _updateDrag];
}


- (void) concludeDragOperation:(id<NSDraggingInfo>)sender
{
    if ([[NSTableView class] instancesRespondToSelector:@selector(concludeDragOperation:)]) {
        [super concludeDragOperation:sender];
    }

    _dragInside = NO;
    _inLocalDrag = NO;
    [self _updateDrag];
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


@end
