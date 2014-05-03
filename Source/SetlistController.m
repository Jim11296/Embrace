//
//  SetlistController
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "SetlistController.h"

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
#import "TracksController.h"
#import "TrialBottomView.h"
#import "WhiteSlider.h"

#import <AVFoundation/AVFoundation.h>

static NSString * const sMinimumSilenceKey = @"minimum-silence";
static NSString * const sSavedAtKey = @"saved-at";

static NSTimeInterval sAutoGapMinimum = 0;
static NSTimeInterval sAutoGapMaximum = 15.0;


@interface SetlistController () <NSTableViewDelegate, NSTableViewDataSource, PlayerListener, PlayerTrackProvider, WhiteSliderDragDelegate>

@end

@implementation SetlistController {
    BOOL       _inVolumeDrag;
    
    double     _volumeBeforeKeyboard;
    double     _volumeBeforeAutoPause;
    BOOL       _didAutoPause;
    BOOL       _confirmPause;
    BOOL       _willCalculateStartAndEndTimes;
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
    return @"SetlistWindow";
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    WhiteWindow *window = (WhiteWindow *)[self window];

    [window setupWithHeaderView:[self headerView] mainView:[self mainView]];
    

    [[self headerView] setBottomBorderColor:[NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0]];
    [[self bottomContainer] setTopBorderColor:[NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0]];


    [[self playButton] setImage:[NSImage imageNamed:@"play_template"]];
    [[self gearButton] setImage:[NSImage imageNamed:@"gear_template"]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handlePreferencesDidChange:)            name:PreferencesDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleTracksControllerDidModifyTracks:) name:TracksControllerDidModifyTracksNotificationName object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleTrackDidModifyPlayDuration:)      name:TrackDidModifyPlayDurationNotificationName object:nil];

    [self _handlePreferencesDidChange:nil];

#if TRIAL
    {
        NSScrollView *scrollView      = [self scrollView];
        BorderedView *bottomContainer = [self bottomContainer];
    

        // Fix up the bottom here
        NSRect bottomFrame = [bottomContainer frame];
        bottomFrame.size.height += 38;
        
        NSRect trialBottomViewFrame = bottomFrame;
        trialBottomViewFrame.origin.y = 34;
        trialBottomViewFrame.size.height = 32;
        trialBottomViewFrame.size.width = 172;
        trialBottomViewFrame.origin.x = round((bottomFrame.size.width - 172) / 2);
       
        NSRect scrollFrame = [scrollView frame];
        scrollFrame.size.height -= 38;
        scrollFrame.origin.y += 38;
        [[self scrollView] setFrame:scrollFrame];
        
        [[self bottomContainer] setFrame:bottomFrame];

        TrialBottomView *bv = [[TrialBottomView alloc] initWithFrame:trialBottomViewFrame];
        [bv setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewHeightSizable];
        [[self bottomContainer] addSubview:bv];

    }
#endif


    // Add top and bottom shadows
    {
        NSRect mainBounds = [[self mainView] bounds];

        NSRect topShadowFrame    = NSMakeRect(0, 0, mainBounds.size.width, 4);
        NSRect bottomShadowFrame = NSMakeRect(0, 0, mainBounds.size.width, 4);
        
        bottomShadowFrame.origin.y = NSMinY([[self scrollView] frame]);

        topShadowFrame.origin.y = mainBounds.size.height - 4;
        
        ShadowView *topShadow    = [[ShadowView alloc] initWithFrame:topShadowFrame];
        ShadowView *bottomShadow = [[ShadowView alloc] initWithFrame:bottomShadowFrame];
        
        [topShadow setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin];
        [bottomShadow setAutoresizingMask:NSViewWidthSizable|NSViewMaxYMargin];
        
        [bottomShadow setFlipped:YES];
        
        [[self mainView] addSubview:topShadow];
        [[self mainView] addSubview:bottomShadow];
        
        [window setHiddenViewsWhenInactive:@[ topShadow, bottomShadow ]];
    }
    
    [self setPlayer:[Player sharedInstance]];
    [self _setupPlayer];


    [[self volumeSlider] setDragDelegate:self];
    [self _updateDragSongsView];

    [window setExcludedFromWindowsMenu:YES];

    [window registerForDraggedTypes:@[ NSURLPboardType, NSFilenamesPboardType ]];

}

