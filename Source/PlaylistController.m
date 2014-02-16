//
//  PlaylistController
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "PlaylistController.h"

#import "AudioDevice.h"
#import "WrappedAudioDevice.h"

#import "Track.h"
#import "EffectType.h"
#import "Effect.h"
#import "Player.h"
#import "AppDelegate.h"
#import "iTunesManager.h"
#import "TrackTableCellView.h"
#import "WaveformView.h"
#import "BorderedView.h"
#import "Button.h"
#import "WhiteWindow.h"
#import "LevelMeter.h"
#import "PlayBar.h"
#import "Preferences.h"
#import "ShadowView.h"
#import "ViewTrackController.h"
#import "TrackTableView.h"
#import "WhiteSlider.h"

#import <AVFoundation/AVFoundation.h>

static NSString * const sTracksKey = @"tracks";
static NSString * const sMinimumSilenceKey = @"minimum-silence";
static NSString * const sTrackPasteboardType = @"com.iccir.Embrace.Track";

static NSTimeInterval sAutoGapMinimum = 0;
static NSTimeInterval sAutoGapMaximum = 15.0;


@interface PlaylistController () <NSTableViewDelegate, NSTableViewDataSource, PlayerListener, PlayerTrackProvider, WhiteSliderDragDelegate>

@end

@implementation PlaylistController {
    NSUInteger _rowOfDraggedTrack;
    BOOL       _inVolumeDrag;
    
    double     _volumeBeforeAutoPause;
    BOOL       _didAutoPause;
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
    [[self tracksController] removeObserver:self forKeyPath:@"arrangedObjects"];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *) windowNibName
{
    return @"PlaylistWindow";
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    [(WhiteWindow *)[self window] setupWithHeaderView:[self headerView] mainView:[self mainView]];
    
    [[self tableView] registerForDraggedTypes:@[ NSURLPboardType, NSFilenamesPboardType, sTrackPasteboardType ]];
#if DEBUG
    [[self tableView] setDoubleAction:@selector(viewSelectedTrack:)];
#endif

    [[self headerView] setBottomBorderColor:[NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0]];
    [[self bottomContainer] setTopBorderColor:[NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleTableViewSelectionDidChange:) name:NSTableViewSelectionDidChangeNotification object:[self tableView]];

    [[self playButton] setImage:[NSImage imageNamed:@"play_template"]];
    [[self gearButton] setImage:[NSImage imageNamed:@"gear_template"]];
    
    [[self tracksController] addObserver:self forKeyPath:@"arrangedObjects" options:0 context:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:) name:PreferencesDidChangeNotification object:nil];
    [self _handlePreferencesDidChange:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleTrackDidUpdate:) name:TrackDidUpdateNotification object:nil];
    
    // Add top and bottom shadows
    {
        NSRect mainBounds = [[self mainView] bounds];

        NSRect topShadowFrame    = NSMakeRect(0, 0, mainBounds.size.width, 4);
        NSRect bottomShadowFrame = NSMakeRect(0, 0, mainBounds.size.width, 4);
        
        bottomShadowFrame.origin.y = NSMinY([[[self tableView] enclosingScrollView] frame]);

        topShadowFrame.origin.y = mainBounds.size.height - 4;
        
        ShadowView *topShadow    = [[ShadowView alloc] initWithFrame:topShadowFrame];
        ShadowView *bottomShadow = [[ShadowView alloc] initWithFrame:bottomShadowFrame];
        
        [topShadow setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin];
        [bottomShadow setAutoresizingMask:NSViewWidthSizable|NSViewMaxYMargin];
        
        [bottomShadow setFlipped:YES];
        
        [[self mainView] addSubview:topShadow];
        [[self mainView] addSubview:bottomShadow];
        
        [(WhiteWindow *)[self window] setHiddenViewsWhenInactive:@[ topShadow, bottomShadow ]];
    }
    
    [self setPlayer:[Player sharedInstance]];
    [self _setupPlayer];


    [[self volumeSlider] setDragDelegate:self];
    [self _updateDragSongsView];

    [[self window] setExcludedFromWindowsMenu:YES];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == [self tracksController]) {
        if ([keyPath isEqualToString:@"arrangedObjects"]) {
            [self _updatePlayButton];
            [self _updateDragSongsView];
        }
    }
}

#pragma mark - Private Methods

- (Track *) _nextQueuedTrack
{
    for (Track *track in _tracks) {
        if ([track trackStatus] == TrackStatusQueued) {
            return track;
        }
    }

    return nil;
}


