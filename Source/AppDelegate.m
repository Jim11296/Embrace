// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "AppDelegate.h"

#import "SetlistController.h"
#import "EffectsController.h"
#import "PreferencesController.h"
#import "EditGraphicEQEffectController.h"
#import "EditSystemEffectController.h"
#import "CurrentTrackController.h"
#import "ViewTrackController.h"
#import "TracksController.h"
#import "Preferences.h"
#import "DebugController.h"
#import "EffectAdditions.h"

#import "Player.h"
#import "Effect.h"
#import "Track.h"
#import "CrashPadClient.h"

#import "IssueManager.h"
#import "iTunesManager.h"
#import "ScriptsManager.h"
#import "WrappedAudioDevice.h"

#import "WorkerService.h"

#import "CrashReportSender.h"
#import "MTSEscapePod.h"
#import "MTSTelemetry.h"

@interface AppDelegate ()

- (IBAction) openFile:(id)sender;

- (IBAction) clearSetlist:(id)sender;
- (IBAction) resetPlayedTracks:(id)sender;

- (IBAction) copySetlist:(id)sender;
- (IBAction) saveSetlist:(id)sender;
- (IBAction) exportSetlist:(id)sender;

- (IBAction) changeNumberOfLayoutLines:(id)sender;
- (IBAction) changeShortensPlayedTracks:(id)sender;

- (IBAction) changeKeySignatureDisplayMode:(id)sender;
- (IBAction) revealTime:(id)sender;

- (IBAction) performPreferredPlaybackAction:(id)sender;
- (IBAction) hardSkip:(id)sender;
- (IBAction) hardStop:(id)sender;

- (IBAction) increaseVolume:(id)sender;
- (IBAction) decreaseVolume:(id)sender;
- (IBAction) increaseAutoGap:(id)sender;
- (IBAction) decreaseAutoGap:(id)sender;

- (IBAction) showSetlistWindow:(id)sender;
- (IBAction) showEffectsWindow:(id)sender;
- (IBAction) showPreferences:(id)sender;
- (IBAction) showCurrentTrack:(id)sender;

- (IBAction) sendFeedback:(id)sender;
- (IBAction) viewOnAppStore:(id)sender;

- (IBAction) openAcknowledgements:(id)sender;

- (IBAction) showDebugWindow:(id)sender;
- (IBAction) sendCrashReports:(id)sender;
- (IBAction) openSupportFolder:(id)sender;

@property (nonatomic, weak) IBOutlet NSMenuItem *debugMenuItem;

@property (nonatomic, weak) IBOutlet NSMenuItem *crashReportSeparator;
@property (nonatomic, weak) IBOutlet NSMenuItem *crashReportMenuItem;

@property (nonatomic, weak) IBOutlet NSMenuItem *openSupportSeparator;
@property (nonatomic, weak) IBOutlet NSMenuItem *sendLogsMenuItem;
@property (nonatomic, weak) IBOutlet NSMenuItem *openSupportMenuItem;

@end

@implementation AppDelegate {
    SetlistController      *_setlistController;
    EffectsController      *_effectsController;
    NSWindowController     *_currentTrackController;
    PreferencesController  *_preferencesController;

#if DEBUG
    DebugController        *_debugController;
#endif

    NSMutableArray    *_editEffectControllers;
    NSMutableArray    *_viewTrackControllers;
    
    NSXPCConnection   *_connectionToWorker;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    EmbraceLogMethod();

    EmbraceCheckCompatibility();

    // Load preferences
    [Preferences sharedInstance];

    // Load issue manager
    [IssueManager sharedInstance];

    // Start parsing iTunes XML
    [iTunesManager sharedInstance];
    
    // Load scripts
    [ScriptsManager sharedInstance];
    
    [EffectType embrace_registerMappedEffects];

    MTSTelemetrySetBasePath(GetApplicationSupportDirectory());
    
    NSString *escapePodTelemetryName = @"Crashes";
    
    MTSEscapePodSetTelemetryName(escapePodTelemetryName);

    MTSTelemetryRegisterURL(escapePodTelemetryName, [NSURL URLWithString:@"<redacted>"]);

    if (!CrashPadIsDebuggerAttached()) {
        SetupCrashPad();
        MTSEscapePodInstall();
        MTSTelemetrySend(MTSEscapePodGetTelemetryName(), NO);
    }

    _setlistController      = [[SetlistController alloc] init];
    _effectsController      = [[EffectsController alloc] init];
    _currentTrackController = [[CurrentTrackController alloc] init];

    [self _showPreviouslyVisibleWindows];

    BOOL hasCrashReports = MTSTelemetryHasContents(MTSEscapePodGetTelemetryName());
    
    [[self crashReportMenuItem] setHidden:!hasCrashReports];
    [[self crashReportSeparator] setHidden:!hasCrashReports];

#ifdef DEBUG
    [[self debugMenuItem] setHidden:NO];
#endif

    EmbraceLog(@"Hello", @"Embrace finished launching at %@", [NSDate date]);

    EmbraceLog(@"Migration", @"Current build is %@, latest build is %@.",
        GetAppBuildString(),
        [[Preferences sharedInstance] latestBuildString]);
}