#if TRIAL

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    NSLog(@"%@", NSStringFromSelector(commandSelector));
    return YES;
}

#endif

#pragma mark - Private Methods

- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
    return NSDragOperationCopy;
}


- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
    return [[self tracksController] acceptDrop:sender row:-1 dropOperation:NSTableViewDropOn];
}


#pragma mark - Private Methods

- (void) _updatePlayButton
{
    PlaybackAction action  = [self preferredPlaybackAction];
    BOOL           enabled = [self isPreferredPlaybackActionEnabled];
    
    Player   *player = [Player sharedInstance];
    BOOL isVolumeZero = ([player volume] == 0);

    NSImage  *image   = nil;
    NSString *tooltip = nil;
    BOOL      alert   = NO;

    Button *playButton = [self playButton];
    
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
        image = _confirmPause ? [NSImage imageNamed:@"stop_template"] : [NSImage imageNamed:@"pause_template"];
        alert = _confirmPause;
        enabled = YES;

    } else {
        image = [NSImage imageNamed:@"play_template"];

        Track *next = [[self tracksController] firstQueuedTrack];

        if (!next) {
            tooltip = NSLocalizedString(@"Add a track to enable playback", nil);
        }
    }

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


- (void) _handlePreferencesDidChange:(NSNotification *)note
{
    Preferences *preferences = [Preferences sharedInstance];
    
    AudioDevice *device     = [preferences mainOutputAudioDevice];
    double       sampleRate = [preferences mainOutputSampleRate];
    UInt32       frames     = [preferences mainOutputFrames];
    BOOL         hogMode    = [preferences mainOutputUsesHogMode];

    [[Player sharedInstance] updateOutputDevice:device sampleRate:sampleRate frames:frames hogMode:hogMode];
}


- (void) _handleTracksControllerDidModifyTracks:(NSNotification *)note
{
    [self _calculateStartAndEndTimes];
    [self _updatePlayButton];
    [self _updateDragSongsView];
}


- (void) _handleTrackDidModifyPlayDuration:(NSNotification *)note
{
    if (!_willCalculateStartAndEndTimes) {
        [self performSelector:@selector(_calculateStartAndEndTimes) withObject:nil afterDelay:10];
        _willCalculateStartAndEndTimes = YES;
    }
}


- (void) _loadState
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval silence = [defaults doubleForKey:sMinimumSilenceKey];
    [self setMinimumSilenceBetweenTracks:silence];
}


- (NSString *) _contentsAsString
{
    NSMutableArray *played = [NSMutableArray array];
    NSMutableArray *queued = [NSMutableArray array];

    for (Track *track in [[self tracksController] tracks]) {
        NSMutableString *line = [NSMutableString string];

        NSString *artist = [track artist];
        if (artist) [line appendFormat:@"%@ %C ", artist, (unichar)0x2014];
        
        NSString *title = [track title];
        if (!title) title = @"???";

        [line appendFormat:@"%@", title];
        
        if ([track trackStatus] == TrackStatusQueued) {
            [queued addObject:line];
        } else {
            [played addObject:line];
        }
    }
    
    NSString *result = @"";
    NSString *playedString = [played count] ? [played componentsJoinedByString:@"\n"] : nil;
    NSString *queuedString = [queued count] ? [queued componentsJoinedByString:@"\n"] : nil;

    if (playedString && queuedString) {
        result = [NSString stringWithFormat:@"%@\n\nUnplayed:\n%@", playedString, queuedString];

    } else if (queuedString) {
        result = queuedString;

    } else if (playedString) {
        result = playedString;
    }
    
    return result;
}


