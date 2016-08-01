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
#import "ExportManager.h"
#import "iTunesManager.h"
#import "TrackTableCellView.h"
#import "WaveformView.h"
#import "BorderedView.h"
#import "Button.h"
#import "EmbraceWindow.h"
#import "LabelMenuView.h"
#import "DangerMeter.h"
#import "LevelMeter.h"
#import "PlayBar.h"
#import "Preferences.h"
#import "ViewTrackController.h"
#import "TrackTableView.h"
#import "TracksController.h"
#import "TrialBottomView.h"
#import "WhiteSlider.h"

#import <AVFoundation/AVFoundation.h>

static NSString * const sMinimumSilenceKey = @"minimum-silence";
static NSString * const sSavedAtKey = @"saved-at";

static NSInteger sAutoGapMinimum = 0;
static NSInteger sAutoGapMaximum = 16;


@interface SetlistController () <NSTableViewDelegate, NSTableViewDataSource, PlayerListener, PlayerTrackProvider, WhiteSliderDragDelegate, EmbraceWindowListener>

@property (nonatomic, strong, readwrite) IBOutlet TracksController *tracksController;

@property (nonatomic, strong) IBOutlet NSView *dragSongsView;

@property (nonatomic, strong) IBOutlet NSMenu        *gearMenu;
@property (nonatomic, strong) IBOutlet LabelMenuView *gearLabelMenuView;
@property (nonatomic, weak)   IBOutlet NSMenuItem    *gearLabelSeparator;
@property (nonatomic, weak)   IBOutlet NSMenuItem    *gearLabelMenuItem;

@property (nonatomic, strong) IBOutlet NSMenu        *tableMenu;
@property (nonatomic, strong) IBOutlet LabelMenuView *tableLabelMenuView;
@property (nonatomic, weak)   IBOutlet NSMenuItem    *tableLabelSeparator;
@property (nonatomic, weak)   IBOutlet NSMenuItem    *tableLabelMenuItem;

@property (nonatomic, weak)   IBOutlet BorderedView *topContainer;

@property (nonatomic, weak)   IBOutlet NSTextField  *playOffsetField;
@property (nonatomic, weak)   IBOutlet PlayBar      *playBar;
@property (nonatomic, weak)   IBOutlet NSTextField  *playRemainingField;
@property (nonatomic, weak)   IBOutlet Button       *playButton;
@property (nonatomic, weak)   IBOutlet Button       *gearButton;
@property (nonatomic, weak)   IBOutlet DangerMeter  *dangerMeter;
@property (nonatomic, weak)   IBOutlet LevelMeter   *levelMeter;
@property (nonatomic, weak)   IBOutlet WhiteSlider  *volumeSlider;

@property (nonatomic, weak)   IBOutlet NSView *mainView;
@property (nonatomic, weak)   IBOutlet NSScrollView *scrollView;
@property (nonatomic, weak)   IBOutlet BorderedView *bottomContainer;
@property (nonatomic, weak)   IBOutlet WhiteSlider  *autoGapSlider;
@property (nonatomic, weak)   IBOutlet NSTextField  *autoGapField;

@end