- (void) _showPreviouslyVisibleWindows
{
    NSArray *visibleWindows = [[NSUserDefaults standardUserDefaults] objectForKey:@"visible-windows"];
    
    if ([visibleWindows containsObject:@"current-track"]) {
        [self showCurrentTrack:self];
    }

    // Always show Set List
    [self showSetlistWindow:self];
    
#ifdef DEBUG
    [[self debugMenuItem] setHidden:NO];
#endif
}


- (void) _saveVisibleWindows
{
    NSMutableArray *visibleWindows = [NSMutableArray array];
    
    if ([[_setlistController window] isVisible]) {
        [visibleWindows addObject:@"setlist"];
    }

    if ([[_currentTrackController window] isVisible]) {
        [visibleWindows addObject:@"current-track"];
    }

    [[NSUserDefaults standardUserDefaults] setObject:visibleWindows forKey:@"visible-windows"];
}


- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows
{
    EmbraceLogMethod();

    if (!hasVisibleWindows) {
        [self showSetlistWindow:self];
    }

    return YES;
}


- (BOOL) application:(NSApplication *)sender openFile:(NSString *)filename
{
    EmbraceLogMethod();

    NSURL *fileURL = [NSURL fileURLWithPath:filename];

    if (fileURL) {
        return [_setlistController addTracksWithURLs:@[ fileURL ]];
    }

    return NO;
}


- (void) application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    EmbraceLogMethod();

    NSMutableArray *fileURLs = [NSMutableArray array];
    
    for (NSString *filename in [filenames reverseObjectEnumerator]) {
        NSURL *fileURL = [NSURL fileURLWithPath:filename];
        if (fileURL) [fileURLs addObject:fileURL];
    }

    [_setlistController addTracksWithURLs:fileURLs];
}


- (void) applicationWillTerminate:(NSNotification *)notification
{
    EmbraceLogMethod();

    [self _saveVisibleWindows];

    [[Player sharedInstance] saveEffectState];
    [[Player sharedInstance] hardStop];
    
    [WrappedAudioDevice releaseHoggedDevices];
}


- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
    EmbraceLogMethod();

    if ([[Player sharedInstance] isPlaying]) {
        NSAlert *alert = [[NSAlert alloc] init];

        [alert setMessageText:NSLocalizedString(@"Quit Embrace", nil)];
        [alert setInformativeText:NSLocalizedString(@"Music is currently playing. Are you sure you want to quit?", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Quit",   nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        [alert setAlertStyle:NSAlertStyleCritical];

        return [alert runModal] == NSAlertFirstButtonReturn ? NSTerminateNow : NSTerminateCancel;
    }
    
    return NSTerminateNow;
}


#pragma mark - Private Methods

- (EditEffectController *) _equalizerEffectController
{
    for (Effect *effect in [[Player sharedInstance] effects]) {
        NSString *effectName = [[effect type] name];

        if ([effectName isEqualToString:EmbraceMappedEffect10BandEQ] ||
            [effectName isEqualToString:EmbraceMappedEffect31BandEQ] ||
            [effectName isEqualToString:@"AUGraphicEQ"] ||
            [effectName isEqualToString:@"AUNBandEQ"]
        ) {
            return [self editControllerForEffect:effect];
        }
    }

    return nil;
}


- (void) _toggleWindowForController:(NSWindowController *)controller sender:(id)sender
{
    BOOL orderIn = YES;

    if ([sender isKindOfClass:[NSMenuItem class]]) {
        if ([sender state] == NSControlStateValueOn) {
            orderIn = NO;
        }
    }
    
    if (orderIn) {
        [controller showWindow:self];
    } else {
        [[controller window] orderOut:self];
    }
}


#pragma mark - Public Methods

- (void) _clearConnectionToWorker
{
    [_connectionToWorker setInvalidationHandler:nil];
    _connectionToWorker = nil;
}


- (id<WorkerProtocol>) workerProxyWithErrorHandler:(void (^)(NSError *error))handler
{
    if (!_connectionToWorker) {
        __weak id weakSelf = self;

        NSXPCInterface *interface = [NSXPCInterface interfaceWithProtocol:@protocol(WorkerProtocol)];

        NSString *serviceName = @"com.iccir.Embrace.EmbraceWorker";
#if TRIAL
        serviceName = @"com.iccir.Embrace-Trial.EmbraceWorker";
#endif
    
        NSXPCConnection *connection = [[NSXPCConnection alloc] initWithServiceName:serviceName];
        [connection setRemoteObjectInterface:interface];

        [connection setInvalidationHandler:^{
            [weakSelf _clearConnectionToWorker];
        }];
            
        _connectionToWorker = connection;
        [_connectionToWorker resume];
    }
    
    return [_connectionToWorker remoteObjectProxyWithErrorHandler:handler];
}


- (void) performPreferredPlaybackAction
{
    [self performPreferredPlaybackAction:self];
}


- (void) displayErrorForTrack:(Track *)track
{
    TrackError trackError = [track trackError];
    if (!trackError) return;

    NSString *messageText     = @"";
    NSString *informativeText = @"";
    
    if (trackError == TrackErrorConversionFailed) {
        messageText = NSLocalizedString(@"The file cannot be read because it is in an unknown format.", nil);
    
    } else if (trackError == TrackErrorProtectedContent) {
        messageText     = NSLocalizedString(@"The file cannot be read because it is protected.", nil);
        informativeText = NSLocalizedString(@"Protected content can only be played with iTunes.\n\nIf this file was downloaded from Apple Music, you will need to first remove the download and then purchase it from the iTunes Store.", nil);

    } else if (trackError == TrackErrorOpenFailed) {
        messageText = NSLocalizedString(@"The file cannot be opened.", nil);
    
    } else {
        messageText = NSLocalizedString(@"The file cannot be read.", nil);
    }
    
    if (![messageText length]) {
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert setMessageText:messageText];
    [alert setInformativeText:informativeText];

    [alert runModal];
}


- (void) showEffectsWindow
{
    [self showEffectsWindow:self];
}


- (void) showCurrentTrack
{
    [self showCurrentTrack:self];
}


- (void) showPreferences
{
    [self showPreferences:self];
}


- (EditEffectController *) editControllerForEffect:(Effect *)effect
{
    if (!_editEffectControllers) {
        _editEffectControllers = [NSMutableArray array];
    }

    for (EditEffectController *controller in _editEffectControllers) {
        if ([[controller effect] isEqual:effect]) {
            return controller;
        }
    }
    
    Class cls = [EditSystemEffectController class];
    NSString *effectName = [[effect type] name];

    if ([effectName isEqualToString:EmbraceMappedEffect10BandEQ] ||
        [effectName isEqualToString:EmbraceMappedEffect31BandEQ]
    ) {
        cls = [EditGraphicEQEffectController class];
    }
    
    EditEffectController *controller = [[cls alloc] initWithEffect:effect index:[_editEffectControllers count]];

    if (controller) {
        [_editEffectControllers addObject:controller];
    }

    return controller;
}


- (void) closeEditControllerForEffect:(Effect *)effect
{
    NSMutableArray *toRemove = [NSMutableArray array];

    for (EditEffectController *controller in _editEffectControllers) {
        if ([controller effect] == effect) {
            [controller close];
            if (controller) [toRemove addObject:controller];
        }
    }
    
    [_editEffectControllers removeObjectsInArray:toRemove];
}


- (ViewTrackController *) viewTrackControllerForTrack:(Track *)track
{
    if (!_viewTrackControllers) {
        _viewTrackControllers = [NSMutableArray array];
    }

    for (ViewTrackController *controller in _viewTrackControllers) {
        if ([[controller track] isEqual:track]) {
            return controller;
        }
    }
    
    ViewTrackController *controller = [[ViewTrackController alloc] initWithTrack:track];
    if (controller) [_viewTrackControllers addObject:controller];
    return controller;
}


- (void) closeViewTrackControllerForEffect:(Track *)track
{
    NSMutableArray *toRemove = [NSMutableArray array];

    for (ViewTrackController *controller in _viewTrackControllers) {
        if ([controller track] == track) {
            [controller close];
            if (controller) [toRemove addObject:controller];
        }
    }
    
    [_viewTrackControllers removeObjectsInArray:toRemove];
}


#pragma mark - IBActions

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(performPreferredPlaybackAction:)) {
        PlaybackAction playbackAction = [_setlistController preferredPlaybackAction];
        
        NSString *title = NSLocalizedString(@"Play", nil);
        BOOL enabled = [_setlistController isPreferredPlaybackActionEnabled];
        NSInteger state = NSControlStateValueOff;
        
        if (playbackAction == PlaybackActionShowIssue) {
            title = NSLocalizedString(@"Show Issue", nil);

        } else if (playbackAction == PlaybackActionStop) {
            title = NSLocalizedString(@"Stop", nil);
        }

        [menuItem setState:state];
        [menuItem setTitle:title];
        [menuItem setEnabled:enabled];
        [menuItem setKeyEquivalent:@" "];

    } else if (action == @selector(clearSetlist:)) {
        if ([_setlistController shouldPromptForClear]) {
            [menuItem setTitle:NSLocalizedString(@"Clear Set List\\U2026", nil)];
        } else {
            [menuItem setTitle:NSLocalizedString(@"Clear Set List", nil)];
        }

// Disable this when playing in the trial version.  Else it's too easy to DJ with the trial.
#if TRIAL
        return ![[Player sharedInstance] isPlaying];
#endif

        return YES;
    
    } else if (action == @selector(resetPlayedTracks:)) {
        if ([_setlistController shouldPromptForClear]) {
            [menuItem setTitle:NSLocalizedString(@"Reset Played Tracks\\U2026", nil)];
        } else {
            [menuItem setTitle:NSLocalizedString(@"Reset Played Tracks", nil)];
        }

        return ![[Player sharedInstance] isPlaying];
    
    } else if (action == @selector(hardStop:)) {
        return [[Player sharedInstance] isPlaying];

    } else if (action == @selector(hardSkip:)) {
        return [[Player sharedInstance] isPlaying];

    } else if (action == @selector(showSetlistWindow:)) {
        BOOL yn = [_setlistController isWindowLoaded] && [[_setlistController window] isMainWindow];
        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];
    
    } else if (action == @selector(showEffectsWindow:)) {
        BOOL yn = [_effectsController isWindowLoaded] && [[_effectsController window] isMainWindow];
        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];
    
    } else if (action == @selector(showCurrentTrack:)) {
        BOOL yn = [_currentTrackController isWindowLoaded] && [[_currentTrackController window] isMainWindow];
        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];
        
    } else if (action == @selector(showEqualizer:)) {
        EditEffectController *equalizerController = [self _equalizerEffectController];

        if (equalizerController) {
            BOOL yn = [equalizerController isWindowLoaded] && [[equalizerController window] isMainWindow];
            [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];

        } else {
            [menuItem setState:NSControlStateValueOff];
            return NO;
        }
        
    } else if (action == @selector(changeTrackAttributes:)) {
        TrackViewAttribute viewAttribute = [menuItem tag];
        BOOL isEnabled = [[Preferences sharedInstance] numberOfLayoutLines] > 1;
        
        if (viewAttribute == TrackViewAttributeDuplicateStatus) {
            isEnabled = YES;
        }

        BOOL yn = [[Preferences sharedInstance] isTrackViewAttributeSelected:viewAttribute];
       
        if (!isEnabled) yn = NO;

        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];
        
        return isEnabled;

    } else if (action == @selector(changeKeySignatureDisplayMode:)) {
        KeySignatureDisplayMode mode = [[Preferences sharedInstance] keySignatureDisplayMode];
        BOOL yn = mode == [menuItem tag];
        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];

    } else if (action == @selector(changeDuplicateStatusMode:)) {
        DuplicateStatusMode mode = [[Preferences sharedInstance] duplicateStatusMode];
        BOOL yn = mode == [menuItem tag];
        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];
    
    } else if (action == @selector(changeNumberOfLayoutLines:)) {
        NSInteger yn = ([[Preferences sharedInstance] numberOfLayoutLines] == [menuItem tag]);
        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];

    } else if (action == @selector(changeShortensPlayedTracks:)) {
        NSInteger yn = [[Preferences sharedInstance] shortensPlayedTracks];
        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];

    } else if (action == @selector(changeFloatsOnTop:)) {
        NSInteger yn = [[Preferences sharedInstance] floatsOnTop];
        [menuItem setState:(yn ? NSControlStateValueOn : NSControlStateValueOff)];

    } else if (action == @selector(revealTime:)) {
        return [_setlistController validateMenuItem:menuItem];

    } else if (action == @selector(sendCrashReports:)){
        BOOL hasCrashReports = MTSTelemetryHasContents(MTSEscapePodGetTelemetryName());

        [[self crashReportMenuItem]  setHidden:!hasCrashReports];
        [[self crashReportSeparator] setHidden:!hasCrashReports];

        return YES;

    } else if (action == @selector(openSupportFolder:)){
        NSUInteger modifierFlags = [NSEvent modifierFlags];
        
        NSUInteger mask = NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand;
        BOOL visible = ((modifierFlags & mask) == mask);
    
        [[self openSupportSeparator] setHidden:!visible];
        [[self openSupportMenuItem]  setHidden:!visible];
        [[self sendLogsMenuItem]     setHidden:!visible];

        return YES;
    }

    return YES;
}


