//
//  TracksController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-03-01.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TracksController.h"
#import "Track.h"
#import "ViewTrackController.h"
#import "TrackTableCellView.h"
#import "AppDelegate.h"
#import "Player.h"
#import "Preferences.h"
#import "TrackTableView.h"
#import "iTunesManager.h"

NSString * const TracksControllerDidModifyTracksNotificationName = @"TracksControllerDidModifyTracks";

static NSString * const sTrackUUIDsKey = @"track-uuids";
static NSString * const sModifiedAtKey = @"modified-at";
static NSString * const sTrackPasteboardType = @"com.iccir.Embrace.Track";

@interface TracksController ()
@property (nonatomic) NSUInteger count;
@end


@implementation TracksController {
    BOOL _didInit;
    NSMutableArray *_tracks;
    NSUInteger _rowOfDraggedTrack;
}



- (void) awakeFromNib
{
    if (_didInit) return;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleTableViewSelectionDidChange:) name:NSTableViewSelectionDidChangeNotification object:[self tableView]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];

    [[self tableView] registerForDraggedTypes:@[ NSURLPboardType, NSFilenamesPboardType, sTrackPasteboardType ]];
#if DEBUG
    [[self tableView] setDoubleAction:@selector(viewSelectedTrack:)];
#endif
    
    [self _loadState];
    [[self tableView] reloadData];
    
    _didInit = YES;
}


#pragma mark - Private Methods

- (void) _saveState
{
    NSMutableArray *trackUUIDsArray = [NSMutableArray array];

    for (Track *track in [self tracks]) {
        NSUUID *uuid = [track UUID];
        if (uuid) [trackUUIDsArray addObject:[uuid UUIDString]];
    }

    [[NSUserDefaults standardUserDefaults] setObject:trackUUIDsArray forKey:sTrackUUIDsKey];
}


- (void) _loadState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *tracks = [NSMutableArray array];

    NSArray  *trackUUIDs  = [defaults objectForKey:sTrackUUIDsKey];

    if ([trackUUIDs isKindOfClass:[NSArray class]]) {
        for (NSString *uuidString in trackUUIDs) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
            Track *track = [Track trackWithUUID:uuid];

            if (track) [tracks addObject:track];
            
            if ([track trackStatus] == TrackStatusPlaying) {
                [track setTrackStatus:TrackStatusPlayed];
            }
        }
    }
    
    _tracks = tracks;
}


- (void) _updateInsertionPointWorkaround:(BOOL)yn
{
    [(TrackTableView *)_tableView updateInsertionPointWorkaround:yn];
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    [[self tableView] reloadData];
}


- (void) _handleTableViewSelectionDidChange:(NSNotification *)note
{
    NSIndexSet *selectionIndexes = [[self tableView] selectedRowIndexes];
    
    [[self tableView] enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *view, NSInteger row) {
        TrackTableCellView *trackView = (TrackTableCellView *)[view viewAtColumn:0];
        [trackView setSelected:[selectionIndexes containsIndex:row]];
    }];
}


- (void) _didModifyTracks
{
    NSTimeInterval t = [NSDate timeIntervalSinceReferenceDate];
    [[NSUserDefaults standardUserDefaults] setObject:@(t) forKey:sModifiedAtKey];

    [[NSNotificationCenter defaultCenter] postNotificationName:TracksControllerDidModifyTracksNotificationName object:self];

    [self _saveState];
}


#pragma mark - IBActions

- (IBAction) delete:(id)sender
{
    NSIndexSet *indexSet = [[self tableView] selectedRowIndexes];
    NSMutableIndexSet *indexSetToRemove = [NSMutableIndexSet indexSet];
    
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
        Track *track = [self trackAtIndex:index];
        if (!track) return;

        if ([track trackStatus] == TrackStatusQueued) {
            [track cancelLoad];
            [indexSetToRemove addIndex:index];
        }
    }];
    
    [[self tableView] beginUpdates];

    [[self tableView] removeRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectFade];
    [_tracks removeObjectsAtIndexes:indexSet];

    NSUInteger indexToSelect = [indexSet lastIndex];

    if (indexToSelect >= [_tracks count]) {
        indexToSelect--;
    }

    [[self tableView] selectRowIndexes:[NSIndexSet indexSetWithIndex:indexToSelect] byExtendingSelection:NO];

    [[self tableView] endUpdates];

    [self _didModifyTracks];
}


#pragma mark - Table View Delegate

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_tracks count];
}


- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [_tracks objectAtIndex:row];
}


