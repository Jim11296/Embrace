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
#import "ExportManager.h"


#if TRIAL
#define MAXIMUM_TRACK_COUNT_FOR_TRIAL 5

#define TrackTrialCheck(A) {                                                            \
    (A)();                                                                              \
    dispatch_async(dispatch_get_main_queue(), ^{                                        \
        NSTableView *TV = [self tableView];                                             \
        NSIndexSet  *IS = [NSIndexSet indexSetWithIndex:MAXIMUM_TRACK_COUNT_FOR_TRIAL]; \
        while ([_tracks count] > MAXIMUM_TRACK_COUNT_FOR_TRIAL) {                       \
            [TV beginUpdates];                                                          \
            [TV removeRowsAtIndexes:IS withAnimation:NSTableViewAnimationEffectNone];   \
            [_tracks removeObjectsAtIndexes:IS];                                        \
            [TV endUpdates];                                                            \
        }                                                                               \
    });                                                                                 \
}

#else
#define TrackTrialCheck(A) (A)()
#endif


NSString * const TracksControllerDidModifyTracksNotificationName = @"TracksControllerDidModifyTracks";

static NSString * const sTrackUUIDsKey = @"track-uuids";
static NSString * const sModifiedAtKey = @"modified-at";


@interface TracksController ()
@property (nonatomic) NSUInteger count;
@property (nonatomic, weak) IBOutlet TrackTableView *tableView;
@end


@implementation TracksController {
    BOOL _didInit;
    NSMutableArray *_tracks;
    NSIndexSet *_draggedIndexSet;
    BOOL _draggedIndexSetIsContiguous;
}


- (void) awakeFromNib
{
    if (_didInit) return;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleTableViewSelectionDidChange:) name:NSTableViewSelectionDidChangeNotification object:[self tableView]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];

    [[self tableView] registerForDraggedTypes:@[ (__bridge NSString *)kUTTypeFileURL, NSURLPboardType, NSFilenamesPboardType, EmbraceQueuedTrackPasteboardType, EmbraceLockedTrackPasteboardType ]];
#if DEBUG
    [[self tableView] setDoubleAction:@selector(viewClickedTrack:)];
#endif

    NSNib *nib = [[NSNib alloc] initWithNibNamed:@"TrackTableCellView" bundle:nil];
    [[self tableView] registerNib:nib forIdentifier:@"TrackCell"];

    [self _loadState];
    [self _detectDuplicates];
    [[self tableView] reloadData];
    
    _didInit = YES;
}


#pragma mark - Importing Tracks

static NSString *sGetFileType(NSURL *url)
{
    NSString *typeIdentifier = nil;
    NSError  *error = nil;
    [url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:&error];

    return typeIdentifier;
}


static void sCollectURL(NSURL *inURL, NSMutableArray *results, NSInteger depth)
{
    static const NSInteger sMaxDepth = 5;

    if (depth > sMaxDepth) {
        return;
    }
    
    NSString *type = sGetFileType(inURL);
    if (!type) return;

    if (UTTypeConformsTo((__bridge CFStringRef)type, kUTTypeM3UPlaylist)) {
        if (depth < sMaxDepth) {
            sCollectM3UPlaylistURL(inURL, results, depth + 1);
        }

    } else if (UTTypeConformsTo((__bridge CFStringRef)type, kUTTypeFolder)) {
        if (depth < sMaxDepth) {
            sCollectFolderURL(inURL, results, depth + 1);
        }

    } else if (UTTypeConformsTo((__bridge CFStringRef)type, kUTTypeAudiovisualContent) || (depth == 0)) {
        [results addObject:inURL];
    }
}


static void sCollectFolderURL(NSURL *inURL, NSMutableArray *results, NSInteger depth)
{
    NSDirectoryEnumerationOptions options =
        NSDirectoryEnumerationSkipsSubdirectoryDescendants |
        NSDirectoryEnumerationSkipsPackageDescendants |    
        NSDirectoryEnumerationSkipsHiddenFiles;
        
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:inURL includingPropertiesForKeys:@[ NSURLTypeIdentifierKey ] options:options error:&error];

    for (NSURL *url in contents) {
        sCollectURL(url, results, depth);
    }
}