- (IBAction) clearSetlist:(id)sender
{
    EmbraceLogMethod();

    if ([_setlistController shouldPromptForClear]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert setMessageText:NSLocalizedString(@"Clear Set List", nil)];
        [alert setInformativeText:NSLocalizedString(@"You haven't saved or exported the current set list. Are you sure you want to clear it?", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Clear",  nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            [_setlistController clear];
        }
    
    } else {
        [_setlistController clear];
    }
}


- (IBAction) resetPlayedTracks:(id)sender
{
    EmbraceLogMethod();

    if ([_setlistController shouldPromptForClear]) {
        NSAlert *alert = [[NSAlert alloc] init];

        [alert setMessageText:NSLocalizedString(@"Reset Played Tracks", nil)];
        [alert setInformativeText:NSLocalizedString(@"Are you sure you want to reset all played tracks to the queued state?", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Reset",  nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            [_setlistController resetPlayedTracks];
        }
    
    } else {
        [_setlistController resetPlayedTracks];
    }
}


- (IBAction) openFile:(id)sender
{
    EmbraceLogMethod();

    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    if (!LoadPanelState(openPanel, @"open-file-panel")) {
        NSString *musicPath = [NSSearchPathForDirectoriesInDomains(NSMusicDirectory, NSUserDomainMask, YES) firstObject];
        
        if (musicPath) {
            [openPanel setDirectoryURL:[NSURL fileURLWithPath:musicPath]];
        }
    }
    
    [openPanel setTitle:NSLocalizedString(@"Add to Set List", nil)];
    [openPanel setAllowedFileTypes:GetAvailableAudioFileUTIs()];

    __weak id weakSetlistController = _setlistController;


    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            SavePanelState(openPanel, @"open-file-panel");
            
            NSURL *url = [openPanel URL];
            if (url) {
                [weakSetlistController addTracksWithURLs:@[ url ]];
            }
        }
    }];
}


