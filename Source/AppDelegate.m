//
//  AppDelegate.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "AppDelegate.h"

#import "SetlistController.h"
#import "EffectsController.h"
#import "PreferencesController.h"
#import "EditEffectController.h"
#import "CurrentTrackController.h"
#import "ViewTrackController.h"
#import "TracksController.h"
#import "Preferences.h"
#import "DebugController.h"

#import "Player.h"
#import "Effect.h"
#import "Track.h"
#import "CrashPadClient.h"

#import "iTunesManager.h"
#import "WrappedAudioDevice.h"

#import <CrashReporter.h>
#import "CrashReportSender.h"


@implementation AppDelegate {
    SetlistController      *_setlistController;
    EffectsController      *_effectsController;
    CurrentTrackController *_currentTrackController;
    PreferencesController  *_preferencesController;

#if DEBUG
    DebugController        *_debugController;
#endif

    PLCrashReporter   *_crashReporter;
    CrashReportSender *_crashSender;

    NSMutableArray         *_editEffectControllers;
    NSMutableArray         *_viewTrackControllers;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Load preferences
    [Preferences sharedInstance];

    // Start parsing iTunes XML
    [iTunesManager sharedInstance];
    
    PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeBSD symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll];
    _crashReporter = [[PLCrashReporter alloc] initWithConfiguration:config];
    
    _crashSender = [[CrashReportSender alloc] initWithAppIdentifier:@"<redacted>"];

    [_crashSender extractPendingReportFromReporter:_crashReporter];
    SetupCrashPad(_crashReporter);
    
    if (![CrashReportSender isDebuggerAttached]) {
        [_crashReporter enableCrashReporter];
    }

    _setlistController      = [[SetlistController     alloc] init];
    _effectsController      = [[EffectsController      alloc] init];
    _currentTrackController = [[CurrentTrackController alloc] init];
    
    [self _showPreviouslyVisibleWindows];

    BOOL hasCrashReports = [_crashSender hasCrashReports];

    [[self crashReportMenuItem] setHidden:!hasCrashReports];
    [[self crashReportSeparator] setHidden:!hasCrashReports];

#ifdef DEBUG
    [[self debugMenuItem] setHidden:NO];
#endif

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
    if (!hasVisibleWindows) {
        [self showSetlistWindow:self];
    }

    return YES;
}


- (BOOL) application:(NSApplication *)sender openFile:(NSString *)filename
{
    NSURL *fileURL = [NSURL fileURLWithPath:filename];

    if (IsAudioFileAtURL(fileURL)) {
        [_setlistController openFileAtURL:fileURL];
        return YES;
    }

    return NO;
}


- (void) application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    for (NSString *filename in [filenames reverseObjectEnumerator]) {
        NSURL *fileURL = [NSURL fileURLWithPath:filename];

        if (IsAudioFileAtURL(fileURL)) {
            [_setlistController openFileAtURL:fileURL];
        }
    }
}


- (void) applicationWillTerminate:(NSNotification *)notification
{
    [self _saveVisibleWindows];

    [[Player sharedInstance] saveEffectState];
    [[Player sharedInstance] hardStop];
    
    [WrappedAudioDevice releaseHoggedDevices];
}


- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
    if ([[Player sharedInstance] isPlaying]) {
        NSString *messageText     = NSLocalizedString(@"Quit Embrace", nil);
        NSString *informativeText = NSLocalizedString(@"Music is currently playing. Are you sure you want to quit?", nil);
        NSString *defaultButton   = NSLocalizedString(@"Quit", nil);
        
        NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:defaultButton alternateButton:NSLocalizedString(@"Cancel", nil) otherButton:nil informativeTextWithFormat:@"%@", informativeText];
        [alert setAlertStyle:NSCriticalAlertStyle];
        
        return [alert runModal] == NSOKButton ? NSTerminateNow : NSTerminateCancel;
    }
    
    return NSTerminateNow;
}


- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(performPreferredPlaybackAction:)) {
        PlaybackAction playbackAction = [_setlistController preferredPlaybackAction];
        
        NSString *title = NSLocalizedString(@"Play", nil);
        BOOL enabled = [_setlistController isPreferredPlaybackActionEnabled];
        NSInteger state = NSOffState;
        
        if (playbackAction == PlaybackActionShowIssue) {
            title = NSLocalizedString(@"Show Issue", nil);

        } else if (playbackAction == PlaybackActionTogglePause) {
            title = NSLocalizedString(@"Pause", nil);
            
            BOOL yn = [[[Player sharedInstance] currentTrack] pausesAfterPlaying];
            state = yn ? NSOnState : NSOffState;
            
        } else if (playbackAction == PlaybackActionPause) {
            title = NSLocalizedString(@"Pause", nil);
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

        return YES;
    
    } else if (action == @selector(resetPlayedTracks:)) {
        if ([_setlistController shouldPromptForClear]) {
            [menuItem setTitle:NSLocalizedString(@"Reset Played Tracks\\U2026", nil)];
        } else {
            [menuItem setTitle:NSLocalizedString(@"Reset Played Tracks", nil)];
        }

        return ![[Player sharedInstance] isPlaying];
    
    } else if (action == @selector(hardPause:)) {
        return [[Player sharedInstance] isPlaying];

    } else if (action == @selector(hardSkip:)) {
        return [[Player sharedInstance] isPlaying];

    } else if (action == @selector(showSetlistWindow:)) {
        BOOL yn = [_setlistController isWindowLoaded] && [[_setlistController window] isMainWindow];
        [menuItem setState:(yn ? NSOnState : NSOffState)];
    
    } else if (action == @selector(showEffectsWindow:)) {
        BOOL yn = [_effectsController isWindowLoaded] && [[_effectsController window] isMainWindow];
        [menuItem setState:(yn ? NSOnState : NSOffState)];
    
    } else if (action == @selector(showCurrentTrack:)) {
        BOOL yn = [_currentTrackController isWindowLoaded] && [[_currentTrackController window] isMainWindow];
        [menuItem setState:(yn ? NSOnState : NSOffState)];

    } else if (action == @selector(changeViewAttributes:)) {
        BOOL isEnabled = [[Preferences sharedInstance] numberOfLayoutLines] > 1;

        BOOL yn = [[Preferences sharedInstance] isViewAttributeSelected:[menuItem tag]];
        if (!isEnabled) yn = NO;

        [menuItem setState:(yn ? NSOnState : NSOffState)];
        
        return isEnabled;

    } else if (action == @selector(changeKeySignatureDisplay:)) {
        KeySignatureDisplayMode mode = [[Preferences sharedInstance] keySignatureDisplayMode];
        BOOL yn = mode == [menuItem tag];
        [menuItem setState:(yn ? NSOnState : NSOffState)];
    
    } else if (action == @selector(changeViewLayout:)) {
        NSInteger yn = ([[Preferences sharedInstance] numberOfLayoutLines] == [menuItem tag]);
        [menuItem setState:(yn ? NSOnState : NSOffState)];

    } else if (action == @selector(revealEndTime:)) {
        return [_setlistController canRevealEndTime];

    } else if (action == @selector(sendCrashReports:)){
        BOOL hasCrashReports = [_crashSender hasCrashReports];

        [[self crashReportMenuItem]  setHidden:!hasCrashReports];
        [[self crashReportSeparator] setHidden:!hasCrashReports];

        return YES;

    } else if (action == @selector(openSupportFolder:)){
        NSUInteger modifierFlags = [NSEvent modifierFlags];
        
        NSUInteger mask = NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask;
        BOOL visible = ((modifierFlags & mask) == mask);
    
        [[self openSupportSeparator] setHidden:!visible];
        [[self openSupportMenuItem]  setHidden:!visible];

        return YES;
    }

    return YES;
}