static void sCollectM3UPlaylistURL(NSURL *inURL, NSMutableArray *results, NSInteger depth)
{
    EmbraceLog(@"TrackController", @"Parsing M3U at: %@", inURL);

    NSData *data = [NSData dataWithContentsOfURL:inURL];
    if (!data) return;
    
    NSString *contents = nil;
    if (!contents || [contents length] < 8) {
        EmbraceLog(@"TrackController", @"Trying UTF-8 encoding");
        contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    if (!contents || [contents length] < 8) {
        EmbraceLog(@"TrackController", @"Trying UTF-16 encoding");
        contents = [[NSString alloc] initWithData:data encoding:NSUTF16StringEncoding];
    }

    if (!contents || [contents length] < 8) {
        EmbraceLog(@"TrackController", @"Trying Latin-1 encoding");
        contents = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    
    NSURL *baseURL = [inURL URLByDeletingLastPathComponent];
    
    if ([contents length] >= 8) {
        for (NSString *line in [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            if ([line hasPrefix:@"#"]) {
                continue;

            } else if ([line hasPrefix:@"file:"]) {
                NSURL *url = [NSURL URLWithString:line];
                
                if ([url isFileURL]) {
                    sCollectURL(url, results, depth);
                }
                
            } else {
                NSString *trimmedPath = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSURL *url = [NSURL fileURLWithPath:trimmedPath relativeToURL:baseURL];
                
                if ([url isFileURL]) {
                    sCollectURL(url, results, depth);
                }
            }
        }
    }
}


- (BOOL) _addTracksWithURLs:(NSArray<NSURL *> *)inURLs atIndex:(NSUInteger)index
{
    EmbraceLog(@"TracksController", @"Collecting tracks at URLs: %@", inURLs);

    NSMutableArray *results = [NSMutableArray array];

    for (NSURL *inURL in inURLs) {
        sCollectURL(inURL, results, 0);
    }

    NSInteger resultsCount = [results count];

    EmbraceLog(@"TracksController", @"Found %ld tracks", (long)resultsCount);

    if (resultsCount > 0) {
        BOOL okToAdd = YES;
        
        if (resultsCount > 100) {
            NSAlert *alert = [[NSAlert alloc] init];

            NSString *messageFormat = NSLocalizedString(@"Add %@ Tracks", nil);
            NSString *numberString = [NSNumberFormatter localizedStringFromNumber:@(resultsCount) numberStyle:NSNumberFormatterDecimalStyle];

            [alert setMessageText:[NSString stringWithFormat:messageFormat, numberString]];
            [alert setInformativeText:NSLocalizedString(@"Do you really want to add these tracks to your Set List?", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Add Tracks", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
            
            [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
            okToAdd = ([alert runModal] == NSAlertFirstButtonReturn);

        } else {
            EmbraceLog(@"TracksController", @"Found tracks: %@", results);
        }
        
        if (okToAdd) {
            NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];

            [[self tableView] beginUpdates];

            for (NSURL *url in results) {
                Track *track = [Track trackWithFileURL:url];
                
                if (track) {
                    [_tracks insertObject:track atIndex:index];
                    [indexSet addIndex:index];
                    index++;
                }
            }

            [[self tableView] insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectFade];

            [[self tableView] endUpdates];
            
#if TRIAL
            if ([_tracks count] > MAXIMUM_TRACK_COUNT_FOR_TRIAL) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _displayTrialAlert];
                });
            }
#endif
            
            TrackTrialCheck(^{
                [self _didModifyTracks];
            });

            return YES;
        }
    }

    return NO;
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

    NSArray *trackUUIDs  = [defaults objectForKey:sTrackUUIDsKey];

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


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    TrackTrialCheck(^{
        [[self tableView] reloadData];
    });
}


- (void) _handleTableViewSelectionDidChange:(NSNotification *)note
{
    TrackTrialCheck(^{
        NSIndexSet *selectionIndexes = [[self tableView] selectedRowIndexes];
        
        [[self tableView] enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *view, NSInteger row) {
            TrackTableCellView *trackView = (TrackTableCellView *)[view viewAtColumn:0];
            [trackView setSelected:[selectionIndexes containsIndex:row]];
        }];
    });
}