- (IBAction) copySetlist:(id)sender
{
    EmbraceLogMethod();

    [_setlistController copyToPasteboard:[NSPasteboard generalPasteboard]];
}


- (IBAction) saveSetlist:(id)sender
{
    EmbraceLogMethod();
    [_setlistController exportToFile];
}


- (IBAction) changeNumberOfLayoutLines:(id)sender
{
    EmbraceLogMethod();
    [[Preferences sharedInstance] setNumberOfLayoutLines:[sender tag]];
}


- (IBAction) changeShortensPlayedTracks:(id)sender
{
    EmbraceLogMethod();
    
    Preferences *preferences = [Preferences sharedInstance];
    [preferences setShortensPlayedTracks:![preferences shortensPlayedTracks]];
}


- (IBAction) changeTrackAttributes:(id)sender
{
    EmbraceLogMethod();

    Preferences *preferences = [Preferences sharedInstance];
    TrackViewAttribute attribute = [sender tag];
    
    BOOL yn = [preferences isTrackViewAttributeSelected:attribute];
    [preferences setTrackViewAttribute:attribute selected:!yn];
}


- (IBAction) changeKeySignatureDisplayMode:(id)sender
{
    EmbraceLogMethod();

    Preferences *preferences = [Preferences sharedInstance];
    [preferences setKeySignatureDisplayMode:[sender tag]];
}