@implementation SetlistController {
    BOOL       _inVolumeDrag;
    
    double     _volumeBeforeKeyboard;
    double     _volumeBeforeAutoPause;
    BOOL       _didAutoPause;
    BOOL       _confirmStop;
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

    EmbraceWindow *window = (EmbraceWindow *)[self window];
   
    [window setTitlebarAppearsTransparent:YES];
    [window setTitleVisibility:NSWindowTitleHidden];
    [window setMovableByWindowBackground:YES];
    [window setTitle:@""];
    [[window standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
    [[window standardWindowButton:NSWindowZoomButton]        setHidden:YES];
    
    [window addListener:[self gearButton]];
    [window addListener:[self playButton]];
    [window addListener:[self volumeSlider]];
    [window addListener:[self autoGapSlider]];
    [window addListener:self];

    [[self bottomContainer] setTopBorderColor:GetRGBColor(0x0, 0.15)];

    [[self playButton] setImage:[NSImage imageNamed:@"PlayTemplate"]];
    [[self gearButton] setImage:[NSImage imageNamed:@"GearTemplate"]];
    
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

    [self setPlayer:[Player sharedInstance]];
    [self _setupPlayer];

    [[self volumeSlider] setDragDelegate:self];
    [self _updateDragSongsView];

    if ([[NSFont class] respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
        NSFont *font = [[self autoGapField] font];
        font = [NSFont monospacedDigitSystemFontOfSize:[font pointSize] weight:NSFontWeightRegular];
        [[self autoGapField] setFont:font];

        font = [[self playOffsetField] font];
        font = [NSFont monospacedDigitSystemFontOfSize:[font pointSize] weight:NSFontWeightRegular];
        [[self playOffsetField] setFont:font];

        font = [[self playRemainingField] font];
        font = [NSFont monospacedDigitSystemFontOfSize:[font pointSize] weight:NSFontWeightRegular];
        [[self playRemainingField] setFont:font];
    }

    [window setExcludedFromWindowsMenu:YES];

    [window registerForDraggedTypes:@[ NSURLPboardType, NSFilenamesPboardType ]];
    
    [self windowDidUpdateMain:nil];
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
        image = [NSImage imageNamed:@"DeviceIssueTemplate"];
        alert = YES;

        PlayerIssue issue = [player issue];

        if (issue == PlayerIssueDeviceMissing) {
            tooltip = NSLocalizedString(@"The selected output device is not connected", nil);
        } else if (issue == PlayerIssueDeviceHoggedByOtherProcess) {
            tooltip = NSLocalizedString(@"Another application is using the selected output device", nil);
        } else if (issue == PlayerIssueErrorConfiguringOutputDevice) {
            tooltip = NSLocalizedString(@"The selected output device could not be configured", nil);
        }

    } else if (action == PlaybackActionStop) {
        image = _confirmStop ? [NSImage imageNamed:@"ConfirmTemplate"] : [NSImage imageNamed:@"StopTemplate"];
        alert = _confirmStop;
        enabled = YES;

    } else {
        if (_didAutoPause) {
            image = [NSImage imageNamed:@"ResumeTemplate"];
        } else {
            image = [NSImage imageNamed:@"PlayTemplate"];
        }

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
        [playButton setWiggling:((action == PlaybackActionStop) && _inVolumeDrag && isVolumeZero)];
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
    
    
    NSWindow *window = [self window];
    if ([preferences floatsOnTop]) {
        [window setLevel:NSFloatingWindowLevel];
        [window setCollectionBehavior:NSWindowCollectionBehaviorManaged|NSWindowCollectionBehaviorParticipatesInCycle];
        
    } else {
        [window setLevel:NSNormalWindowLevel];
        [window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
    
    }
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
    NSInteger silence = [defaults integerForKey:sMinimumSilenceKey];
    [self setMinimumSilenceBetweenTracks:silence];
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

        if (action == PlaybackActionStop && !_inVolumeDrag && isVolumeZero) {
            [playButton performOpenAnimationToImage:[NSImage imageNamed:@"ResumeTemplate"] enabled:YES];
            _volumeBeforeAutoPause = beforeVolume;
            _didAutoPause = YES;

            [[Player sharedInstance] hardStop];

        } else if (action == PlaybackActionPlay && _didAutoPause && !isVolumeZero) {
            [playButton performOpenAnimationToImage:[NSImage imageNamed:@"StopTemplate"] enabled:NO];
            _didAutoPause = NO;

            [[Player sharedInstance] play];
        }
    } else {
        _didAutoPause = NO;
    }
}


- (void) _clearConfirmStop
{
    EmbraceLogMethod();

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_clearConfirmStop) object:nil];

    _confirmStop = NO;
    [[self playButton] performPopAnimation:NO toImage:[NSImage imageNamed:@"StopTemplate"] alert:NO];
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

        } else if (status == TrackStatusPreparing || status == TrackStatusPlaying) {
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


- (BOOL) addTracksWithURLs:(NSArray<NSURL *> *)urls
{
    EmbraceLog(@"SetlistController", @"-addTracksWithURLs: %@", urls);
    return [[self tracksController] addTracksWithURLs:urls];
}


- (void) copyToPasteboard:(NSPasteboard *)pasteboard
{
    EmbraceLogMethod();
    
    NSArray  *tracks   = [[self tracksController] tracks];
    NSString *contents = [[ExportManager sharedInstance] stringWithFormat:ExportManagerFormatPlainText tracks:tracks];

    NSPasteboardItem *item = [[NSPasteboardItem alloc] initWithPasteboardPropertyList:contents ofType:NSPasteboardTypeString];

    [pasteboard clearContents];
    [pasteboard writeObjects:[NSArray arrayWithObject:item]];
}


- (void) exportToFile
{
    NSArray  *tracks = [[self tracksController] tracks];
    NSInteger result = [[ExportManager sharedInstance] runModalWithTracks:tracks];

    if (result == NSFileHandlingPanelOKButton) {
        [self _markAsSaved];
    }
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
        return PlaybackActionStop;

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

    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:messageText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];

    if (informativeText) [alert setInformativeText:informativeText];
    if (otherButton)     [alert addButtonWithTitle:otherButton];
    
    if ([alert runModal] == NSAlertSecondButtonReturn) {
        [GetAppDelegate() showPreferences];
    }
}


- (void) handleNonSpaceKeyDown
{
    if (_confirmStop) {
        [self _clearConfirmStop];
    }
}



#pragma mark - IBActions

- (IBAction) performPreferredPlaybackAction:(id)sender
{
    EmbraceLogMethod();

    PlaybackAction action = [self preferredPlaybackAction];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_clearConfirmStop) object:nil];

    if (action == PlaybackActionShowIssue) {
        [self showAlertForIssue:[[Player sharedInstance] issue]];

    } else if (action == PlaybackActionStop) {
        EmbraceLog(@"SetlistController", @"Performing PlaybackActionStop, _confirmStop is %ld", (long)_confirmStop);

        if (!_confirmStop) {
            _confirmStop = YES;

            [[self playButton] performPopAnimation:YES toImage:[NSImage imageNamed:@"ConfirmTemplate"] alert:YES];
            
            [self _updatePlayButton];
            [self performSelector:@selector(_clearConfirmStop) withObject:nil afterDelay:2];

        } else {
            NSEvent *currentEvent = [NSApp currentEvent];
            NSEventType type = [currentEvent type];
            
            BOOL isDoubleClick = NO;

            EmbraceLog(@"SetlistController", @"About to -hardStop with event: %@", currentEvent);

            if ((type == NSLeftMouseDown) || (type == NSRightMouseDown) || (type == NSOtherMouseDown)) {
                isDoubleClick = [currentEvent clickCount] >= 2;
            }
        
            if (!isDoubleClick) {
                _confirmStop = NO;
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
    NSInteger value = [self minimumSilenceBetweenTracks] + 1;
    if (value > sAutoGapMaximum) value = sAutoGapMaximum;
    [self setMinimumSilenceBetweenTracks:value];
}


- (IBAction) decreaseAutoGap:(id)sender
{
    EmbraceLogMethod();
    NSInteger value = [self minimumSilenceBetweenTracks] - 1;
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


- (void) changeLabel:(id)sender
{
    NSInteger selectedTag = [sender selectedTag];
    
    if (selectedTag >= TrackLabelNone && selectedTag <= TrackLabelPurple) {
        for (Track *track in [[self tracksController] selectedTracks]) {
            [track setTrackLabel:selectedTag];
        }
    }
}


- (void) revealEndTime:(id)sender
{
    EmbraceLogMethod();

    NSArray *tracks = [[self tracksController] selectedTracks];
    if ([tracks count] == 0) return;

    [self _calculateStartAndEndTimes];

    [[self tracksController] revealEndTime:self];
}


- (BOOL) canRevealEndTime
{
    return [[self tracksController] canRevealEndTime];
}


- (IBAction) toggleStopsAfterPlaying:(id)sender
{
    EmbraceLogMethod();
    [[self tracksController] toggleStopsAfterPlaying:self];
    [self _updatePlayButton];
}


- (IBAction) toggleIgnoreAutoGap:(id)sender
{
    EmbraceLogMethod();
    [[self tracksController] toggleIgnoreAutoGap:self];
    [self _updatePlayButton];
}


- (IBAction) toggleMarkAsPlayed:(id)sender
{
    EmbraceLogMethod();
    [[self tracksController] toggleMarkAsPlayed:self];
    [self _updatePlayButton];
}


- (IBAction) showGearMenu:(id)sender
{
    EmbraceLogMethod();

    NSButton *gearButton = [self gearButton];

    NSRect bounds = [gearButton bounds];
    NSPoint point = NSMakePoint(1, CGRectGetMaxY(bounds) + 6);
    [[gearButton menu] popUpMenuPositioningItem:nil atLocation:point inView:gearButton];
}


- (IBAction) showEffects:(id)sender
{
    [GetAppDelegate() showEffectsWindow];
}


- (IBAction) showCurrentTrack:(id)sender
{
    [GetAppDelegate() showCurrentTrack];
}


#pragma mark - Delegates

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(delete:) ||
        action == @selector(toggleMarkAsPlayed:) ||
        action == @selector(toggleStopsAfterPlaying:) ||
        action == @selector(toggleIgnoreAutoGap:) ||
        action == @selector(revealEndTime:))
    {
        return [[self tracksController] validateMenuItem:menuItem];
    }
    
    return YES;
}


- (void) menuWillOpen:(NSMenu *)menu
{
    BOOL showLabels = [[Preferences sharedInstance] showsLabelDots] ||
                      [[Preferences sharedInstance] showsLabelStripes];

    NSMutableSet *selectedLabels = [NSMutableSet set];
    TrackLabel    trackLabel     = TrackLabelNone;
    
    for (Track *track in [[self tracksController] selectedTracks]) {
        [selectedLabels addObject:@([track trackLabel])];
    }

    NSInteger selectedLabelsCount = [selectedLabels count];
    if (selectedLabelsCount > 1) {
        trackLabel = TrackLabelMultiple;
    } else if (selectedLabelsCount == 1) {
        trackLabel = [[selectedLabels anyObject] integerValue];
    } else if (selectedLabelsCount == 0) {
        trackLabel = TrackLabelNone;
        showLabels = NO;
    }
    
    if ([menu isEqual:[self gearMenu]]) {
        [[self gearLabelSeparator] setHidden:!showLabels];
        [[self gearLabelMenuItem]  setHidden:!showLabels];
        [[self gearLabelMenuItem]  setView:showLabels ? [self gearLabelMenuView] : nil];

        [[self gearLabelMenuView] setSelectedTag:trackLabel];
    
    } else if ([menu isEqual:[self tableMenu]]) {
        [[self tableLabelSeparator] setHidden:!showLabels];
        [[self tableLabelMenuItem]  setHidden:!showLabels];
        [[self tableLabelMenuItem]  setView:showLabels ? [self tableLabelMenuView] : nil];
       
        [[self tableLabelMenuView] setSelectedTag:trackLabel];
    }
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


- (BOOL) window:(EmbraceWindow *)window cancelOperation:(id)sender
{
    NSArray *selectedTracks = [[self tracksController] selectedTracks];
    
    if ([selectedTracks count] > 0) {
        [[self tracksController] deselectAllTracks];
        return YES;
    }

    return NO;
}


- (void) windowDidUpdateMain:(EmbraceWindow *)window
{
    BorderedView *topContainer    = [self topContainer];
    BorderedView *bottomContainer = [self bottomContainer];
    
    if ([window isMainWindow]) {
        [topContainer    setBackgroundGradientTopColor:   [NSColor colorWithCalibratedWhite:(0xec / 255.0) alpha:1.0]];
        [topContainer    setBackgroundGradientBottomColor:[NSColor colorWithCalibratedWhite:(0xd3 / 255.0) alpha:1.0]];
        [bottomContainer setBackgroundGradientTopColor:   [NSColor colorWithCalibratedWhite:(0xe0 / 255.0) alpha:1.0]];
        [bottomContainer setBackgroundGradientBottomColor:[NSColor colorWithCalibratedWhite:(0xd3 / 255.0) alpha:1.0]];
        [topContainer    setBackgroundColor:nil];
        [bottomContainer setBackgroundColor:nil];
    } else {
        [topContainer    setBackgroundColor:GetRGBColor(0xf6f6f6, 1.0)];
        [bottomContainer setBackgroundColor:GetRGBColor(0xf6f6f6, 1.0)];
        [topContainer    setBackgroundGradientTopColor:   nil];
        [topContainer    setBackgroundGradientBottomColor:nil];
        [bottomContainer setBackgroundGradientTopColor:   nil];
        [bottomContainer setBackgroundGradientBottomColor:nil];
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
    EmbraceLog(@"SetlistController", @"player:didUpdatePlaying:%ld", (long)playing);

    if (playing) {
        [[self dangerMeter] setMetering:YES];
        [[self levelMeter] setMetering:YES];
        [[self playBar] setPlaying:YES];
        
        [[self playOffsetField]    setHidden:NO];
        [[self playRemainingField] setHidden:NO];
        
    } else {
        [[self playOffsetField] setStringValue:GetStringForTime(0)];
        [[self playRemainingField] setStringValue:GetStringForTime(0)];

        [[self playOffsetField]    setHidden:YES];
        [[self playRemainingField] setHidden:YES];

        [[self playBar] setPercentage:0];
        [[self playBar] setPlaying:NO];

        [[self dangerMeter] setMetering:NO];
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

    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:messageText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert setInformativeText:NSLocalizedString(@"You can prevent this by quitting other applications when using Embrace, or by giving Embrace exclusive access in Preferences.", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Show Preferences", nil)];

    if ([alert runModal] == NSAlertSecondButtonReturn) {
        [GetAppDelegate() showPreferences];
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

    Float32 dangerPeak        = [player dangerPeak];
    NSTimeInterval lastOverloadTime = [player lastOverloadTime];
    
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

    [[self dangerMeter] addDangerPeak:dangerPeak lastOverloadTime:lastOverloadTime];

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
    
    NSInteger minimumSilence = [self minimumSilenceBetweenTracks];
   
    if ((minimumSilence == sAutoGapMaximum) && currentTrack) {
        padding = HUGE_VAL;

    } else if (currentTrack && trackToPlay) {
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


- (void) player:(Player *)player didFinishTrack:(Track *)finishedTrack
{
    [[self tracksController] didFinishTrack:finishedTrack];
}


- (void) setMinimumSilenceBetweenTracks:(NSInteger)minimumSilenceBetweenTracks
{
    if (_minimumSilenceBetweenTracks != minimumSilenceBetweenTracks) {
        [self willChangeValueForKey:@"autoGapTimeString"];

        _minimumSilenceBetweenTracks = minimumSilenceBetweenTracks;

        [[NSUserDefaults standardUserDefaults] setInteger:minimumSilenceBetweenTracks forKey:sMinimumSilenceKey];
        [self _calculateStartAndEndTimes];

        [self didChangeValueForKey:@"autoGapTimeString"];
    }
}


- (NSString *) autoGapTimeString
{
    if (_minimumSilenceBetweenTracks == sAutoGapMinimum) {
        return NSLocalizedString(@"Off", nil);
    } else if (_minimumSilenceBetweenTracks == sAutoGapMaximum) {
        return NSLocalizedString(@"Stop", nil);
    } else {
        return GetStringForTime(_minimumSilenceBetweenTracks);
    }
}


@end