- (BOOL) tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSArray *tracksToDrag = [_tracks objectsAtIndexes:rowIndexes];
    
    Track *track = [tracksToDrag firstObject];

    if ([track trackStatus] == TrackStatusQueued) {
        [pboard setData:[NSData data] forType:sTrackPasteboardType];
        _rowOfDraggedTrack = [rowIndexes firstIndex];
        return YES;
    }

    return NO;
}


- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    TrackTableCellView *cellView = [tableView makeViewWithIdentifier:@"TrackCell" owner:self];

    NSIndexSet *selectionIndexes = [tableView selectedRowIndexes];
    [cellView setSelected:[selectionIndexes containsIndex:row]];
    
    return cellView;
}


- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    NSInteger numberOfLines = [[Preferences sharedInstance] numberOfLayoutLines];
    
    if (numberOfLines == 1) {
        return 25;
    } else if (numberOfLines == 3) {
        return 56;
    }
    
    return 40;
}


- (void) tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    [self _updateInsertionPointWorkaround:NO];

    if (operation == NSDragOperationNone) {
        NSRect frame = [[[self tableView] window] frame];

        if (!NSPointInRect(screenPoint, frame)) {
            if (_rowOfDraggedTrack != NSNotFound) {
                Track *draggedTrack = [self trackAtIndex:_rowOfDraggedTrack];

                [[self tableView] beginUpdates];

                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:_rowOfDraggedTrack];
                [[self tableView] removeRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectFade];

                if (draggedTrack) {
                    [_tracks removeObject:draggedTrack];
                }

                [[self tableView] endUpdates];
 
                [self _didModifyTracks];
                
                NSShowAnimationEffect(NSAnimationEffectPoof, [NSEvent mouseLocation], NSZeroSize, nil, nil, nil);
            }
        }
    }
}


- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pasteboard = [info draggingPasteboard];
    BOOL isMove = ([pasteboard dataForType:sTrackPasteboardType] != nil);

    [self _updateInsertionPointWorkaround:NO];
    
    if (dropOperation == NSTableViewDropAbove) {
        Track *track = [self trackAtIndex:row];

        if (!track || [track trackStatus] == TrackStatusQueued) {
            if (row == 0) {
                [self _updateInsertionPointWorkaround:YES];
            }

            if (isMove) {
                if ((row == _rowOfDraggedTrack) || (row == (_rowOfDraggedTrack + 1))) {
                    return NSDragOperationNone;
                } else {
                    return NSDragOperationMove;
                }
            
            } else {
                return NSDragOperationCopy;
            }
        }
    }

    if (!isMove && (dropOperation == NSTableViewDropOn)) {
        Track *track = [self trackAtIndex:row];

        if (!track || [track trackStatus] == TrackStatusQueued) {
            [tableView setDropRow:(row + 1) dropOperation:NSTableViewDropAbove];
            return NSDragOperationCopy;
        }
    }
    
    // Always accept a drag from iTunes, target end of table in this case
    if (!isMove) {
        [tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationCopy;
    }

    return NSDragOperationNone;
}


- (BOOL) acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
{
    EmbraceLog(@"TracksController", @"Accepting drop");

    [self _updateInsertionPointWorkaround:NO];

    NSPasteboard *pboard = [info draggingPasteboard];

    if ((row == -1) && (dropOperation == NSTableViewDropOn)) {
        row = [_tracks count];
    }

    NSArray  *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    NSString *URLString = [pboard stringForType:(__bridge NSString *)kUTTypeFileURL];

    // Let manager extract any metadata from the pasteboard 
    [[iTunesManager sharedInstance] extractMetadataFromPasteboard:pboard];

    if ([pboard dataForType:sTrackPasteboardType]) {
        if (_rowOfDraggedTrack < row) {
            row--;
        }

        EmbraceLog(@"TracksController", @"Moving track from %ld to %ld", (long)_rowOfDraggedTrack, row);

        Track *draggedTrack = [self trackAtIndex:_rowOfDraggedTrack];
        [[self tableView] moveRowAtIndex:_rowOfDraggedTrack toIndex:row];
        
        if (draggedTrack) {
            [_tracks removeObject:draggedTrack];
            [_tracks insertObject:draggedTrack atIndex:row];
        }

        [self _didModifyTracks];

        return YES;

    } else if ([filenames count] >= 2) {
        NSMutableArray    *tracks   = [NSMutableArray array];
        NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];

        EmbraceLog(@"TracksController", @"Adding tracks: %@", filenames);
        
        for (NSString *filename in filenames) {
            NSURL *URL = [NSURL fileURLWithPath:filename];

            Track *track = [Track trackWithFileURL:URL];
            if (track) {
                [tracks addObject:track];
                [indexSet addIndex:row];
                
                row++;
            }
        }

        [_tracks insertObjects:tracks atIndexes:indexSet];
        [[self tableView] insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectFade];
        
        [self _didModifyTracks];

        return YES;

    } else if (URLString) {
        NSURL *URL = [NSURL URLWithString:URLString];

        EmbraceLog(@"TracksController", @"Adding track: %@", URL);

        Track *track = [Track trackWithFileURL:URL];
        if (track) {
            [_tracks insertObject:track atIndex:row];
            [[self tableView] insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:NSTableViewAnimationEffectFade];
        }

        [self _didModifyTracks];

        return YES;
    }
    
    return NO;
}


- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
{
    return [self acceptDrop:info row:row dropOperation:dropOperation];
}


#pragma mark - Public

- (void) saveState
{
    [self _saveState];
}


- (Track *) firstQueuedTrack
{
    for (Track *track in _tracks) {
        if ([track trackStatus] == TrackStatusQueued) {
            return track;
        }
    }

    return nil;
}



- (Track *) selectedTrack
{
    NSIndexSet *selectedRows = [[self tableView] selectedRowIndexes];
    
    return [self trackAtIndex:[selectedRows firstIndex]];
}


- (void) addTrackAtURL:(NSURL *)URL
{
    Track *track = [Track trackWithFileURL:URL];

    if (track) {
        [_tracks addObject:track];
        [self _didModifyTracks];
    }
}


- (void) removeAllTracks
{
    NSMutableArray *tracksToRemove = [_tracks mutableCopy];
    Track *trackToKeep = [[Player sharedInstance] currentTrack];

    if (trackToKeep) {
        [tracksToRemove removeObject:trackToKeep];
    }

    for (Track *track in tracksToRemove) {
        [track cancelLoad];
    }

    [_tracks removeObjectsInArray:tracksToRemove];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:sModifiedAtKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"tracks"];

    for (Track *track in tracksToRemove) {
        [track clearAndCleanup];
    }

    if (!trackToKeep) {
        [Track clearPersistedState];
    }

    [[self tableView] deselectAll:nil];
    [[self tableView] reloadData];

    [self _didModifyTracks];
}


- (void) deselectAllTracks
{
    [[self tableView] deselectAll:nil];
}


- (void) resetPlayedTracks
{
    if ([[Player sharedInstance] isPlaying]) return;

    for (Track *track in _tracks) {
        [track setTrackStatus:TrackStatusQueued];
    }
}


- (void) revealEndTimeForTrack:(Track *)track
{
    NSInteger index = [_tracks indexOfObject:track];
    
    if (index != NSNotFound) {
        id view = [[self tableView] viewAtColumn:0 row:index makeIfNecessary:NO];
        
        if ([view respondsToSelector:@selector(revealEndTime)]) {
            [view revealEndTime];
        }
    }
}


- (BOOL) canDeleteSelectedObjects
{
    Track *selectedTrack = [self selectedTrack];
    if (!selectedTrack) return NO;

    if ([selectedTrack trackStatus] == TrackStatusQueued) {
        return YES;
    }
    
    return NO;
}


- (BOOL) canChangeTrackStatusOfTrack:(Track *)track
{
    NSInteger index = [_tracks indexOfObject:track];
    if (index == NSNotFound) {
        return NO;
    }
    
    if ([[Player sharedInstance] currentTrack]) {
        return NO;
    }

    NSInteger count = [_tracks count];
    
    Track *previousTrack = index > 0           ? [_tracks objectAtIndex:(index - 1)] : nil;
    Track *nextTrack     = (index + 1) < count ? [_tracks objectAtIndex:(index + 1)] : nil;
    
    BOOL isPreviousPlayed = !previousTrack || ([previousTrack trackStatus] == TrackStatusPlayed);
    BOOL isNextPlayed     =                    [nextTrack     trackStatus] == TrackStatusPlayed;

    return (isPreviousPlayed != isNextPlayed);
}


- (Track *) trackAtIndex:(NSUInteger)index
{
    if (index < [_tracks count]) {
        return [_tracks objectAtIndex:index];
    }

    return nil;
}


- (IBAction) viewSelectedTrack:(id)sender
{
    NSInteger clickedRow = [[self tableView] clickedRow];

    if (clickedRow >= 0 && clickedRow <= [_tracks count]) {
        Track *track = [_tracks objectAtIndex:clickedRow];
        ViewTrackController *controller = [GetAppDelegate() viewTrackControllerForTrack:track];

        [controller showWindow:self];
    }
}


#pragma mark - Accessors

- (NSTimeInterval) modificationTime
{
    return [[NSUserDefaults standardUserDefaults] doubleForKey:sModifiedAtKey];
}


@end