- (IBAction) changeDuplicateStatusMode:(id)sender
{
    EmbraceLogMethod();

    Preferences *preferences = [Preferences sharedInstance];
    [preferences setDuplicateStatusMode:[sender tag]];
    
    [_setlistController detectDuplicates];
}


- (IBAction) exportSetlist:(id)sender   {  EmbraceLogMethod();  [_setlistController exportToPlaylist];     }
- (IBAction) increaseAutoGap:(id)sender {  EmbraceLogMethod();  [_setlistController increaseAutoGap:self]; }
- (IBAction) decreaseAutoGap:(id)sender {  EmbraceLogMethod();  [_setlistController decreaseAutoGap:self]; }
- (IBAction) revealTime:(id)sender      {  EmbraceLogMethod();  [_setlistController revealTime:self];      }


- (IBAction) performPreferredPlaybackAction:(id)sender
{
    EmbraceLog(@"AppDelegate", @"performPreferredPlaybackAction:  sender=%@, event=%@", sender, [NSApp currentEvent]);
    [_setlistController performPreferredPlaybackAction:self];
}


- (IBAction) increaseVolume:(id)sender
{
    EmbraceLog(@"AppDelegate", @"increaseVolume:  sender=%@, event=%@", sender, [NSApp currentEvent]);
    [_setlistController increaseVolume:self];
}


- (IBAction) decreaseVolume:(id)sender
{
    EmbraceLog(@"AppDelegate", @"decreaseVolume:  sender=%@, event=%@", sender, [NSApp currentEvent]);
    [_setlistController decreaseVolume:self];
}


- (IBAction) hardSkip:(id)sender
{
    EmbraceLog(@"AppDelegate", @"hardSkip:  sender=%@, event=%@", sender, [NSApp currentEvent]);
    [[Player sharedInstance] hardSkip];
}


- (IBAction) hardStop:(id)sender
{
    EmbraceLog(@"AppDelegate", @"hardStop:  sender=%@, event=%@", sender, [NSApp currentEvent]);
    [[Player sharedInstance] hardStop];
}


- (IBAction) showSetlistWindow:(id)sender
{
    EmbraceLogMethod();
    [self _toggleWindowForController:_setlistController sender:sender];
}


- (IBAction) showEffectsWindow:(id)sender
{
    EmbraceLogMethod();
    [self _toggleWindowForController:_effectsController sender:sender];
}


- (IBAction) showCurrentTrack:(id)sender
{
    EmbraceLogMethod();
    [self _toggleWindowForController:_currentTrackController sender:sender];
}


- (IBAction) showEqualizer:(id)sender
{
    EmbraceLogMethod();

    EditEffectController *equalizerController = [self _equalizerEffectController];
    if (equalizerController) {
        [self _toggleWindowForController:equalizerController sender:sender];
    }
}


- (IBAction) showDebugWindow:(id)sender
{
#if DEBUG
    EmbraceLogMethod();

    if (!_debugController) {
        _debugController = [[DebugController alloc] init];
    }

    [_debugController showWindow:self];
#endif
}