- (void) _updatePlayButton
{
    PlaybackAction action  = [self preferredPlaybackAction];
    BOOL           enabled = [self isPreferredPlaybackActionEnabled];
    
    Player   *player = [Player sharedInstance];
    BOOL isVolumeZero = ([player volume] == 0);

    NSImage  *image   = nil;
    NSString *tooltip = nil;
    BOOL      alert   = NO;
    
    if (action == PlaybackActionShowIssue) {
        image = [NSImage imageNamed:@"issue_template"];
        alert = YES;

        PlayerIssue issue = [player issue];

        if (issue == PlayerIssueDeviceMissing) {
            tooltip = NSLocalizedString(@"The selected output device is not connected", nil);
        } else if (issue == PlayerIssueDeviceHoggedByOtherProcess) {
            tooltip = NSLocalizedString(@"Another application is using the selected output device", nil);
        } else if (issue == PlayerIssueErrorConfiguringOutputDevice) {
            tooltip = NSLocalizedString(@"The selected output device could not be configured", nil);
        }

    } else if (action == PlaybackActionPause) {
        image = [NSImage imageNamed:@"pause_template"];

    } else if (action == PlaybackActionTogglePause) {
        image = [NSImage imageNamed:@"pause_template"];
        enabled = NO;

    } else {
        image = [NSImage imageNamed:@"play_template"];

        Track *next = [self _nextQueuedTrack];

        if (!next) {
            tooltip = NSLocalizedString(@"Add a track to enable playback", nil);
        } else if (isVolumeZero == 0) {
            tooltip = NSLocalizedString(@"Turn up the volume to enable playback", nil);
        }
    }

    Button *playButton = [self playButton];

    [playButton setWiggling:((action == PlaybackActionPause) && _inVolumeDrag && isVolumeZero) || _didAutoPause];
    [playButton setAlert:alert];
    [playButton setImage:image];
    [playButton setToolTip:tooltip];
    [playButton setEnabled:enabled];

    if (enabled) {
        [playButton setWiggling:((action == PlaybackActionPause) && _inVolumeDrag && isVolumeZero) || _didAutoPause];
    } else {
        [playButton setWiggling:NO];
    }
}


- (void) _handleTrackDidUpdate:(NSNotification *)note
{
    [self _saveState];
}


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    Preferences *preferences = [Preferences sharedInstance];
    
    AudioDevice *device     = [preferences mainOutputAudioDevice];
    double       sampleRate = [preferences mainOutputSampleRate];
    UInt32       frames     = [preferences mainOutputFrames];
    BOOL         hogMode    = [preferences mainOutputUsesHogMode];

    [[Player sharedInstance] updateOutputDevice:device sampleRate:sampleRate frames:frames hogMode:hogMode];
    
    [[self tableView] reloadData];
}


- (void) _loadState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *tracks = [NSMutableArray array];

    NSArray  *states  = [defaults objectForKey:sTracksKey];
    NSTimeInterval silence = [defaults doubleForKey:sMinimumSilenceKey];

    if ([states isKindOfClass:[NSArray class]]) {
        for (NSDictionary *state in states) {
            Track *track = [Track trackWithStateDictionary:state];
            if (track) [tracks addObject:track];
            
            if ([track trackStatus] == TrackStatusPlaying) {
                [track setTrackStatus:TrackStatusPlayed];
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
        NSDictionary *dictionary = [track stateDictionary];
        if (dictionary) [tracksStateArray addObject:dictionary];
    }

    [defaults setObject:tracksStateArray forKey:sTracksKey];
    [defaults setDouble:_minimumSilenceBetweenTracks forKey:sMinimumSilenceKey];
}


- (Track *) _selectedTrack
{
    NSArray *tracks = [[self tracksController] selectedObjects];
    return [tracks firstObject];
}


- (BOOL) _canChangeTrackStatusOfTrack:(Track *)track
{
    NSArray  *arrangedTracks = [[self tracksController] arrangedObjects];
    NSInteger count          = [arrangedTracks count];
    
    NSInteger index = [arrangedTracks indexOfObject:track];
    if (index == NSNotFound) {
        return NO;
    }
    
    if ([[Player sharedInstance] currentTrack]) {
        return NO;
    }
    
    Track *previousTrack = index > 0           ? [arrangedTracks objectAtIndex:(index - 1)] : nil;
    Track *nextTrack     = (index + 1) < count ? [arrangedTracks objectAtIndex:(index + 1)] : nil;
    
    BOOL isPreviousPlayed = !previousTrack || ([previousTrack trackStatus] == TrackStatusPlayed);
    BOOL isNextPlayed     =                    [nextTrack     trackStatus] == TrackStatusPlayed;

    return (isPreviousPlayed != isNextPlayed);
}


- (BOOL) _canDeleteSelectedObjects
{
    Track *selectedTrack = [self _selectedTrack];

    if ([selectedTrack trackStatus] == TrackStatusQueued) {
        return YES;
    }
    
    return NO;
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


- (void) _updateDragSongsView
{
    BOOL hidden = [[[self tracksController] arrangedObjects] count] > 0;
    
    if (hidden) {
        [_dragSongsView setAlphaValue:1];

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [[_dragSongsView animator] setAlphaValue:0];
        } completionHandler:^{
            [_dragSongsView removeFromSuperview];
        }];

    } else {
        NSView *scrollView  = [[self tableView] enclosingScrollView];
        NSRect  scrollFrame = [scrollView frame];
        
        NSRect dragFrame = [_dragSongsView frame];
        
        dragFrame.origin.x = NSMinX(scrollFrame) + round((NSWidth( scrollFrame) - NSWidth( dragFrame)) / 2);
        dragFrame.origin.y = NSMinY(scrollFrame) + round((NSHeight(scrollFrame) - NSHeight(dragFrame)) / 2);

        [_dragSongsView setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewMaxYMargin|NSViewMinYMargin];
        [_dragSongsView setFrame:dragFrame];

        [_dragSongsView setAlphaValue:1];
        [[scrollView superview] addSubview:_dragSongsView];
    }
}


