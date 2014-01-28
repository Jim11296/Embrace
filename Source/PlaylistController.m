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
#import "TrackData.h"
#import "WaveformView.h"
#import "BorderedView.h"
#import "Button.h"
#import "WhiteWindow.h"
#import "LevelMeter.h"
#import "PlayBar.h"
#import "Preferences.h"

#import <AVFoundation/AVFoundation.h>

static NSString * const sTracksKey = @"tracks";
static NSString * const sMinimumSilenceKey = @"minimum-silence";
static NSString * const sTrackPasteboardType = @"com.iccir.Embrace.Track";


@interface PlaylistController () <NSTableViewDelegate, NSTableViewDataSource, PlayerListener, PlayerTrackProvider>

@end

@implementation PlaylistController {
    NSUInteger _rowOfDraggedTrack;
}


- (id) initWithWindow:(NSWindow *)window
{
    if ((self = [super initWithWindow:window])) {
        [self _loadState];
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

    [(WhiteWindow *)[self window] setupWithHeaderView:[self headerView] mainView:[[self tableView] enclosingScrollView]];

    [[self tableView] registerForDraggedTypes:@[ NSURLPboardType, NSFilenamesPboardType, sTrackPasteboardType ]];
    [[self tableView] setDoubleAction:@selector(editSelectedTrack:)];
    
    [[self headerView] setBottomBorderColor:[NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0]];
    [[self bottomContainer] setTopBorderColor:[NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleTableViewSelectionDidChange:) name:NSTableViewSelectionDidChangeNotification object:[self tableView]];

    [[self playButton] setImage:[NSImage imageNamed:@"play_template"]];
    [[self gearButton] setImage:[NSImage imageNamed:@"gear_template"]];
    
    [[self tracksController] addObserver:self forKeyPath:@"selectedIndex" options:0 context:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];
    [self _handlePreferencesDidChange:nil];
    
    [self setPlayer:[Player sharedInstance]];
    [self _setupPlayer];
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *tracks = [NSMutableArray array];

    NSArray  *states  = [defaults objectForKey:sTracksKey];
    NSTimeInterval silence = [defaults doubleForKey:sMinimumSilenceKey];

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
    
    [self setMinimumSilenceBetweenTracks:silence];
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
    [defaults setDouble:_minimumSilenceBetweenTracks forKey:sMinimumSilenceKey];
    
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


- (NSString *) _historyAsString
{
    NSMutableString *result = [NSMutableString string];

    for (Track *track in [[self tracksController] arrangedObjects]) {
        if ([track trackStatus] == TrackStatusQueued) continue;
        if ([track trackType] != TrackTypeAudioFile) continue;

        NSString *artist = [track artist];
        if (artist) [result appendFormat:@"%@ %C ", artist, (unichar)0x2014];
        
        NSString *title = [track title];
        if (!title) title = @"???";
        [result appendFormat:@"%@\n", title];
    }
    
    return result;
}


#pragma mark - Debug

- (void) debugPopulatePlaylist
{
    Track *(^getTrack)(NSString *) = ^(NSString *name) {
        NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"m4a"];
        NSURL *url = [NSURL fileURLWithPath:path];
        
        return [Track trackWithFileURL:url];
    };
    
    NSMutableArray *tracks = [NSMutableArray array];
    [tracks addObject:getTrack(@"test_c")];
    [tracks addObject:getTrack(@"test_d")];
    [tracks addObject:getTrack(@"test_e")];
    [tracks addObject:getTrack(@"test_f")];
    [tracks addObject:getTrack(@"test_g")];
    
    [self clearHistory];
    [[self tracksController] addObjects:tracks];
}



#pragma mark - Public Methods

- (void) clearHistory
{
    NSArrayController *tracksController = [self tracksController];

    NSArray *tracks = [tracksController arrangedObjects];
    [tracksController removeObjects:tracks];
    [tracksController setSelectionIndexes:[NSIndexSet indexSet]];
}


- (void) openFileAtURL:(NSURL *)URL
{
    Track *track = [Track trackWithFileURL:URL];
    [[self tracksController] addObject:track];
}


- (void) copyHistoryToPasteboard:(NSPasteboard *)pasteboard
{
    NSString *history = [self _historyAsString];

    NSPasteboardItem *item = [[NSPasteboardItem alloc] initWithPasteboardPropertyList:history ofType:NSPasteboardTypeString];

    [pasteboard clearContents];
    [pasteboard writeObjects:[NSArray arrayWithObject:item]];
}


- (void) saveHistoryToFileAtURL:(NSURL *)url
{
    NSString *historyContents = [self _historyAsString];

    NSError *error = nil;
    [historyContents writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        NSLog(@"Error saving history: %@", error);
        NSBeep();
    }
}


- (void) exportHistory
{
    NSMutableArray *fileURLs = [NSMutableArray array];
    
    for (Track *track in _tracks) {
        if ([track fileURL]) {
            [fileURLs addObject:[track fileURL]];
        }
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterLongStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    
    NSMutableString *name = [NSMutableString string];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    [name appendFormat:@"%@ (%@)", NSLocalizedString(@"Embrace", nil), dateString];
    
    [[iTunesManager sharedInstance] exportPlaylistWithName:name fileURLs:fileURLs];
}


#pragma mark - IBActions

- (IBAction) playOrSoftPause:(id)sender
{
    [[Player sharedInstance] playOrSoftPause];
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
        [track setPausesAfterPlaying:![track pausesAfterPlaying]];
    }
}


- (IBAction) addSilence:(id)sender
{
    Track *track = [SilentTrack silenceTrack];

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


- (IBAction) showCurrentTrack:(id)sender
{
    [GetAppDelegate() showCurrentTrack:self];
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


#pragma mark - Player

- (void) _setupPlayer
{
    Player *player = [Player sharedInstance];


    [player addListener:self];
    [player setTrackProvider:self];

    [self player:player didUpdatePlaying:NO];
}


- (void) player:(Player *)player didUpdatePlaying:(BOOL)playing
{
    Button *playButton = [self playButton];

    if (playing) {
        [playButton setImage:[NSImage imageNamed:@"pause_template"]];

        [[self playBar] setHidden:NO];
        [[self playOffsetField] setHidden:NO];
        [[self playRemainingField] setHidden:NO];

        [[self levelMeter] setMetering:YES];
        
    } else {
        [playButton setImage:[NSImage imageNamed:@"play_template"]];

        [[self playBar] setHidden:YES];
        [[self playOffsetField] setHidden:YES];
        [[self playRemainingField] setHidden:YES];

        [[self levelMeter] setMetering:NO];
    }
}

- (void) playerDidTick:(Player *)player
{
    Track *track = [player currentTrack];
    
    NSTimeInterval timeElapsed   = [player timeElapsed];
    NSTimeInterval timeRemaining = [player timeRemaining];

    Float32 leftAveragePower  = [player leftAveragePower];
    Float32 rightAveragePower = [player rightAveragePower];
    Float32 leftPeakPower     = [player leftPeakPower];
    Float32 rightPeakPower    = [player rightPeakPower];
    
    NSTimeInterval duration = timeElapsed + timeRemaining;
    if (!duration) duration = 1;
    
    double percentage = 0;
    if (timeElapsed > 0) {
        percentage = timeElapsed / duration;
    }

    [[self playBar] setPercentage:percentage];
    [[self levelMeter] setLeftAveragePower:leftAveragePower rightAveragePower:rightAveragePower leftPeakPower:leftPeakPower rightPeakPower:rightPeakPower];

    BOOL silent = [track isSilentAtOffset:timeElapsed];
    [[self playButton] setEnabled:silent];
}


- (void) player:(Player *)player getNextTrack:(Track **)outNextTrack getPadding:(NSTimeInterval *)outPadding
{
    Track *currentTrack = [player currentTrack];

    [self _saveState];

    Track *trackToPlay = nil;
    NSTimeInterval padding = 0;
    
    for (Track *track in _tracks) {
        if ([track trackStatus] != TrackStatusPlayed) {
            trackToPlay = track;
            break;
        }
    }
    
    if (currentTrack && trackToPlay) {
        NSTimeInterval totalSilence = [currentTrack silenceAtEnd] + [trackToPlay silenceAtStart];
        padding = [self minimumSilenceBetweenTracks] - totalSilence;
        if (padding < 0) padding = 0;
    }
    
    *outNextTrack = trackToPlay;
    *outPadding   = padding;
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

    NSIndexSet *selectionIndexes = [[self tracksController] selectionIndexes];
    [cellView setSelected:[selectionIndexes containsIndex:row]];
    
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
    NSPasteboard *pasteboard = [info draggingPasteboard];
    BOOL isMove = ([pasteboard dataForType:sTrackPasteboardType] != nil);

    if (dropOperation == NSTableViewDropAbove) {
        Track *track = [self _trackAtRow:row];

        if (!track || [track trackStatus] == TrackStatusQueued) {
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
        Track *track = [self _trackAtRow:row];

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


- (BOOL) tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
{
    NSPasteboard *pboard = [info draggingPasteboard];

    if ((row == -1) && (dropOperation == NSTableViewDropOn)) {
        row = [[[self tracksController] arrangedObjects] count];
        dropOperation = NSTableViewDropAbove;
    }

    NSArray  *filenames = [pboard propertyListForType:NSFilenamesPboardType];
    NSString *URLString = [pboard stringForType:(__bridge NSString *)kUTTypeFileURL];

    // Let manager extract any metadata from the pasteboard 
    [[iTunesManager sharedInstance] extractMetadataFromPasteboard:pboard];

    if ([pboard dataForType:sTrackPasteboardType]) {
        if (_rowOfDraggedTrack < row) {
            row--;
        }

        Track *draggedTrack = [[[self tracksController] arrangedObjects] objectAtIndex:_rowOfDraggedTrack];
        [[self tableView] moveRowAtIndex:_rowOfDraggedTrack toIndex:row];
        
        [[self tracksController] removeObject:draggedTrack];
        [[self tracksController] insertObject:draggedTrack atArrangedObjectIndex:row];
        
        return YES;

    } else if ([filenames count] >= 2) {
        for (NSString *filename in [filenames reverseObjectEnumerator]) {
            NSURL *URL = [NSURL fileURLWithPath:filename];

            Track *track = [Track trackWithFileURL:URL];
            [[self tracksController] insertObject:track atArrangedObjectIndex:row];
        }

        return YES;

    } else if (URLString) {
        NSURL *URL = [NSURL URLWithString:URLString];

        Track *track = [Track trackWithFileURL:URL];
        [[self tracksController] insertObject:track atArrangedObjectIndex:row];

        return YES;
    }
    
    return NO;
}


- (void) _handleTableViewSelectionDidChange:(NSNotification *)note
{
    NSIndexSet *selectionIndexes = [[self tracksController] selectionIndexes];
    
    [[self tableView] enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *view, NSInteger row) {
        TrackTableCellView *trackView = (TrackTableCellView *)[view viewAtColumn:0];
        [trackView setSelected:[selectionIndexes containsIndex:row]];
    }];
}


- (void) setTracks:(NSArray *)tracks
{
    if (_tracks != tracks) {
        _tracks = tracks;
        [self _saveState];
    }
}


@end