- (IBAction) sendCrashReports:(id)sender
{
    EmbraceLogMethod();

    NSAlert *(^makeAlertOne)() = ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert setMessageText:NSLocalizedString(@"Send Crash Report?", nil)];
        [alert setInformativeText:NSLocalizedString(@"Information about the crash, your operating system, and device will be sent. No personal information is included.", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Send", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

        return alert;
    };

    NSAlert *(^makeAlertTwo)() = ^{
        NSAlert *alert = [[NSAlert alloc] init];

        [alert setMessageText:NSLocalizedString(@"Crash Report Sent", nil)];
        [alert setInformativeText:NSLocalizedString(@"Thank you for your crash report.  If you have any additional information regarding the crash, please contact me.", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Contact", nil)];

        return alert;
    };
    
    BOOL okToSend = [makeAlertOne() runModal] == NSAlertFirstButtonReturn;

    if (okToSend) {
        [CrashReportSender sendCrashReportsWithCompletionHandler:^(BOOL didSend) {
            NSModalResponse response = [makeAlertTwo() runModal];
            
            if (response == NSAlertSecondButtonReturn) {
                [self sendFeedback:nil];
            }
        }];
    }
}


- (IBAction) sendLogs:(id)sender
{
    EmbraceLogMethod();

    NSAlert *(^makeAlertOne)() = ^{
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert setMessageText:NSLocalizedString(@"Send Logs?", nil)];
        [alert setInformativeText:NSLocalizedString(@"Detailed logs containing your set lists and usage will be sent.", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Send", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

        return alert;
    };

    NSAlert *(^makeAlertTwo)(BOOL) = ^(BOOL didSend) {
        NSAlert *alert = [[NSAlert alloc] init];

        if (didSend) {
            [alert setMessageText:NSLocalizedString(@"Logs Sent", nil)];
            [alert setInformativeText:NSLocalizedString(@"Thank you for your logs.  If you have any additional information, please contact me.", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Contact", nil)];
        } else {
            [alert setMessageText:NSLocalizedString(@"Error", nil)];
            [alert setInformativeText:NSLocalizedString(@"Your logs could not be sent.  Please try again.", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
        }

        return alert;
    };
    
    BOOL okToSend = [makeAlertOne() runModal] == NSAlertFirstButtonReturn;

    if (okToSend) {
        [CrashReportSender sendLogsWithCompletionHandler:^(BOOL didSend) {
            NSModalResponse response = [makeAlertTwo(didSend) runModal];
            
            if (response == NSAlertSecondButtonReturn) {
                [self sendFeedback:nil];
            }
        }];
    }
}


- (IBAction) openSupportFolder:(id)sender
{
    EmbraceLogMethod();
    [[NSWorkspace sharedWorkspace] openFile:GetApplicationSupportDirectory()];
}


- (IBAction) showPreferences:(id)sender
{
    EmbraceLogMethod();

    if (!_preferencesController) {
        _preferencesController = [[PreferencesController alloc] init];
    }

    [_preferencesController showWindow:self];
}


- (IBAction) changeFloatsOnTop:(id)sender
{
    EmbraceLogMethod();
    
    Preferences *preferences = [Preferences sharedInstance];
    BOOL floatsOnTop = [preferences floatsOnTop];
   
    [[Preferences sharedInstance] setFloatsOnTop:!floatsOnTop];
}


- (IBAction) sendFeedback:(id)sender
{
    EmbraceLogMethod();

    NSURL *url = [NSURL URLWithString:@"http://www.ricciadams.com/contact/"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction) viewWebsite:(id)sender
{
    EmbraceLogMethod();

    NSURL *url = [NSURL URLWithString:@"http://www.ricciadams.com/projects/embrace"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}



- (IBAction) viewFacebookGroup:(id)sender
{
    EmbraceLogMethod();

    NSURL *url = [NSURL URLWithString:@"https://www.facebook.com/groups/embrace.users"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}



- (IBAction) viewOnAppStore:(id)sender
{
    EmbraceLogMethod();

    NSURL *url = [NSURL URLWithString:@"http://www.ricciadams.com/buy/embrace"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction) openAcknowledgements:(id)sender
{
    EmbraceLogMethod();

    NSString *fromPath = [[NSBundle mainBundle] pathForResource:@"Acknowledgements" ofType:@"rtf"];
    NSString *toPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[fromPath lastPathComponent]];

    NSError *error;

    if ([[NSFileManager defaultManager] fileExistsAtPath:toPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:toPath error:&error];
    }

    [[NSFileManager defaultManager] copyItemAtPath:fromPath toPath:toPath error:&error];

    [[NSFileManager defaultManager] setAttributes:@{
        NSFilePosixPermissions: @0444
    } ofItemAtPath:toPath error:&error];
    
    [[NSWorkspace sharedWorkspace] openFile:toPath];
}


@end