#pragma mark - Public Methods

- (void) clearHistory
{
    NSArrayController *tracksController = [self tracksController];

    NSMutableArray *tracks = [[tracksController arrangedObjects] mutableCopy];
    Track *trackToKeep = [[Player sharedInstance] currentTrack];

    if (trackToKeep) {
        [tracks removeObject:trackToKeep];
    }

    for (Track *track in tracks) {
        [track cancelLoad];
    }

    [tracksController removeObjects:tracks];
    [tracksController setSelectionIndexes:[NSIndexSet indexSet]];
    
    [[self tableView] reloadData];
}


- (void) openFileAtURL:(NSURL *)URL
{
    Track *track = [Track trackWithFileURL:URL];
    if (track) [[self tracksController] addObject:track];
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


- (PlaybackAction) preferredPlaybackAction
{
    Player        *player      = [Player sharedInstance];

    PlayerIssue issue = [player issue];

    if (issue != PlayerIssueNone) {
        return PlaybackActionShowIssue;
    
    } else if ([player isPlaying]) {
        double volume = [player volume];

        if (volume == 0) {
            return PlaybackActionPause;
        } else {
            return PlaybackActionTogglePause;
        }

    } else {
        return PlaybackActionPlay;
    }
}


- (BOOL) isPreferredPlaybackActionEnabled
{
    PlaybackAction action = [self preferredPlaybackAction];

    if (action == PlaybackActionPlay) {
        Track *next = [self _nextQueuedTrack];

        return next != nil;

    } else if (action == PlaybackActionTogglePause) {
        return YES;

    } else if (action == PlaybackActionShowIssue) {
        return YES;

    } else if (action == PlaybackActionPause) {
        return [[Player sharedInstance] volume] == 0;

    } else {
        return NO;
    }
}


- (void) showAlertForIssue:(PlayerIssue)issue
{
    NSString *messageText     = nil;
    NSString *informativeText = nil;

    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    NSString *deviceName = [device name];

    if (issue == PlayerIssueDeviceMissing) {
        messageText = NSLocalizedString(@"The selected output device is not connected", nil);
        
        NSString *format = NSLocalizedString(@"\\U201c%@\\U201d could not be located.  Verify that it is connected and powered on.", nil);

        informativeText = [NSString stringWithFormat:format, deviceName];

    } else if (issue == PlayerIssueDeviceHoggedByOtherProcess) {
        messageText = NSLocalizedString(@"Another application is using the selected output device", nil);

        pid_t hogModeOwner = [[device controller] hogModeOwner];
        NSRunningApplication *owner = [NSRunningApplication runningApplicationWithProcessIdentifier:hogModeOwner];
        
        if (owner) {
            NSString *format = NSLocalizedString(@"The application \\U201c%@\\U201d has exclusive access to \\U201c%@\\U201d.", nil);
            NSString *applicationName = [owner localizedName];
            
            informativeText = [NSString stringWithFormat:format, applicationName, deviceName];
        }

    } else if (issue == PlayerIssueErrorConfiguringOutputDevice) {
        messageText = NSLocalizedString(@"The selected output device could not be configured", nil);
    }

    NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    if (informativeText) [alert setInformativeText:informativeText];
    
    [alert runModal];
}


#pragma mark - IBActions

- (IBAction) performPreferredPlaybackAction:(id)sender
{
    PlaybackAction action = [self preferredPlaybackAction];

    if (action == PlaybackActionShowIssue) {
        [self showAlertForIssue:[[Player sharedInstance] issue]];
        
    } else if (action == PlaybackActionPlay) {
        if (_didAutoPause) {
            _didAutoPause = NO;

            [[Player sharedInstance] playOrSoftPause];
            [[Player sharedInstance] setVolume:_volumeBeforeAutoPause];

        } else {
            [[Player sharedInstance] playOrSoftPause];
        }
    
    } else {
        [[Player sharedInstance] playOrSoftPause];
    }
}


- (IBAction) increaseVolume:(id)sender
{
    double volume = [[Player sharedInstance] volume] + 0.04;
    if (volume > 1.0) volume = 1.0;
    [[Player sharedInstance] setVolume:volume];
}


- (IBAction) decreaseVolume:(id)sender
{
    double volume = [[Player sharedInstance] volume] - 0.04;
    if (volume < 0) volume = 0;
    [[Player sharedInstance] setVolume:volume];
}


- (IBAction) increaseAutoGap:(id)sender
{
    NSTimeInterval value = [self minimumSilenceBetweenTracks] + 1;
    if (value > sAutoGapMaximum) value = sAutoGapMaximum;
    [self setMinimumSilenceBetweenTracks:value];
}


- (IBAction) decreaseAutoGap:(id)sender
{
    NSTimeInterval value = [self minimumSilenceBetweenTracks] - 1;
    if (value < sAutoGapMinimum) value = sAutoGapMinimum;
    [self setMinimumSilenceBetweenTracks:value];
}


- (IBAction) changeVolume:(id)sender
{
    [sender setNeedsDisplay];
}


- (IBAction) viewSelectedTrack:(id)sender
{
    NSInteger clickedRow = [[self tableView] clickedRow];
    NSArray *tracks = [[self tracksController] arrangedObjects];

    if (clickedRow >= 0 && clickedRow <= [tracks count]) {
        Track *track = [tracks objectAtIndex:clickedRow];
        ViewTrackController *controller = [GetAppDelegate() viewTrackControllerForTrack:track];

        [controller showWindow:self];
    }
}


- (IBAction) delete:(id)sender
{
    NSArray   *selectedTracks = [[self tracksController] selectedObjects];
    NSUInteger index = [[self tracksController] selectionIndex];
    
    NSMutableArray *tracksToRemove = [NSMutableArray array];

    for (Track *track in selectedTracks){
        if ([track trackStatus] == TrackStatusQueued) {
            [track cancelLoad];
            if (track) [tracksToRemove addObject:track];
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
        [self _updatePlayButton];
    }
}


- (IBAction) toggleMarkAsPlayed:(id)sender
{
    Track *track = [self _selectedTrack];

    if ([self _canChangeTrackStatusOfTrack:track]) {
        if ([track trackStatus] == TrackStatusQueued) {
            [track setTrackStatus:TrackStatusPlayed];
        } else if ([track trackStatus] == TrackStatusPlayed) {
            [track setTrackStatus:TrackStatusQueued];
        }

        [self _updatePlayButton];
    }
}


- (IBAction) addSilence:(id)sender
{
    Track *track = [SilentTrack silenceTrack];

    Track *selectedTrack = [self _selectedTrack];
    NSInteger index = selectedTrack ? [[[self tracksController] arrangedObjects] indexOfObject:selectedTrack] : NSNotFound;

    if (track) {
        if (selectedTrack && (index != NSNotFound)) {
            [[self tracksController] insertObject:track atArrangedObjectIndex:(index + 1)];
        } else {
            if (track) [[self tracksController] addObject:track];
        }
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

    } else if (action == @selector(toggleMarkAsPlayed:)) {
        Track *track = [self _selectedTrack];
        [menuItem setState:([track trackStatus] == TrackStatusPlayed)];
        return [self _canChangeTrackStatusOfTrack:track];
    
    } else if (action == @selector(togglePauseAfterPlaying:)) {
        Track *track = [self _selectedTrack];
        BOOL canPause = [track trackStatus] != TrackStatusPlayed;
        [menuItem setState:canPause && [track pausesAfterPlaying]];
        return canPause;

    } else if (action == @selector(addSilence:)) {
        return [self _canInsertAfterSelectedRow];
    }
    
    
    return YES;
}


#pragma mark - White Slider

- (void) whiteSliderDidStartDrag:(WhiteSlider *)slider
{
    if (slider == _volumeSlider) {
        _inVolumeDrag = YES;
        [self _updatePlayButton];
    }
}


- (void) whiteSliderDidEndDrag:(WhiteSlider *)slider
{
    if (slider == _volumeSlider) {
        _inVolumeDrag = NO;
        [self _updatePlayButton];
    }

    PlaybackAction action = [self preferredPlaybackAction];
    Button *playButton = [self playButton];
    
    if ([playButton isEnabled]) {
        Player *player = [Player sharedInstance];
        BOOL isVolumeZero = [player volume] == 0;

        if (action == PlaybackActionPause && !_inVolumeDrag && isVolumeZero) {
            [playButton flipToImage:[NSImage imageNamed:@"play_template"] enabled:YES];
            _volumeBeforeAutoPause = [[self volumeSlider] doubleValueBeforeDrag];
            _didAutoPause = YES;

            [[Player sharedInstance] hardStop];

        } else if (action == PlaybackActionPlay && _didAutoPause && !isVolumeZero) {
            [playButton flipToImage:[NSImage imageNamed:@"pause_template"] enabled:NO];
            _didAutoPause = NO;

            [[Player sharedInstance] play];
        }
    } else {
        _didAutoPause = NO;
    }
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
    if (playing) {
        [[self levelMeter] setMetering:YES];
        
    } else {
        [[self playOffsetField] setStringValue:GetStringForTime(0)];
        [[self playRemainingField] setStringValue:GetStringForTime(0)];
        [[self playBar] setPercentage:0];

        [[self levelMeter] setMetering:NO];
    }

    [self _updatePlayButton];
}


- (void) player:(Player *)player didUpdateIssue:(PlayerIssue)issue
{
    [self _updatePlayButton];
}


- (void) player:(Player *)player didUpdateVolume:(double)volume
{
    [self _updatePlayButton];
}


- (void) playerDidTick:(Player *)player
{
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

    if (![player isPlaying]) {
        percentage = 0;
    }

    [[self playBar] setPercentage:percentage];
    [[self levelMeter] setLeftAveragePower:leftAveragePower rightAveragePower:rightAveragePower leftPeakPower:leftPeakPower rightPeakPower:rightPeakPower];

    [self _updatePlayButton];
}


- (void) player:(Player *)player getNextTrack:(Track **)outNextTrack getPadding:(NSTimeInterval *)outPadding
{
    Track *currentTrack = [player currentTrack];

    [self _saveState];

    Track *trackToPlay = [self _nextQueuedTrack];
    NSTimeInterval padding = 0;
    
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


- (void) tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    if (operation == NSDragOperationNone) {
        NSRect frame = [[self window] frame];

        if (!NSPointInRect(screenPoint, frame)) {
            if (_rowOfDraggedTrack != NSNotFound) {
                Track *draggedTrack = [[[self tracksController] arrangedObjects] objectAtIndex:_rowOfDraggedTrack];

                [[self tableView] beginUpdates];

                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:_rowOfDraggedTrack];
                [[self tableView] removeRowsAtIndexes:indexSet withAnimation:NSTableViewAnimationEffectNone];

                if (draggedTrack) {
                    [[self tracksController] removeObject:draggedTrack];
                }

                [[self tableView] endUpdates];
                
                NSShowAnimationEffect(NSAnimationEffectPoof, [NSEvent mouseLocation], NSZeroSize, nil, nil, nil);
            }
        }
    }
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
        
        if (draggedTrack) {
            [[self tracksController] removeObject:draggedTrack];
            [[self tracksController] insertObject:draggedTrack atArrangedObjectIndex:row];
        }

        return YES;

    } else if ([filenames count] >= 2) {
        for (NSString *filename in [filenames reverseObjectEnumerator]) {
            NSURL *URL = [NSURL fileURLWithPath:filename];

            Track *track = [Track trackWithFileURL:URL];
            if (track) {
                [[self tracksController] insertObject:track atArrangedObjectIndex:row];
            }
        }

        return YES;

    } else if (URLString) {
        NSURL *URL = [NSURL URLWithString:URLString];

        Track *track = [Track trackWithFileURL:URL];
        if (track) {
            [[self tracksController] insertObject:track atArrangedObjectIndex:row];
        }

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


- (void) setMinimumSilenceBetweenTracks:(NSTimeInterval)minimumSilenceBetweenTracks
{
    if (_minimumSilenceBetweenTracks != minimumSilenceBetweenTracks) {
        _minimumSilenceBetweenTracks = minimumSilenceBetweenTracks;
        [self _saveState];
    }
}


@end