- (void) _updateDragSongsView
{
    BOOL hidden = [[[self tracksController] tracks] count] > 0;
    
    if (hidden) {
        [_dragSongsView setAlphaValue:1];

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [[_dragSongsView animator] setAlphaValue:0];
        } completionHandler:^{
            [_dragSongsView removeFromSuperview];
        }];

    } else {
        NSView *scrollView  = [self scrollView];
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


- (void) _markAsSaved
{
    NSTimeInterval t = [NSDate timeIntervalSinceReferenceDate];
    [[NSUserDefaults standardUserDefaults] setObject:@(t) forKey:sSavedAtKey];
}


- (void) _doAutoPauseIfNeededWithBeforeVolume:(double)beforeVolume
{
    EmbraceLogMethod();

    PlaybackAction action = [self preferredPlaybackAction];
    Button *playButton = [self playButton];
    
    if ([playButton isEnabled]) {
        Player *player = [Player sharedInstance];
        BOOL isVolumeZero = [player volume] == 0;

        if (action == PlaybackActionPause && !_inVolumeDrag && isVolumeZero) {
            [playButton performOpenAnimationToImage:[NSImage imageNamed:@"play_template"] enabled:YES];
            _volumeBeforeAutoPause = beforeVolume;
            _didAutoPause = YES;

            [[Player sharedInstance] hardStop];

        } else if (action == PlaybackActionPlay && _didAutoPause && !isVolumeZero) {
            [playButton performOpenAnimationToImage:[NSImage imageNamed:@"pause_template"] enabled:NO];
            _didAutoPause = NO;

            [[Player sharedInstance] play];
        }
    } else {
        _didAutoPause = NO;
    }
}


- (void) _clearConfirmPause
{
    EmbraceLogMethod();

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_clearConfirmPause) object:nil];

    _confirmPause = NO;
    [[self playButton] performPopAnimation:NO toImage:[NSImage imageNamed:@"pause_template"] alert:NO];
    [self _updatePlayButton];
}


- (void) _clearVolumeBeforeKeyboard
{
    _volumeBeforeKeyboard = 0;
}


- (void) _increaseOrDecreaseVolumeByAmount:(CGFloat)amount
{
    EmbraceLogMethod();

    Player *player = [Player sharedInstance];

    double oldVolume = [player volume];
    double newVolume = oldVolume + amount;

    if (newVolume > 1.0) newVolume = 1.0;
    if (newVolume < 0.0) newVolume = 0.0;

    if (_volumeBeforeKeyboard == 0) {
        _volumeBeforeKeyboard = oldVolume;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_clearVolumeBeforeKeyboard) object:nil];
        [self performSelector:@selector(_clearVolumeBeforeKeyboard) withObject:nil afterDelay:10];
    }

    [player setVolume:newVolume];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _doAutoPauseIfNeededWithBeforeVolume:_volumeBeforeKeyboard];
    });
}


- (void) _calculateStartAndEndTimes
{
    _willCalculateStartAndEndTimes = NO;

    Player *player = [Player sharedInstance];

    NSTimeInterval now = [player isPlaying] ? [NSDate timeIntervalSinceReferenceDate] : 0.0;
    NSTimeInterval time = 0;

    Track  *lastTrack = nil;

    for (Track *track in [[self tracksController] tracks]) {
        NSTimeInterval endTime   = 0;

        TrackStatus status = [track trackStatus];
        
        if (status == TrackStatusPlayed) {
            continue;

        } else if (status == TrackStatusPlaying) {
            if ([track isEqual:[player currentTrack]]) {
                time += [player timeRemaining];
                endTime = now + time;
            }

        } else if (status == TrackStatusQueued) {
            time += [track playDuration];
            endTime = now + time;
            
            if (lastTrack) {
                NSTimeInterval padding = 0;

                NSTimeInterval minimumSilence =  [self minimumSilenceBetweenTracks];

                NSTimeInterval totalSilence = [lastTrack silenceAtEnd] + [track silenceAtStart];
                padding = minimumSilence - totalSilence;
                if (padding < 0) padding = 0;
                
                if (minimumSilence > 0 && padding == 0) {
                    padding = 1.0;
                }

                time += padding;
            }
        }
        
        if (endTime) {
            [track setEstimatedEndTime:endTime];
        }

        lastTrack = track;
    }
}