- (void) displayErrorForTrackError:(NSInteger)trackError
{
    if (!trackError) return;

    NSString *messageText     = @"";
    NSString *informativeText = @"";
    
    if (trackError == TrackErrorConversionFailed) {
        messageText = NSLocalizedString(@"The file cannot be read because it is in an unknown format.", nil);
    
    } else if (trackError == TrackErrorProtectedContent) {
        messageText     = NSLocalizedString(@"The file cannot be read because it is protected.", nil);
        informativeText = NSLocalizedString(@"Protected content can only be played with iTunes or Quicktime Player.", nil);

    } else if (trackError == TrackErrorOpenFailed) {
        messageText = NSLocalizedString(@"The file cannot be opened.", nil);
    
    } else {
        messageText = NSLocalizedString(@"The file cannot be read.", nil);
    }
    
    if (![messageText length]) {
        return;
    }
    
    NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", informativeText];

    [alert runModal];
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
    
    EditEffectController *controller = [[EditEffectController alloc] initWithEffect:effect index:[_editEffectControllers count]];

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


- (IBAction) clearSetlist:(id)sender
{
    if ([_setlistController shouldPromptForClear]) {
        NSString *messageText     = NSLocalizedString(@"Clear Set List", nil);
        NSString *informativeText = NSLocalizedString(@"You haven't saved or exported the current set list. Are you sure you want to clear it?", nil);
        NSString *defaultButton   = NSLocalizedString(@"Clear", nil);
        
        NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:defaultButton alternateButton:NSLocalizedString(@"Cancel", nil) otherButton:nil informativeTextWithFormat:@"%@", informativeText];
        
        if ([alert runModal] == NSOKButton) {
            [_setlistController clear];
        }
    
    } else {
        [_setlistController clear];
    }
}


- (IBAction) resetPlayedTracks:(id)sender
{
    if ([_setlistController shouldPromptForClear]) {
        NSString *messageText     = NSLocalizedString(@"Reset Played Tracks", nil);
        NSString *informativeText = NSLocalizedString(@"Are you sure you want to reset all played tracks to the queued state?", nil);
        NSString *defaultButton   = NSLocalizedString(@"Reset", nil);
        
        NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:defaultButton alternateButton:NSLocalizedString(@"Cancel", nil) otherButton:nil informativeTextWithFormat:@"%@", informativeText];
        
        if ([alert runModal] == NSOKButton) {
            [_setlistController resetPlayedTracks];
        }
    
    } else {
        [_setlistController resetPlayedTracks];
    }
}


- (IBAction) openFile:(id)sender
{
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
        if (result == NSOKButton) {
            SavePanelState(openPanel, @"open-file-panel");
            [weakSetlistController openFileAtURL:[openPanel URL]];
        }
    }];
}


- (IBAction) copySetlist:(id)sender
{
    [_setlistController copyToPasteboard:[NSPasteboard generalPasteboard]];
}


- (IBAction) saveSetlist:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterLongStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    
    NSString *dateString = [formatter stringFromDate:[NSDate date]];

    NSString *suggestedNameFormat = NSLocalizedString(@"Embrace (%@)", nil);
    NSString *suggestedName = [NSString stringWithFormat:suggestedNameFormat, dateString];
    [savePanel setNameFieldStringValue:suggestedName];

    [savePanel setTitle:NSLocalizedString(@"Save Set List", nil)];
    [savePanel setAllowedFileTypes:@[ @"txt" ]];
    
    if (!LoadPanelState(savePanel, @"save-set-list-panel")) {
        NSString *desktopPath = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject];
        
        if (desktopPath) {
            [savePanel setDirectoryURL:[NSURL fileURLWithPath:desktopPath]];
        }
    }
    
    __weak id weakSetlistController = _setlistController;
    
    [savePanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            SavePanelState(savePanel, @"save-set-list-panel");
            [weakSetlistController saveToFileAtURL:[savePanel URL]];
        }
    }];
}


- (IBAction) changeViewLayout:(id)sender
{
    [[Preferences sharedInstance] setNumberOfLayoutLines:[sender tag]];
}


- (IBAction) changeViewAttributes:(id)sender
{
    Preferences *preferences = [Preferences sharedInstance];
    ViewAttribute attribute = [sender tag];
    
    BOOL yn = [preferences isViewAttributeSelected:attribute];
    [preferences setViewAttribute:attribute selected:!yn];
}


- (IBAction) changeKeySignatureDisplay:(id)sender
{
    Preferences *preferences = [Preferences sharedInstance];
    [preferences setKeySignatureDisplayMode:[sender tag]];
}


