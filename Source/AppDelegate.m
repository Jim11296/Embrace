//
//  AppDelegate.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "AppDelegate.h"

#import "PlaylistController.h"
#import "EffectsController.h"
#import "PreferencesController.h"
#import "EditEffectController.h"
#import "CurrentTrackController.h"
#import "ViewTrackController.h"
#import "Preferences.h"

#import "Player.h"
#import "Effect.h"
#import "Track.h"

#import "iTunesManager.h"

@implementation AppDelegate {
    PlaylistController     *_playlistController;
    EffectsController      *_effectsController;
    CurrentTrackController *_currentTrackController;
    PreferencesController  *_preferencesController;

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
    
    _playlistController     = [[PlaylistController     alloc] init];
    _effectsController      = [[EffectsController      alloc] init];
    _currentTrackController = [[CurrentTrackController alloc] init];
    
    [self _showPreviouslyVisibleWindows];

    InstallCppTerminationHandler();

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

    // Always show main window
    [self showMainWindow:self];
    
#ifdef DEBUG
    [[self debugMenuItem] setHidden:NO];
#endif
}


- (void) _saveVisibleWindows
{
    NSMutableArray *visibleWindows = [NSMutableArray array];
    
    if ([[_playlistController window] isVisible]) {
        [visibleWindows addObject:@"playlist"];
    }

    if ([[_currentTrackController window] isVisible]) {
        [visibleWindows addObject:@"current-track"];
    }

    [[NSUserDefaults standardUserDefaults] setObject:visibleWindows forKey:@"visible-windows"];
}


- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows
{
    if (!hasVisibleWindows) {
        [self showMainWindow:self];
    }

    return YES;
}


- (BOOL) application:(NSApplication *)sender openFile:(NSString *)filename
{
    NSURL *fileURL = [NSURL fileURLWithPath:filename];

    if (IsAudioFileAtURL(fileURL)) {
        [_playlistController openFileAtURL:fileURL];
        return YES;
    }

    return NO;
}


- (void) application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    for (NSString *filename in [filenames reverseObjectEnumerator]) {
        NSURL *fileURL = [NSURL fileURLWithPath:filename];

        if (IsAudioFileAtURL(fileURL)) {
            [_playlistController openFileAtURL:fileURL];
        }
    }
}


- (void) applicationWillTerminate:(NSNotification *)notification
{
    [self _saveVisibleWindows];

    [[Player sharedInstance] saveEffectState];
    [[Player sharedInstance] hardStop];
}


- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
    if ([[Player sharedInstance] isPlaying]) {
        NSString *messageText     = NSLocalizedString(@"Are you sure you want to quit Embrace?", nil);
        NSString *informativeText = NSLocalizedString(@"If you quit, the currently playing music will stop.", nil);
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
        PlaybackAction action = [_playlistController preferredPlaybackAction];
        
        NSString *title = NSLocalizedString(@"Play", nil);
        BOOL enabled = [_playlistController isPreferredPlaybackActionEnabled];
        NSInteger state = NSOffState;
        
        if (action == PlaybackActionShowIssue) {
            title = NSLocalizedString(@"Show Issue", nil);

        } else if (action == PlaybackActionSkip) {
            title = NSLocalizedString(@"Skip", nil);

        } else if (action == PlaybackActionTogglePause) {
            title = NSLocalizedString(@"Pause after playing", nil);
            
            BOOL yn = [[[Player sharedInstance] currentTrack] pausesAfterPlaying];
            state = yn ? NSOnState : NSOffState;
            
        } else if (action == PlaybackActionPause) {
            title = NSLocalizedString(@"Pause", nil);
        }

        [menuItem setState:state];
        [menuItem setTitle:title];
        [menuItem setEnabled:enabled];
        [menuItem setKeyEquivalent:@" "];

    } else if (action == @selector(hardPause:)) {
        [menuItem setKeyEquivalent:@" "];
        return [[Player sharedInstance] isPlaying];

    } else if (action == @selector(hardSkip:)) {
        return [[Player sharedInstance] isPlaying];

    } else if (action == @selector(showMainWindow:)) {
        BOOL yn = [_playlistController isWindowLoaded] && [[_playlistController window] isMainWindow];
        [menuItem setState:(yn ? NSOnState : NSOffState)];
    
    } else if (action == @selector(showEffectsWindow:)) {
        BOOL yn = [_effectsController isWindowLoaded] && [[_effectsController window] isMainWindow];
        [menuItem setState:(yn ? NSOnState : NSOffState)];
    
    } else if (action == @selector(showCurrentTrack:)) {
        BOOL yn = [_currentTrackController isWindowLoaded] && [[_currentTrackController window] isMainWindow];
        [menuItem setState:(yn ? NSOnState : NSOffState)];
    }

    return YES;
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