#pragma mark - Public Methods

- (void) clear
{
    EmbraceLog(@"SetlistController", @"-clear");

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:sSavedAtKey];

    [[self tracksController] removeAllTracks];
}


- (void) resetPlayedTracks
{
    EmbraceLogMethod();
    [[self tracksController] resetPlayedTracks];
}


- (BOOL) shouldPromptForClear
{
    NSTimeInterval modifiedAt = [[self tracksController] modificationTime];
    NSTimeInterval savedAt    = [[NSUserDefaults standardUserDefaults] doubleForKey:sSavedAtKey];
    
    NSInteger playedCount = 0;
    for (Track *track in [[self tracksController] tracks]) {
        if ([track trackStatus] == TrackStatusPlayed) {
            playedCount++;
            break;
        }
    }
    
    if ((modifiedAt > savedAt) && (playedCount > 0)) {
        return YES;
    }
    
    return NO;
}


- (void) openFileAtURL:(NSURL *)URL
{
    EmbraceLog(@"SetlistController", @"-openFileAtURL: %@", URL);

    [[self tracksController] addTrackAtURL:URL];
}


- (void) copyToPasteboard:(NSPasteboard *)pasteboard
{
    EmbraceLogMethod();

    NSString *contents = [self _contentsAsString];

    NSPasteboardItem *item = [[NSPasteboardItem alloc] initWithPasteboardPropertyList:contents ofType:NSPasteboardTypeString];

    [pasteboard clearContents];
    [pasteboard writeObjects:[NSArray arrayWithObject:item]];
}


- (void) saveToFileAtURL:(NSURL *)url
{
    EmbraceLog(@"SetlistController", @"-saveToFileAtURL:%@", url);

    NSString *contents = [self _contentsAsString];

    NSError *error = nil;
    [contents writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        EmbraceLog(@"SetlistController", @"Error saving set list to %@, %@", url, error);
        NSBeep();
    }
    
    [self _markAsSaved];
}


