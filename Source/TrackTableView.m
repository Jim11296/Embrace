// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "TrackTableView.h"
#import "TrackTableCellView.h"


NSString * const EmbraceLockedTrackPasteboardType = @"com.iccir.Embrace.Track.Locked";
NSString * const EmbraceQueuedTrackPasteboardType = @"com.iccir.Embrace.Track.Queued";


@implementation TrackTableView {
    NSHashTable       *_cellsWithMouseInside;
    NSMutableIndexSet *_rowsNeedingUpdatedHeight;

    BOOL _dragInside;
    BOOL _inLocalDrag;
}


- (instancetype) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self _commonTrackTableViewInit];
    }
    
    return self;
}


- (instancetype) initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self _commonTrackTableViewInit];
    }
    
    return self;
}


- (void) _commonTrackTableViewInit
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleControlTintDidChange:) name:NSControlTintDidChangeNotification object:nil];
    [self _updatePlayingTextColor];
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) viewDidChangeEffectiveAppearance
{
    PerformWithAppearance([self effectiveAppearance], ^{
        [self _updatePlayingTextColor];
    });
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

- (void) _handleControlTintDidChange:(NSNotification *)note
{
    // As of 10.14 beta 2, -viewDidChangeEffectiveAppearance is rarely
    // called for control accent color changes. Hence, we listen for this
    // notification.
    
    [self _updatePlayingTextColor];
}


- (void) _updatePlayingTextColor
{
    NSColor *playingTextColor = nil;

    NSColor *(^getColorWithHue)(CGFloat, NSArray<NSNumber *> *) = ^(CGFloat normalizedHue, NSArray<NSNumber *> *values) {
        CGFloat hue = fmod(normalizedHue * 360.0, 360.0);

        CGFloat keys[] = { -2.0, 28.0, 41.0, 106.0, 214.0, 299.0,  332.0, 358.0, 388.0 };

        NSColor *result = nil;

        if ([values count] == 14) {
            for (NSInteger i = 0; i < 8; i++) {
                CGFloat keyA = keys[i];
                CGFloat keyB = keys[i+1];
                
                if (hue >= keyA && hue <= keyB) {
                    CGFloat sA = [[values objectAtIndex:((i*2)+0) % 14] doubleValue];
                    CGFloat sB = [[values objectAtIndex:((i*2)+2) % 14] doubleValue];

                    CGFloat bA = [[values objectAtIndex:((i*2)+1) % 14] doubleValue];
                    CGFloat bB = [[values objectAtIndex:((i*2)+3) % 14] doubleValue];

                    CGFloat multiplier = (hue - keyA) / (keyB - keyA);
                    CGFloat saturation = sA + ((sB - sA) * multiplier);
                    CGFloat brightness = bA + ((bB - bA) * multiplier);
                    
                    result = [NSColor colorWithHue:normalizedHue saturation:saturation brightness:brightness alpha:1.0];
                    break;
                }
            }
        }

        return result;
    };


    if (@available(macOS 10.14, *)) {
        NSColor *controlAccentColor = [[NSColor selectedContentBackgroundColor] colorUsingType:NSColorTypeComponentBased];

        CGFloat hue;
        [controlAccentColor getHue:&hue saturation:NULL brightness:NULL alpha:NULL];
        
        if (IsAppearanceDarkAqua(self)) {
            playingTextColor = getColorWithHue(hue, @[
                @0.70, @0.95, /* Red    */
                @0.75, @0.90, /* Orange */
                @0.70, @0.85, /* Yellow */
                @0.60, @0.75, /* Green  */
                @0.60, @1.00, /* Blue   */
                @0.40, @0.85, /* Purple */
                @0.60, @0.95  /* Pink   */
            ]);

        } else {
            playingTextColor = getColorWithHue(hue, @[
                @1.0,  @0.9,   /* Red    */
                @1.0,  @0.8,   /* Orange */
                @1.0,  @0.75,  /* Yellow */
                @1.0,  @0.55,  /* Green  */
                @1.0,  @0.9,   /* Blue   */
                @1.0,  @0.55,  /* Purple */
                @1.0,  @0.9    /* Pink   */
            ]);
        }
    }
    
    if (!playingTextColor) {
        playingTextColor = [Theme colorNamed:@"SetlistPlayingTextFallback"];
    }

    _playingTextColor = playingTextColor;

    [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
        [[rowView viewAtColumn:0] updateColors];
    }];
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
