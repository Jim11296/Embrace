//
//  PlaylistController
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "PlaylistController.h"
#import "Track.h"
#import "EffectType.h"
#import "Effect.h"
#import "Player.h"
#import "AppDelegate.h"
#import "iTunesManager.h"
#import "TrackTableCellView.h"
#import "Waveform.h"
#import "EditTrackController.h"
#import "WaveformView.h"
#import "BorderedView.h"
#import "Button.h"
#import "MainWindow.h"
#import "LevelMeter.h"
#import "PlayBar.h"
#import "Preferences.h"

#import <AVFoundation/AVFoundation.h>

static NSString * const sTracksKey  = @"tracks";
static NSString * const sTrackPasteboardType = @"com.iccir.MinimalBeat.Track";


@interface PlaylistController () <NSTableViewDelegate, NSTableViewDataSource, PlayerDelegate>

@end

@implementation PlaylistController {
    NSUInteger _rowOfDraggedTrack;
}


- (id) initWithWindow:(NSWindow *)window
{
    if ((self = [super initWithWindow:window])) {
        [self _loadState];
        [[Player sharedInstance] setDelegate:self];
    }

    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *) windowNibName
{
    return @"PlaylistWindow";
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    [(MainWindow *)[self window] setupWithHeaderView:[self headerView] mainView:[[self tableView] enclosingScrollView]];

    [[self tableView] registerForDraggedTypes:@[ NSURLPboardType, NSFilenamesPboardType, sTrackPasteboardType ]];
    [[self tableView] setDoubleAction:@selector(editSelectedTrack:)];
    
    [[self headerView] setBottomBorderColor:[NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0]];
    [[self bottomContainer] setTopBorderColor:[NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleTableViewSelectionDidChange:) name:NSTableViewSelectionDidChangeNotification object:[self tableView]];

    [[self playButton] setImage:[NSImage imageNamed:@"play_template"]];
    [[self gearButton] setImage:[NSImage imageNamed:@"gear_template"]];
    
    [[self tracksController] addObserver:self forKeyPath:@"selectedIndex" options:0 context:NULL];

    [self playerDidUpdate:[Player sharedInstance]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];
    [self _handlePreferencesDidChange:nil];
    
    [self setPlayer:[Player sharedInstance]];
}


#pragma mark - Private Methods

- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    Preferences *preferences = [Preferences sharedInstance];
    
    AudioDevice *device     = [preferences mainOutputAudioDevice];
    double       sampleRate = [preferences mainOutputSampleRate];
    UInt32       frames     = [preferences mainOutputFrames];
    BOOL         hogMode    = [preferences mainOutputUsesHogMode];

    [[Player sharedInstance] updateOutputDevice:device sampleRate:sampleRate frames:frames hogMode:hogMode];
}


- (void) _loadState
{
    NSMutableArray *tracks = [NSMutableArray array];

    NSArray *states = [[NSUserDefaults standardUserDefaults] objectForKey:sTracksKey];

    Track *trackToPlay = nil;

    if ([states isKindOfClass:[NSArray class]]) {
        for (NSDictionary *state in states) {
            Track *track = [Track trackWithStateDictionary:state];
            if (track) [tracks addObject:track];
            
            if ([track trackStatus] == TrackStatusPlaying) {
                trackToPlay = track;
            }
        }
    }
    
    [self setTracks:tracks];
}


- (void) _saveState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSMutableArray *tracksStateArray = [NSMutableArray array];
    for (Track *track in [self tracks]) {
        [tracksStateArray addObject:[track stateDictionary]];
    }
    [defaults setObject:tracksStateArray forKey:sTracksKey];
    
    [defaults synchronize];
}


- (Track *) _selectedTrack
{
    NSArray *tracks = [[self tracksController] selectedObjects];
    return [tracks firstObject];
}


- (BOOL) _canDeleteSelectedObjects
{
    Track *selectedTrack = [self _selectedTrack];

    if ([selectedTrack trackStatus] == TrackStatusQueued) {
        return YES;
    }
    
    return NO;
}


- (BOOL) _canEditSelectedObjects
{
    TrackType type = [[self _selectedTrack] trackType];
    return type == TrackTypeAudioFile;
}


- (BOOL) _canInsertAfterSelectedRow
{
    Track *selectedTrack = [self _selectedTrack];
    if (!selectedTrack) return YES;
    
    if ([selectedTrack trackStatus] == TrackStatusPlayed) {
        NSArray *tracks = [[self tracksController] arrangedObjects];

        // Only allow inserting after a played track if said track is the last
        return [selectedTrack isEqual:[tracks lastObject]];
    }
    
    return YES;
}