- (void) exportToPlaylist
{
    EmbraceLogMethod();

    NSMutableArray *fileURLs = [NSMutableArray array];
    
    for (Track *track in [[self tracksController] tracks]) {
        NSURL *fileURL = [track externalURL];
        if (fileURL) [fileURLs addObject:fileURL];
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterLongStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    
    NSMutableString *name = [NSMutableString string];
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    [name appendFormat:@"%@ (%@)", NSLocalizedString(@"Embrace", nil), dateString];
    
    [[iTunesManager sharedInstance] exportPlaylistWithName:name fileURLs:fileURLs];

    [self _markAsSaved];
}


- (PlaybackAction) preferredPlaybackAction
{
    Player *player = [Player sharedInstance];

    PlayerIssue issue = [player issue];

    if (issue != PlayerIssueNone) {
        return PlaybackActionShowIssue;
    
    } else if ([player isPlaying]) {
        return PlaybackActionPause;

    } else {
        return PlaybackActionPlay;
    }
}


- (BOOL) isPlaybackActionEnabled:(PlaybackAction)action
{
    if (action == PlaybackActionPlay) {
        Track *next = [[self tracksController] firstQueuedTrack];
        return next != nil;
    }
    
    return YES;
}


- (BOOL) isPreferredPlaybackActionEnabled
{
    return [self isPlaybackActionEnabled:[self preferredPlaybackAction]];
}


- (void) showAlertForIssue:(PlayerIssue)issue
{
    NSString *messageText     = nil;
    NSString *informativeText = nil;
    NSString *otherButton     = nil;

    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    NSString *deviceName = [device name];

    if (issue == PlayerIssueDeviceMissing) {
        messageText = NSLocalizedString(@"The selected output device is not connected.", nil);
        
        NSString *format = NSLocalizedString(@"Verify that \\U201c%@\\U201d is connected and powered on.", nil);

        informativeText = [NSString stringWithFormat:format, deviceName];
        otherButton = NSLocalizedString(@"Show Preferences", nil);

    } else if (issue == PlayerIssueDeviceHoggedByOtherProcess) {
        messageText = NSLocalizedString(@"Another application is using the selected output device.", nil);

        pid_t hogModeOwner = [[device controller] hogModeOwner];
        NSRunningApplication *owner = [NSRunningApplication runningApplicationWithProcessIdentifier:hogModeOwner];
        
        if (owner) {
            NSString *format = NSLocalizedString(@"The application \\U201c%@\\U201d has exclusive access to \\U201c%@\\U201d.", nil);
            NSString *applicationName = [owner localizedName];
            
            informativeText = [NSString stringWithFormat:format, applicationName, deviceName];
        }

    } else if (issue == PlayerIssueErrorConfiguringOutputDevice) {
        messageText = NSLocalizedString(@"The selected output device could not be configured.", nil);
        otherButton = NSLocalizedString(@"Show Preferences", nil);
    }

    NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:nil alternateButton:nil otherButton:otherButton informativeTextWithFormat:@""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    if (informativeText) [alert setInformativeText:informativeText];
    
    if ([alert runModal] == NSAlertOtherReturn) {
        [GetAppDelegate() showPreferences:nil];
    }
}


- (void) handleNonSpaceKeyDown
{
    if (_confirmPause) {
        [self _clearConfirmPause];
    }
}



#pragma mark - IBActions

- (IBAction) performPreferredPlaybackAction:(id)sender
{
    EmbraceLogMethod();

    PlaybackAction action = [self preferredPlaybackAction];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_clearConfirmPause) object:nil];

    if (action == PlaybackActionShowIssue) {
        [self showAlertForIssue:[[Player sharedInstance] issue]];

    } else if (action == PlaybackActionPause) {
        BOOL isAtBeginningOfSong = [[Player sharedInstance] isAtBeginningOfSong];
    
        EmbraceLog(@"SetlistController", @"Performing PlaybackActionPause, _confirmPause is %ld", (long)_confirmPause);

        if (!_confirmPause && !isAtBeginningOfSong) {
            _confirmPause = YES;

            [[self playButton] performPopAnimation:YES toImage:[NSImage imageNamed:@"stop_template"] alert:YES];
            
            [self _updatePlayButton];
            [self performSelector:@selector(_clearConfirmPause) withObject:nil afterDelay:2];

        } else {
            NSEvent *currentEvent = [NSApp currentEvent];
            NSEventType type = [currentEvent type];
            
            BOOL isDoubleClick = NO;

            EmbraceLog(@"SetlistController", @"About to -hardStop with event: %@", currentEvent);

            if ((type == NSLeftMouseDown) || (type == NSRightMouseDown) || (type == NSOtherMouseDown)) {
                isDoubleClick = [currentEvent clickCount] >= 2;
            }
        
            if (!isDoubleClick) {
                _confirmPause = NO;
                [[Player sharedInstance] hardStop];
            }
        }

    } else {
        if (_didAutoPause) {
            _didAutoPause = NO;

            [[Player sharedInstance] play];
            [[Player sharedInstance] setVolume:_volumeBeforeAutoPause];
            
            _volumeBeforeKeyboard = 0;

        } else {
            [[Player sharedInstance] play];
        }
    }
}


- (IBAction) increaseVolume:(id)sender
{
    EmbraceLogMethod();
    [self _increaseOrDecreaseVolumeByAmount:0.04];
}


- (IBAction) decreaseVolume:(id)sender
{
    EmbraceLogMethod();
    [self _increaseOrDecreaseVolumeByAmount:-0.04];
}


- (IBAction) increaseAutoGap:(id)sender
{
    EmbraceLogMethod();
    NSTimeInterval value = [self minimumSilenceBetweenTracks] + 1;
    if (value > sAutoGapMaximum) value = sAutoGapMaximum;
    [self setMinimumSilenceBetweenTracks:value];
}


- (IBAction) decreaseAutoGap:(id)sender
{
    EmbraceLogMethod();
    NSTimeInterval value = [self minimumSilenceBetweenTracks] - 1;
    if (value < sAutoGapMinimum) value = sAutoGapMinimum;
    [self setMinimumSilenceBetweenTracks:value];
}