- (IBAction) clearHistory:(id)sender
{
    [_playlistController clearHistory];
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
    
    [openPanel setTitle:NSLocalizedString(@"Add to Playlist", nil)];
    [openPanel setAllowedFileTypes:GetAvailableAudioFileUTIs()];

    __weak id weakPlaylistController = _playlistController;


    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            SavePanelState(openPanel, @"open-file-panel");
            [weakPlaylistController openFileAtURL:[openPanel URL]];
        }
    }];
}


- (IBAction) copyHistory:(id)sender
{
    [_playlistController copyHistoryToPasteboard:[NSPasteboard generalPasteboard]];
}


- (IBAction) saveHistory:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterLongStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    
    NSString *dateString = [formatter stringFromDate:[NSDate date]];

    NSString *suggestedNameFormat = NSLocalizedString(@"Embrace (%@)", nil);
    NSString *suggestedName = [NSString stringWithFormat:suggestedNameFormat, dateString];
    [savePanel setNameFieldStringValue:suggestedName];

    [savePanel setTitle:NSLocalizedString(@"Save History", nil)];
    [savePanel setAllowedFileTypes:@[ @"txt" ]];
    
    if (!LoadPanelState(savePanel, @"save-history-panel")) {
        NSString *desktopPath = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject];
        
        if (desktopPath) {
            [savePanel setDirectoryURL:[NSURL fileURLWithPath:desktopPath]];
        }
    }
    
    __weak id weakPlaylistController = _playlistController;
    
    [savePanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            SavePanelState(savePanel, @"save-history-panel");
            [weakPlaylistController saveHistoryToFileAtURL:[savePanel URL]];
        }
    }];
}


- (IBAction) exportHistory:(id)sender                  {  [_playlistController exportHistory]; }
- (IBAction) performPreferredPlaybackAction:(id)sender {  [_playlistController performPreferredPlaybackAction:self]; }
- (IBAction) increaseVolume:(id)sender                 {  [_playlistController increaseVolume:self];  }
- (IBAction) decreaseVolume:(id)sender                 {  [_playlistController decreaseVolume:self];  }
- (IBAction) increaseAutoGap:(id)sender                {  [_playlistController increaseAutoGap:self]; }
- (IBAction) decreaseAutoGap:(id)sender                {  [_playlistController decreaseAutoGap:self]; }


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


- (IBAction) showMainWindow:(id)sender
{
    [self _toggleWindowForController:_playlistController sender:sender];
}


- (IBAction) showEffectsWindow:(id)sender
{
    [self _toggleWindowForController:_effectsController sender:sender];
}


- (IBAction) showCurrentTrack:(id)sender
{
    [self _toggleWindowForController:_currentTrackController sender:sender];
}


- (IBAction) showPreferences:(id)sender
{
    if (!_preferencesController) {
        _preferencesController = [[PreferencesController alloc] init];
    }

    [_preferencesController showWindow:self];
}


- (IBAction) debugPopulatePlaylist:(id)sender
{
    NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"debug-population-set"];
    [_playlistController debugPopulatePlaylistWithSet:index];
}


- (IBAction) debugChangePopulation:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setInteger:[sender tag] forKey:@"debug-population-set"];
    [self debugPopulatePlaylist:sender];
}


- (IBAction) debugPlayPauseLoop:(id)sender
{
    static NSTimer *playPauseTimer = nil;
    if (!playPauseTimer) {
        [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(debugPlayPauseTick:) userInfo:nil repeats:YES];
    }
}


- (void) debugPlayPauseTick:(NSTimer *)timer
{
    Player *player = [Player sharedInstance];

    if ([player isPlaying]) {
        Track *track = [player currentTrack];
        [player hardStop];
        [track setTrackStatus:TrackStatusQueued];

    } else {
        [player play];
    }
}


- (IBAction) debugShowInternalEffects:(id)sender
{
    NSArray *internalEffects = [[Player sharedInstance] debugInternalEffects];

    for (Effect *effect in internalEffects) {
        [[self editControllerForEffect:effect] showWindow:self];
    }
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


@end