- (void) _detectDuplicates
{
    NSMutableDictionary *urlToTrackMap        = [NSMutableDictionary dictionaryWithCapacity:[_tracks count]];
    NSMutableDictionary *databaseIDToTrackMap = [NSMutableDictionary dictionaryWithCapacity:[_tracks count]];

    for (Track *track in _tracks) {
        NSInteger databaseID = [track databaseID];
        NSURL *externalURL = [track externalURL];
        BOOL isDuplicate = NO;
        
        if (databaseID) {
            NSNumber *key = @(databaseID);
            Track *existingTrack = [databaseIDToTrackMap objectForKey:key];
            
            if (existingTrack) {
                [existingTrack setDuplicate:YES];
                isDuplicate = YES;
            }

            [databaseIDToTrackMap setObject:track forKey:key];
        }
        
        if (externalURL) {
            Track *existingTrack = [urlToTrackMap objectForKey:externalURL];
            
            if (existingTrack) {
                [existingTrack setDuplicate:YES];
                isDuplicate = YES;
            }
            
            [urlToTrackMap setObject:track forKey:externalURL];
        }
        
        [track setDuplicate:isDuplicate];
    }
}


- (void) _didModifyTracks
{
    TrackTrialCheck(^{
        [self _detectDuplicates];

        NSTimeInterval t = [NSDate timeIntervalSinceReferenceDate];
        [[NSUserDefaults standardUserDefaults] setObject:@(t) forKey:sModifiedAtKey];

        [[NSNotificationCenter defaultCenter] postNotificationName:TracksControllerDidModifyTracksNotificationName object:self];

        [self _saveState];
    });
}


- (BOOL) _isIndexSetContiguous:(NSIndexSet *)indexSet
{
    NSUInteger row = [indexSet firstIndex];
    if (row == NSNotFound) return NO;

    while (row != NSNotFound) {
        NSUInteger nextRow = [indexSet indexGreaterThanIndex:row];
        
        if ((nextRow != NSNotFound) && (nextRow != (row + 1))) {
            return NO;
        }
        
        row = nextRow;
    }

    return YES;
}


#if TRIAL

- (void) _reallyDisplayTrialAlert
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:NSLocalizedString(@"You can only add five songs to the Set List in your trial of Embrace.", nil)];
    [alert setInformativeText:NSLocalizedString(@"To add more, purchase Embrace from the App Store.", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"View in App Store", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert setAlertStyle:NSInformationalAlertStyle];
    
	if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSURL *url = [NSURL URLWithString:@"macappstore://itunes.apple.com/us/app/embrace/id817962217?mt=12"];
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}


- (void) _displayTrialAlert
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reallyDisplayTrialAlert) object:nil];
    [self performSelector:@selector(_reallyDisplayTrialAlert) withObject:nil afterDelay:0.1];
}

#endif


#pragma mark - Table View Delegate

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    __block NSInteger result = 0;
    
    TrackTrialCheck(^{
        result = [_tracks count];
    });
    
    return result;
}


- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    __block id result = nil;

    TrackTrialCheck(^{
        result = [_tracks objectAtIndex:row];
    });
    
    return result;
}


- (BOOL) tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSArray *tracksToDrag = [_tracks objectsAtIndexes:rowIndexes];

    BOOL hasQueued    = NO;
    BOOL hasNotQueued = NO;

    for (Track *track in tracksToDrag) {
        if ([track trackStatus] != TrackStatusQueued) {
            hasNotQueued = YES;
        } else {
            hasQueued = YES;
        }
    }
    
    // Don't allow queued and non-queued
    if (hasNotQueued && hasQueued) {
        return NO;
    }
    
    [pboard setData:[NSData data] forType:(hasQueued ? EmbraceQueuedTrackPasteboardType : EmbraceLockedTrackPasteboardType)];
    _draggedIndexSet = rowIndexes;
    _draggedIndexSetIsContiguous = [self _isIndexSetContiguous:_draggedIndexSet];
    
    return YES;
}


- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    __block NSView *result = nil;

    TrackTrialCheck(^{
        TrackTableCellView *cellView = [tableView makeViewWithIdentifier:@"TrackCell" owner:self];

        NSIndexSet *selectionIndexes = [tableView selectedRowIndexes];
        [cellView setSelected:[selectionIndexes containsIndex:row]];

        result = cellView;
    });
    
    return result;
}


- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    __block CGFloat result = 0;

    const CGFloat kOneLineHeight   = 24;
    const CGFloat kTwoLineHeight   = 39;
    const CGFloat kThreeLineHeight = 56;
    
    TrackTrialCheck(^{
        Preferences *preferences = [Preferences sharedInstance];
        NSInteger numberOfLines = [preferences numberOfLayoutLines];
        BOOL shortensPlayedTracks = [preferences shortensPlayedTracks];
        
        Track *track = [self trackAtIndex:row];
        if (shortensPlayedTracks && ([track trackStatus] == TrackStatusPlayed)) {
        
            if (row != [[self tableView] rowWithMouseInside]) {
                result = kOneLineHeight;
                return;
            }
        }
        
        if (numberOfLines == 1) {
            result = kOneLineHeight;
        } else if (numberOfLines == 3) {
            result = kThreeLineHeight;
        } else {
            result = kTwoLineHeight;
        }
    });

    return result;
}


- (void) tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    [_tableView updateInsertionPointWorkaround:NO];
    [_tableView updateSelectedColorWorkaround:NO];

    if (operation == NSDragOperationNone) {
        NSRect frame = [[[self tableView] window] frame];

        BOOL isLockedTrack = [[session draggingPasteboard] dataForType:EmbraceLockedTrackPasteboardType] != nil;

        if (!NSPointInRect(screenPoint, frame)) {
            if (!isLockedTrack && ([_draggedIndexSet count] != 0)) {
                [[self tableView] beginUpdates];
                [[self tableView] removeRowsAtIndexes:_draggedIndexSet withAnimation:NSTableViewAnimationEffectFade];
                [_tracks removeObjectsAtIndexes:_draggedIndexSet];
                [[self tableView] endUpdates];
 
                [self _didModifyTracks];
                
                NSShowAnimationEffect(NSAnimationEffectPoof, [NSEvent mouseLocation], NSZeroSize, nil, nil, nil);
            }
        }
    }

    _draggedIndexSet = nil;
    _draggedIndexSetIsContiguous = NO;
}


- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pasteboard = [info draggingPasteboard];

    BOOL isLockedTrack   =  ([pasteboard dataForType:EmbraceLockedTrackPasteboardType] != nil);
    BOOL isQueuedTrack   =  ([pasteboard dataForType:EmbraceQueuedTrackPasteboardType] != nil);
    BOOL isExternalTrack = !isLockedTrack && !isQueuedTrack;

    [_tableView updateInsertionPointWorkaround:NO];

    NSDragOperation mask = [info draggingSourceOperationMask];
    BOOL isCopy = (mask & (NSDragOperationGeneric|NSDragOperationCopy)) == NSDragOperationCopy;
    
    if (isExternalTrack) {
        isCopy = YES;
    }
    
    if (dropOperation == NSTableViewDropAbove) {
        Track *track = [self trackAtIndex:row];

        if (!track || [track trackStatus] == TrackStatusQueued) {
            if (row == 0) {
                [_tableView updateInsertionPointWorkaround:YES];
            }

            if (isCopy) {
                [_tableView willDrawInsertionPointAboveRow:row];
                return NSDragOperationCopy;

            } else if (!_draggedIndexSetIsContiguous) {
                [_tableView willDrawInsertionPointAboveRow:row];
                return NSDragOperationGeneric;

            } else if (isQueuedTrack) {
                if ((row >= [_draggedIndexSet firstIndex]) && (row <= ([_draggedIndexSet lastIndex] + 1))) {
                    return NSDragOperationNone;
                } else {
                    [_tableView willDrawInsertionPointAboveRow:row];

                    if (isCopy) {
                        return NSDragOperationCopy;
                    } else {
                        return NSDragOperationGeneric;
                    }
                }

            } else {
                return NSDragOperationNone;
            }
        }
    }

    if (!isQueuedTrack && !isLockedTrack) {
        if (dropOperation == NSTableViewDropOn) {
            Track *track = [self trackAtIndex:row];

            if (!track || [track trackStatus] == TrackStatusQueued) {
                [_tableView setDropRow:(row + 1) dropOperation:NSTableViewDropAbove];
                [_tableView willDrawInsertionPointAboveRow:(row + 1)];
                return NSDragOperationCopy;
            }
        }
    
        // Always accept a drag from iTunes, target end of table in this case
        [tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationCopy;
    }

    return NSDragOperationNone;
}