- (IBAction) changeVolume:(id)sender
{
    EmbraceLogMethod();
    [sender setNeedsDisplay];
}


- (IBAction) delete:(id)sender
{
    EmbraceLogMethod();
    [[self tracksController] delete:sender];
}


- (void) revealEndTime:(id)sender
{
    EmbraceLogMethod();

    Track *track = [[self tracksController] selectedTrack];
    if (!track) return;

    [self _calculateStartAndEndTimes];

    [[self tracksController] revealEndTimeForTrack:track];
}


- (BOOL) canRevealEndTime
{
    Track *track = [[self tracksController] selectedTrack];
    return track && ([track trackStatus] != TrackStatusPlayed);
}


- (IBAction) togglePauseAfterPlaying:(id)sender
{
    EmbraceLogMethod();

    Track *track = [[self tracksController] selectedTrack];
    
    if ([track trackStatus] != TrackStatusPlayed) {
        [track setPausesAfterPlaying:![track pausesAfterPlaying]];
        [self _updatePlayButton];
    }
}


- (IBAction) toggleMarkAsPlayed:(id)sender
{
    EmbraceLogMethod();

    Track *track = [[self tracksController] selectedTrack];

    if ([[self tracksController] canChangeTrackStatusOfTrack:track]) {
        if ([track trackStatus] == TrackStatusQueued) {
            [track setTrackStatus:TrackStatusPlayed];
        } else if ([track trackStatus] == TrackStatusPlayed) {
            [track setTrackStatus:TrackStatusQueued];
        }

        [self _updatePlayButton];
    }
}


- (IBAction) showGearMenu:(id)sender
{
    EmbraceLogMethod();

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


#pragma mark - Delegates

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(delete:)) {
        return [[self tracksController] canDeleteSelectedObjects];

    } else if (action == @selector(toggleMarkAsPlayed:)) {
        Track *track = [[self tracksController] selectedTrack];
        [menuItem setState:([track trackStatus] == TrackStatusPlayed)];
        return [[self tracksController] canChangeTrackStatusOfTrack:track];
    
    } else if (action == @selector(togglePauseAfterPlaying:)) {
        Track *track = [[self tracksController] selectedTrack];
        BOOL canPause = [track trackStatus] != TrackStatusPlayed;
        [menuItem setState:canPause && [track pausesAfterPlaying]];
        return canPause;

    } else if (action == @selector(revealEndTime:)) {
        return [self canRevealEndTime];
    }
    
    
    return YES;
}


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

    double beforeVolume = [[self volumeSlider] doubleValueBeforeDrag];
    [self _doAutoPauseIfNeededWithBeforeVolume:beforeVolume];
}