- (Track *) _trackAtRow:(NSInteger)row
{
    NSArray *tracks = [[self tracksController] arrangedObjects];
    
    if (row >= [tracks count]) {
        return nil;
    }
    
    if (row < 0) {
        return nil;
    }
    
    return [tracks objectAtIndex:row];
}


#pragma mark - IBActions

- (IBAction) playOrPause:(id)sender
{
    [[Player sharedInstance] play];
}


- (IBAction) changeVolume:(id)sender
{
    [sender setNeedsDisplay];
}


- (IBAction) editSelectedTrack:(id)sender
{

}


- (IBAction) delete:(id)sender
{
    NSArray   *selectedTracks = [[self tracksController] selectedObjects];
    NSUInteger index = [[self tracksController] selectionIndex];
    
    NSMutableArray *tracksToRemove = [NSMutableArray array];

    for (Track *track in selectedTracks){
        if ([track trackStatus] == TrackStatusQueued) {
            [tracksToRemove addObject:track];
        }
    }
    
    [[self tracksController] removeObjects:tracksToRemove];

    if (index >= [[[self tracksController] arrangedObjects] count]) {
        [[self tracksController] setSelectionIndex:(index - 1)];
    } else {
        [[self tracksController] setSelectionIndex:index];
    }
}


- (IBAction) togglePauseAfterPlaying:(id)sender
{
    Track *track = [self _selectedTrack];
    
    if ([track trackStatus] != TrackStatusPlayed) {
        [track updatePausesAfterPlaying:![track pausesAfterPlaying]];
    }
}


- (IBAction) addSilence:(id)sender
{
    Track *track = [Track silenceTrack];

    Track *selectedTrack = [self _selectedTrack];
    NSInteger index = selectedTrack ? [[[self tracksController] arrangedObjects] indexOfObject:selectedTrack] : NSNotFound;

    if (selectedTrack && (index != NSNotFound)) {
        [[self tracksController] insertObject:track atArrangedObjectIndex:(index + 1)];
    } else {
        [[self tracksController] addObject:track];
    }
}

- (IBAction) showGearMenu:(id)sender
{
    NSButton *gearButton = [self gearButton];
    NSMenu *menu = [gearButton menu];
    [NSMenu popUpContextMenu:menu withEvent:[NSApp currentEvent] forView:gearButton];
}


- (IBAction) showEffects:(id)sender
{
    [GetAppDelegate() showEffectsWindow:self];
}


#pragma mark - Menu Validation

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    NSTableView *tableView = [self tableView];

    if ([menuItem menu] == [tableView menu]) {
        NSInteger   clickedRow = [tableView clickedRow];
        NSIndexSet *indexSet   = [NSIndexSet indexSetWithIndex:clickedRow];
    
        [tableView selectRowIndexes:indexSet byExtendingSelection:NO];
    }
    
    SEL action = [menuItem action];

    if (action == @selector(delete:)) {
        return [self _canDeleteSelectedObjects];

    } else if (action == @selector(editSelectedTrack:)) {
        return [self _canEditSelectedObjects];

    } else if (action == @selector(togglePauseAfterPlaying:)) {
        Track *track = [self _selectedTrack];
        [menuItem setState:[track pausesAfterPlaying]];
        return (track != nil);

    } else if (action == @selector(addSilence:)) {
        return [self _canInsertAfterSelectedRow];
    }
    
    return NO;
}


#pragma mark - Table View Delegate

- (BOOL) tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSArray *arrangedObjects = [[self tracksController] arrangedObjects];
    NSArray *tracksToDrag = [arrangedObjects objectsAtIndexes:rowIndexes];
    
    Track *track = [tracksToDrag firstObject];

    if ([track trackStatus] == TrackStatusQueued) {
        [pboard setData:[NSData data] forType:sTrackPasteboardType];
        _rowOfDraggedTrack = [rowIndexes firstIndex];
        return YES;
    }

    return NO;
}


- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
{
    NSPasteboard *pboard = [info draggingPasteboard];

    NSArray  *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    NSString *URLString = [pboard stringForType:(__bridge NSString *)kUTTypeFileURL];

    if ([pboard dataForType:sTrackPasteboardType]) {
        if (_rowOfDraggedTrack < row) {
            row--;
        }

        Track *draggedTrack = [[[self tracksController] arrangedObjects] objectAtIndex:_rowOfDraggedTrack];
        [[self tableView] moveRowAtIndex:_rowOfDraggedTrack toIndex:row];
        
        [[self tracksController] removeObject:draggedTrack];
        [[self tracksController] insertObject:draggedTrack atArrangedObjectIndex:row];
        
        return YES;

    } else if ([filenames count]) {
        for (NSString *filename in filenames) {
            NSURL *URL = [NSURL fileURLWithPath:filename];

            Track *track = [Track trackWithFileURL:URL];
            [[self tracksController] addObject:track];
        }

        return YES;

    } else if (URLString) {
        NSURL *URL = [NSURL URLWithString:URLString];
        
        Track *track = [Track trackWithFileURL:URL];
        [[self tracksController] addObject:track];

        return YES;
    }
    
    return NO;
}


- (NSView *) tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSArray *tracks = [[self tracksController] arrangedObjects];
    Track   *track  = [tracks objectAtIndex:row];
    TrackType trackType = [track trackType];
    
    TrackTableCellView *cellView;

    if (trackType == TrackTypeAudioFile) {
        cellView = [tableView makeViewWithIdentifier:@"TrackCell" owner:self];
    } else if (trackType == TrackTypeSilence) {
        cellView = [tableView makeViewWithIdentifier:@"SilenceCell" owner:self];
    }

    NSUInteger selectedRow = [[self tracksController] selectionIndex];
    [cellView setSelected:(row == selectedRow)];
    
    return cellView;
}


- (CGFloat) tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    NSArray *tracks = [[self tracksController] arrangedObjects];
    Track   *track  = [tracks objectAtIndex:row];
    TrackType trackType = [track trackType];
    
    if (trackType == TrackTypeAudioFile) {
        return 40;
    } else if (trackType == TrackTypeSilence) {
        return 24;
    }

    return 40;
}




- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    if (dropOperation == NSTableViewDropAbove) {
        Track *track = [self _trackAtRow:row];

        if (!track || [track trackStatus] == TrackStatusQueued) {
            return NSDragOperationMove;
        }
    }

    return NSDragOperationNone;

//    return NSDragOperationCopy;
}


- (void) _handleTableViewSelectionDidChange:(NSNotification *)note
{
    NSUInteger selectedRow = [[self tracksController] selectionIndex];
    
    [[self tableView] enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *view, NSInteger row) {
        TrackTableCellView *trackView = (TrackTableCellView *)[view viewAtColumn:0];
        [trackView setSelected:(row == selectedRow)];
    }];
}


- (void) setTracks:(NSArray *)tracks
{
    if (_tracks != tracks) {
        _tracks = tracks;
        [self _saveState];
    }
}


#pragma mark - Other Delegates

- (void) playerDidUpdatePlayState:(Player *)player
{
    Button *playButton = [self playButton];

    if ([player isPlaying]) {
        [playButton setImage:[NSImage imageNamed:@"pause_template"]];
        [playButton setEnabled:[player canPause]];
        
    } else {
        [playButton setImage:[NSImage imageNamed:@"play_template"]];
        [playButton setEnabled:[player canPlay]];
    }
}


- (void) playerDidUpdate:(Player *)player
{
    Track *track = [player currentTrack];
    
    if ([player isPlaying]) {
        [[self levelMeter] updateWithTrack:track];

        [[self playOffsetField]    setStringValue:[track playOffsetString]];
        [[self playRemainingField] setStringValue:[track playRemainingString]];

        float percentage = 0;
        if ([track trackStatus] == TrackStatusPlaying) {
            NSTimeInterval duration = [track playDuration];
            if (!duration) duration = 1;
            percentage = [track playOffset] / duration;
        }


        [[self playBar] setPercentage:percentage];
        [[self playBar] setHidden:NO];
        [[self playOffsetField] setHidden:NO];
        [[self playRemainingField] setHidden:NO];

    } else {
        [[self levelMeter] updateWithTrack:nil];

        [[self playBar] setHidden:YES];
        [[self playOffsetField] setHidden:YES];
        [[self playRemainingField] setHidden:YES];
    }
}

- (Track *) playerNextTrack:(Player *)player
{
    [self _saveState];

    for (Track *track in _tracks) {
        if ([track trackStatus] != TrackStatusPlayed) {
            return track;
        }
    }
    
    return nil;
}



@end