- (BOOL) acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
{
    EmbraceLog(@"TracksController", @"Accepting drop: %@ -> %ld, %ld", _draggedIndexSet, (long)row, (long)dropOperation);

    NSDragOperation dragOperation = [self tableView:_tableView validateDrop:info proposedRow:row proposedDropOperation:dropOperation];
    [_tableView updateInsertionPointWorkaround:NO];

    NSPasteboard *pboard = [info draggingPasteboard];

    if ((row == -1) && (dropOperation == NSTableViewDropOn)) {
        row = [_tracks count];
    }

    NSArray  *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    NSString *URLString = [pboard stringForType:(__bridge NSString *)kUTTypeFileURL];

    // Let manager extract any metadata from the pasteboard 
    [[iTunesManager sharedInstance] extractMetadataFromPasteboard:pboard];

    if ([pboard dataForType:EmbraceQueuedTrackPasteboardType] ||
        [pboard dataForType:EmbraceLockedTrackPasteboardType])
    {
        [[self tableView] beginUpdates];

        if (dragOperation == NSDragOperationCopy) {
            EmbraceLog(@"TracksController", @"Duplicating track from %@ to %ld", _draggedIndexSet, row);

            NSMutableArray *duplicatedTracks = [NSMutableArray array];
            
            for (Track *oldTrack in [_tracks objectsAtIndexes:_draggedIndexSet]) {
                [duplicatedTracks addObject:[oldTrack duplicatedTrack]];
            }
            
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [duplicatedTracks count])];
            
            [[self tableView] insertRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectFade];
            [_tracks insertObjects:duplicatedTracks atIndexes:indexSet];

        } else if (dragOperation == NSDragOperationGeneric) {
            EmbraceLog(@"TracksController", @"Moving track from %@ to %ld", _draggedIndexSet, row);

            __block NSInteger oldIndexOffset = 0;
            __block NSInteger newIndexOffset = 0;


            [_draggedIndexSet enumerateIndexesUsingBlock:^(NSUInteger oldIndex, BOOL *stop) {
                Track *track = [self trackAtIndex:(oldIndex + oldIndexOffset)];
                
                if (track) {
                    NSInteger toIndex, fromIndex;

                    if (oldIndex < row) {
                        fromIndex = oldIndex + oldIndexOffset;
                        toIndex   = row - 1;
                        oldIndexOffset--;
                    } else {
                        fromIndex = oldIndex;
                        toIndex = row + newIndexOffset;
                        newIndexOffset++;
                    }

                    [_tableView moveRowAtIndex:fromIndex toIndex:toIndex];
                    [_tracks removeObjectAtIndex:fromIndex];
                    [_tracks insertObject:track atIndex:toIndex];
                }
            }];
        }

        TrackTrialCheck(^{
            [self _didModifyTracks];
        });

        [[self tableView] endUpdates];
        
#if TRIAL
        if ([_tracks count] > MAXIMUM_TRACK_COUNT_FOR_TRIAL) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self _displayTrialAlert];
            });
        }
#endif

        return YES;

    } else if ([filenames count] >= 2) {
        NSMutableArray *fileURLs = [NSMutableArray array];

        for (NSString *filename in filenames) {
            NSURL *fileURL = [NSURL fileURLWithPath:filename];
            if (fileURL) [fileURLs addObject:fileURL];
        }
        
        return [self _addTracksWithURLs:fileURLs atIndex:row];

    } else if (URLString) {
        NSURL *fileURL = [NSURL URLWithString:URLString];
        NSArray *fileURLs = fileURL ? @[ fileURL ] : nil;

        return [self _addTracksWithURLs:fileURLs atIndex:row];
    }
 
    return NO;
}


- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
{
    [_tableView updateInsertionPointWorkaround:NO];
    [_tableView updateSelectedColorWorkaround:NO];

    return [self acceptDrop:info row:row dropOperation:dropOperation];
}


- (void) trackTableView:(TrackTableView *)tableView isModifyingViaDrag:(BOOL)isModifyingViaDrag
{
    [[Player sharedInstance] setPreventNextTrack:isModifyingViaDrag];
}