- (BOOL) window:(WhiteWindow *)window cancelOperation:(id)sender
{
    if ([[self tracksController] selectedTrack]) {
        [[self tracksController] deselectAllTracks];
        return YES;
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
    EmbraceLog(@"SetlistController", @"player:didUpdatePlaying:%ld", (long)playing);

    if (playing) {
        [[self levelMeter] setMetering:YES];
        
    } else {
        [[self playOffsetField] setStringValue:GetStringForTime(0)];
        [[self playRemainingField] setStringValue:GetStringForTime(0)];
        [[self playBar] setPercentage:0];

        [[self levelMeter] setMetering:NO];
    }

    [self _updatePlayButton];
    [self _calculateStartAndEndTimes];
}


- (void) player:(Player *)player didUpdateIssue:(PlayerIssue)issue
{
    [self _updatePlayButton];
}


- (void) player:(Player *)player didUpdateVolume:(double)volume
{
    [self _updatePlayButton];
}


- (void) player:(Player *)player didInterruptPlaybackWithReason:(PlayerInterruptionReason)reason
{
    NSString *messageText = NSLocalizedString(@"Another application interrupted playback.", nil);

    AudioDevice *device = [[Preferences sharedInstance] mainOutputAudioDevice];
    NSString *deviceName = [device name];

    NSString *otherButton = NSLocalizedString(@"Show Preferences", nil);

    NSString *informativeText = NSLocalizedString(@"You can prevent this by quitting other applications when using Embrace, or by giving Embrace exclusive access in Preferences.", nil);

    if (reason == PlayerInterruptionReasonHoggedByOtherProcess) {
        pid_t hogModeOwner = [[device controller] hogModeOwner];
        NSRunningApplication *owner = [NSRunningApplication runningApplicationWithProcessIdentifier:hogModeOwner];
        
        if (owner) {
            NSString *format = NSLocalizedString(@"%@ interrupted playback by taking exclusive access to \\U201c%@\\U201d.", nil);
            NSString *applicationName = [owner localizedName];
            messageText = [NSString stringWithFormat:format, applicationName, deviceName];

        } else {
            NSString *format = NSLocalizedString(@"Another application interrupted playback by taking exclusive access to \\U201c%@\\U201d.", nil);
            messageText = [NSString stringWithFormat:format, deviceName];
        }

    } else if (reason == PlayerInterruptionReasonSampleRateChanged ||
               reason == PlayerInterruptionReasonFramesChanged     ||
               reason == PlayerInterruptionReasonChannelLayoutChanged)
    {
        NSString *format = NSLocalizedString(@"Another application interrupted playback by changing the configuration of \\U201c%@\\U201d.", nil);
        messageText = [NSString stringWithFormat:format, deviceName];
    }

    NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:nil alternateButton:nil otherButton:otherButton informativeTextWithFormat:@""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    if (informativeText) [alert setInformativeText:informativeText];

    if ([alert runModal] == NSAlertOtherReturn) {
        [GetAppDelegate() showPreferences:nil];
    }
}


- (void) playerDidTick:(Player *)player
{
    NSTimeInterval timeElapsed   = [player timeElapsed];
    NSTimeInterval timeRemaining = [player timeRemaining];

    Float32 leftAveragePower  = [player leftAveragePower];
    Float32 rightAveragePower = [player rightAveragePower];
    Float32 leftPeakPower     = [player leftPeakPower];
    Float32 rightPeakPower    = [player rightPeakPower];
    BOOL    limiterActive     = [player isLimiterActive];
    
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
    [[self levelMeter] setLeftAveragePower: leftAveragePower
                         rightAveragePower: rightAveragePower
                             leftPeakPower: leftPeakPower
                            rightPeakPower: rightPeakPower
                             limiterActive: limiterActive];

    [self _updatePlayButton];
}


- (void) player:(Player *)player getNextTrack:(Track **)outNextTrack getPadding:(NSTimeInterval *)outPadding
{
    Track *currentTrack = [player currentTrack];

    [[self tracksController] saveState];

    Track *trackToPlay = [[self tracksController] firstQueuedTrack];
    NSTimeInterval padding = 0;
    
    NSTimeInterval minimumSilence =  [self minimumSilenceBetweenTracks];
    
    if (currentTrack && trackToPlay) {
        NSTimeInterval totalSilence = [currentTrack silenceAtEnd] + [trackToPlay silenceAtStart];
        padding = minimumSilence - totalSilence;
        if (padding < 0) padding = 0;
        
        if (minimumSilence > 0 && padding == 0) {
            padding = 1.0;
        }
        
        if ([currentTrack trackError]) {
            padding = 0;
        }
    }

    EmbraceLog(@"SetlistController", @"-player:getNextTrack:getPadding:, currentTrack=%@, nextTrack=%@, padding=%g", currentTrack, trackToPlay, padding);
    
    *outNextTrack = trackToPlay;
    *outPadding   = padding;
}


- (void) setMinimumSilenceBetweenTracks:(NSTimeInterval)minimumSilenceBetweenTracks
{
    if (_minimumSilenceBetweenTracks != minimumSilenceBetweenTracks) {
        _minimumSilenceBetweenTracks = minimumSilenceBetweenTracks;
        [[NSUserDefaults standardUserDefaults] setDouble:minimumSilenceBetweenTracks forKey:sMinimumSilenceKey];
        [self _calculateStartAndEndTimes];
    }
}


@end