- (IBAction) exportSetlist:(id)sender                  {  [_setlistController exportToPlaylist]; }
- (IBAction) performPreferredPlaybackAction:(id)sender {  [_setlistController performPreferredPlaybackAction:self]; }
- (IBAction) increaseVolume:(id)sender                 {  [_setlistController increaseVolume:self];  }
- (IBAction) decreaseVolume:(id)sender                 {  [_setlistController decreaseVolume:self];  }
- (IBAction) increaseAutoGap:(id)sender                {  [_setlistController increaseAutoGap:self]; }
- (IBAction) decreaseAutoGap:(id)sender                {  [_setlistController decreaseAutoGap:self]; }
- (IBAction) revealEndTime:(id)sender                  {  [_setlistController revealEndTime:self];     }


- (IBAction) hardSkip:(id)sender
{
    [[Player sharedInstance] hardSkip];
}


- (IBAction) hardPause:(id)sender
{
    [[Player sharedInstance] hardStop];
}


- (void) _toggleWindowForController:(NSWindowController *)controller sender:(id)sender
{
    BOOL orderIn = YES;

    if ([sender isKindOfClass:[NSMenuItem class]]) {
        if ([sender state] == NSOnState) {
            orderIn = NO;
        }
    }
    
    if (orderIn) {
        [controller showWindow:self];
    } else {
        [[controller window] orderOut:self];
    }
}


- (IBAction) showSetlistWindow:(id)sender
{
    [self _toggleWindowForController:_setlistController sender:sender];
}


- (IBAction) showEffectsWindow:(id)sender
{
    [self _toggleWindowForController:_effectsController sender:sender];
}


- (IBAction) showCurrentTrack:(id)sender
{
    [self _toggleWindowForController:_currentTrackController sender:sender];
}


- (IBAction) showDebugWindow:(id)sender
{
#if DEBUG
    if (!_debugController) {
        _debugController = [[DebugController alloc] init];
    }

    [_debugController showWindow:self];
#endif
}


- (IBAction) sendCrashReports:(id)sender
{
    NSAlert *(^makeAlertOne)() = ^{
        NSString *messageText     = NSLocalizedString(@"Send Crash Report?", nil);
        NSString *informativeText = NSLocalizedString(@"Information about the crash, your operating system, and device will be sent. No personal information is included.", nil);
        NSString *defaultButton   = NSLocalizedString(@"Send", nil);
    
        return [NSAlert alertWithMessageText:messageText defaultButton:defaultButton alternateButton:NSLocalizedString(@"Cancel", nil) otherButton:nil informativeTextWithFormat:@"%@", informativeText];
    };

    NSAlert *(^makeAlertTwo)() = ^{
        NSString *messageText     = NSLocalizedString(@"Crash Report Sent", nil);
        NSString *informativeText = NSLocalizedString(@"Thank you for your crash report.  If you have any additional information regarding the crash, please contact me.", nil);
        NSString *otherButton     = NSLocalizedString(@"Contact", nil);
            
        return [NSAlert alertWithMessageText:messageText defaultButton:nil alternateButton:nil otherButton:otherButton informativeTextWithFormat:@"%@", informativeText];
    };
    
    BOOL okToSend = [makeAlertOne() runModal] == NSOKButton;

    if (okToSend) {
        [_crashSender sendCrashReportsWithCompletionHandler:^(BOOL didSend) {
            NSModalResponse response = [makeAlertTwo() runModal];
            
            if (response == NSAlertOtherReturn) {
                [self sendFeedback:nil];
            }
        }];
    }
}


- (IBAction) openSupportFolder:(id)sender
{
    NSString *file = GetApplicationSupportDirectory();
    file = [file stringByDeletingLastPathComponent];

    [[NSWorkspace sharedWorkspace] openFile:file];
}


- (IBAction) showPreferences:(id)sender
{
    if (!_preferencesController) {
        _preferencesController = [[PreferencesController alloc] init];
    }

    [_preferencesController showWindow:self];
}


- (IBAction) sendFeedback:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://www.ricciadams.com/contact/"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction) viewWebsite:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://www.ricciadams.com/projects/embrace"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction) viewOnAppStore:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://www.ricciadams.com/buy/embrace"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (IBAction) openAcknowledgements:(id)sender
{
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