#pragma mark - Menu Item Validation

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(paste:)) {
        return [[NSPasteboard generalPasteboard] canReadItemWithDataConformingToTypes:@[ (__bridge NSString *)kUTTypeFileURL, NSFilenamesPboardType ]];

    } else if (action == @selector(copy:)) {
        return [[self selectedTracks] count] > 0;
    
    } else if (action == @selector(delete:)) {
        return [self _validateDeleteWithMenuItem:menuItem];

    } else if (action == @selector(toggleMarkAsPlayed:)) {
        return [self _validateToggleMarkAsPlayedWithMenuItem:menuItem];
        
    } else if (action == @selector(toggleStopsAfterPlaying:)) {
        return [self _validateToggleStopsAfterPlayingWithMenuItem:menuItem];
 
    } else if (action == @selector(toggleIgnoreAutoGap:)) {
        return [self _validateToggleIgnoreAutoGapWithMenuItem:menuItem];
    
    } else if (action == @selector(revealTime:)) {
        return [self _validateRevealTimeWithMenuItem:menuItem];
    }
    
    return YES;
}


- (BOOL) _validateDeleteWithMenuItem:(NSMenuItem *)menuItem
{
    NSArray *selectedTracks = [self selectedTracks];

    BOOL containsSomething = NO;
    BOOL containsNonQueued = NO;
    BOOL containsAllPlayed = NO;

    if ([selectedTracks count]) {
        containsAllPlayed = YES;
        containsSomething = YES;

        for (Track *track in selectedTracks) {
            TrackStatus trackStatus = [track trackStatus];
            
            containsNonQueued = containsNonQueued || (trackStatus != TrackStatusQueued);
            containsAllPlayed = containsAllPlayed && (trackStatus == TrackStatusPlayed);
        }
    }

    NSString *deleteTitle  = NSLocalizedString(@"Delete", nil);
    NSString *confirmTitle = NSLocalizedString(@"Delete\\U2026", nil);

    if (containsAllPlayed) {
        [menuItem setTitle:confirmTitle];
        return YES;

    } else if (containsNonQueued || !containsSomething) {
        [menuItem setTitle:deleteTitle];
        return NO;
        
    } else {
        [menuItem setTitle:deleteTitle];
        return YES;
    }
}


- (BOOL) _validateToggleStopsAfterPlayingWithMenuItem:(NSMenuItem *)menuItem
{
    NSArray *selectedTracks = [self selectedTracks];
    
    BOOL isEnabled = YES;
    BOOL isOn      = NO;
    BOOL isOff     = NO;
    
    for (Track *track in selectedTracks) {
        BOOL canStop = [track trackStatus] != TrackStatusPlayed;
        if (!canStop) isEnabled = NO;

        BOOL stopsAfterPlaying = (canStop && [track stopsAfterPlaying]);
        if ( stopsAfterPlaying) isOn  = YES;
        if (!stopsAfterPlaying) isOff = YES;
    }
    
    if (isOff && isOn) {
        [menuItem setState:NSMixedState];
        isEnabled = NO;
    } else if (isOn) {
        [menuItem setState:NSOnState];
    } else {
        [menuItem setState:NSOffState];
    }

    return isEnabled;
}


- (BOOL) _validateToggleIgnoreAutoGapWithMenuItem:(NSMenuItem *)menuItem
{
    NSArray *selectedTracks = [self selectedTracks];
    
    BOOL isEnabled = YES;
    BOOL isOn      = NO;
    BOOL isOff     = NO;
    
    for (Track *track in selectedTracks) {
        BOOL canIgnore = [track trackStatus] != TrackStatusPlayed;
        if (!canIgnore) isEnabled = NO;

        BOOL ignoresAutoGap = (canIgnore && [track ignoresAutoGap]);
        if ( ignoresAutoGap) isOn  = YES;
        if (!ignoresAutoGap) isOff = YES;
    }
    
    if (isOff && isOn) {
        [menuItem setState:NSMixedState];
        isEnabled = NO;
    } else if (isOn) {
        [menuItem setState:NSOnState];
    } else {
        [menuItem setState:NSOffState];
    }

    return isEnabled;
}


- (BOOL) _validateToggleMarkAsPlayedWithMenuItem:(NSMenuItem *)menuItem
{
    BOOL isOn = NO;
    BOOL isOff = NO;

    for (Track *track in [self selectedTracks]) {
        if ([track trackStatus] == TrackStatusPlayed) {
            isOn = YES;
        } else {
            isOff = YES;
        }
    }

    if (isOn && isOff) {
        [menuItem setState:NSMixedState];
        return NO;
    } else if (isOn) {
        [menuItem setState:NSOnState];
    } else {
        [menuItem setState:NSOffState];
    }

    if ([[Player sharedInstance] currentTrack]) {
        return NO;
    }

    NSIndexSet *selectedRows = [[self tableView] selectedRowIndexes];

    if (![self _isIndexSetContiguous:selectedRows]) {
        return NO;
    }

    NSInteger firstSelectedRow = [selectedRows firstIndex];
    NSInteger lastSelectedRow  = [selectedRows lastIndex];
    NSInteger count            = [_tracks count];
    
    Track *previousTrack = firstSelectedRow      > 0       ? [_tracks objectAtIndex:(firstSelectedRow - 1)] : nil;
    Track *nextTrack     = (lastSelectedRow + 1) < count   ? [_tracks objectAtIndex:(lastSelectedRow  + 1)] : nil;
    
    BOOL isPreviousPlayed = !previousTrack || ([previousTrack trackStatus] == TrackStatusPlayed);
    BOOL isNextPlayed     =                    [nextTrack     trackStatus] == TrackStatusPlayed;

    return (isPreviousPlayed != isNextPlayed);
}


- (BOOL) _validateRevealTimeWithMenuItem:(NSMenuItem *)menuItem
{
    BOOL hasPlayedTime = NO;
    BOOL hasEndTime    = NO;

    for (Track *track in [self selectedTracks]) {
        if ([track trackStatus] == TrackStatusPlayed) {
            hasPlayedTime = YES;
        } else {
            hasEndTime = YES;
        }
    }

    NSString *title = NSLocalizedString(@"Reveal Time", nil);
    if (hasPlayedTime && !hasEndTime) {
        title = NSLocalizedString(@"Reveal Played Time", nil);
    } else if (!hasPlayedTime && hasEndTime) {
        title = NSLocalizedString(@"Reveal End Time", nil);
    }
    
    [menuItem setTitle:title];

    return [[self selectedTracks] count] > 0;
}


#pragma mark - Selected Track Actions

- (void) delete:(id)sender
{
    BOOL needsPrompt = YES;
    for (Track *track in [self selectedTracks]) {
        needsPrompt = needsPrompt && ([track trackStatus] == TrackStatusPlayed);
    }

    if (needsPrompt) {
        BOOL isSingular = [[self selectedTracks] count] == 1;

        NSString *messageText = isSingular ?
            NSLocalizedString(@"Delete Track",  nil) :
            NSLocalizedString(@"Delete Tracks", nil) ;

        NSString *infoText    = isSingular ? 
            NSLocalizedString(@"Are you sure you want to delete this played track?",   nil) :
            NSLocalizedString(@"Are you sure you want to delete these played tracks?", nil) ;

        NSAlert *alert = [[NSAlert alloc] init];

        [alert setMessageText:messageText];
        [alert setInformativeText:infoText];
        [alert addButtonWithTitle:NSLocalizedString(@"Delete",  nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

        if ([alert runModal] != NSAlertFirstButtonReturn) {
            return;
        }
    }

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


- (void) revealTime:(id)sender
{
    EmbraceLogMethod();

    TrackTrialCheck(^{
        for (Track *track in [self selectedTracks]) {
            NSInteger index = [_tracks indexOfObject:track];
            
            if (index != NSNotFound) {
                id view = [[self tableView] viewAtColumn:0 row:index makeIfNecessary:NO];
                
                if ([view respondsToSelector:@selector(revealTime)]) {
                    [view revealTime];
                }
            }
        }
    });
}


- (void) toggleStopsAfterPlaying:(id)sender
{
    EmbraceLogMethod();

    for (Track *track in [self selectedTracks]) {
        if ([track trackStatus] != TrackStatusPlayed) {
            [track setStopsAfterPlaying:![track stopsAfterPlaying]];
        }
    }
}


- (void) toggleIgnoreAutoGap:(id)sender
{
    EmbraceLogMethod();

    for (Track *track in [self selectedTracks]) {
        if ([track trackStatus] != TrackStatusPlayed) {
            [track setIgnoresAutoGap:![track ignoresAutoGap]];
        }
    }
}


- (void) toggleMarkAsPlayed:(id)sender
{
    // Be paranoid and double-check the validity
    //
    if (![self _validateToggleMarkAsPlayedWithMenuItem:nil]) {
        return;
    }

    for (Track *track in [self selectedTracks]) {
        if ([track trackStatus] == TrackStatusQueued) {
            [track setTrackStatus:TrackStatusPlayed];
        } else if ([track trackStatus] == TrackStatusPlayed) {
            [track setTrackStatus:TrackStatusQueued];
        }
    }
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [context setDuration:0];

        [[self tableView] beginUpdates];
        [[self tableView] noteHeightOfRowsWithIndexesChanged:[[self tableView] selectedRowIndexes]];
        [[self tableView] endUpdates];
    } completionHandler:nil];
}


- (void) didFinishTrack:(Track *)finishedTrack
{
    NSInteger row = finishedTrack ? [_tracks indexOfObject:finishedTrack] : NSNotFound;

    if (row != NSNotFound) {
        [[self tableView] beginUpdates];
        [[self tableView] noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:row]];
        [[self tableView] endUpdates];
    }
}


#pragma mark - Public

- (void) copy:(id)sender
{
    NSArray  *tracks   = [self selectedTracks];
    NSString *contents = [[ExportManager sharedInstance] stringWithFormat:ExportManagerFormatPlainText tracks:tracks];

    NSPasteboardItem *item = [[NSPasteboardItem alloc] initWithPasteboardPropertyList:contents ofType:NSPasteboardTypeString];

    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:[NSArray arrayWithObject:item]];
}


- (void) paste:(id)sender
{
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];

    NSArray  *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    NSString *URLString = [pboard stringForType:(__bridge NSString *)kUTTypeFileURL];

    if (filenames) {
        NSMutableArray *fileURLs = [NSMutableArray array];

        for (NSString *filename in filenames) {
            NSURL *fileURL = [NSURL fileURLWithPath:filename];
            if (fileURL) [fileURLs addObject:fileURL];
        }

        [self addTracksWithURLs:fileURLs];

    } else if (URLString) {
        NSURL *fileURL = [NSURL URLWithString:URLString];

        if (fileURL) {
            [self addTracksWithURLs:@[ fileURL ]];
        }
    }
}


- (void) saveState
{
    [self _saveState];
}


- (Track *) firstQueuedTrack
{
    __block Track *result = nil;

    TrackTrialCheck(^{
        for (Track *track in _tracks) {
            if ([track trackStatus] == TrackStatusQueued) {
                result = track;
                break;
            }
        }
    });

    return result;
}


- (NSArray *) selectedTracks
{
    __block NSArray *result;
    
    TrackTrialCheck(^{
        NSIndexSet *selectedRows = [[self tableView] selectedRowIndexes];
        result = selectedRows ? [_tracks objectsAtIndexes:selectedRows] : nil;
    });

    return result;
}


- (BOOL) addTracksWithURLs:(NSArray<NSURL *> *)fileURLs
{
    NSUInteger index = [_tracks count];
    return [self _addTracksWithURLs:fileURLs atIndex:index];
}


- (void) removeAllTracks
{
    EmbraceLogMethod();

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
    EmbraceLogMethod();

    TrackTrialCheck(^{
        [[self tableView] deselectAll:nil];
    });
}


- (void) resetPlayedTracks
{
    EmbraceLogMethod();

    if ([[Player sharedInstance] isPlaying]) return;

    for (Track *track in _tracks) {
        [track setTrackStatus:TrackStatusQueued];
    }

    [self _didModifyTracks];
}


- (Track *) trackAtIndex:(NSUInteger)index
{
    __block Track *result = nil;
    
    TrackTrialCheck(^{
        if (index < [_tracks count]) {
            result = [_tracks objectAtIndex:index];
        }
    });

    return result;
}


- (IBAction) viewClickedTrack:(id)sender
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
