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
    NSMutableArray         *_editTrackControllers;
}


- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Start parsing iTunes XML
    [iTunesManager sharedInstance];
    
    _playlistController = [[PlaylistController alloc] init];
    _effectsController  = [[EffectsController  alloc] init];
    [_playlistController showWindow:self];
    
#ifdef DEBUG
    [[self debugMenuItem] setHidden:NO];
#endif
}


- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];

    if (action == @selector(playOrSoftPause:)) {
        if ([[Player sharedInstance] isPlaying]) {
            [menuItem setTitle:NSLocalizedString(@"Pause", nil)];
        } else {
            [menuItem setTitle:NSLocalizedString(@"Play", nil)];
        }

    } else if (action == @selector(hardPause:)) {
        return [[Player sharedInstance] isPlaying];

    } else if (action == @selector(hardSkip:)) {
        return [[Player sharedInstance] isPlaying];
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
    
    EditEffectController *controller = [[EditEffectController alloc] initWithEffect:effect];
    [_editEffectControllers addObject:controller];
    return controller;
}


- (void) closeEditControllerForEffect:(Effect *)effect
{
    NSMutableArray *toRemove = [NSMutableArray array];

    for (EditEffectController *controller in _editEffectControllers) {
        if ([controller effect] == effect) {
            [controller close];
            [toRemove addObject:controller];
        }
    }
    
    [_editEffectControllers removeObjectsInArray:toRemove];
}


- (IBAction) clearHistory:(id)sender
{
    [_playlistController clearHistory];
}


- (IBAction) openFile:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    __weak id weakPlaylistController = _playlistController;

    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
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
    
    __weak id weakPlaylistController = _playlistController;
    
    [savePanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            [weakPlaylistController saveHistoryToFileAtURL:[savePanel URL]];
        }
    }];
}


- (IBAction) exportHistory:(id)sender
{
    [_playlistController exportHistory];
}


- (IBAction) playOrSoftPause:(id)sender
{
    [_playlistController playOrSoftPause:self];
}


- (IBAction) hardSkip:(id)sender
{
    [[Player sharedInstance] hardSkip];
}


- (IBAction) hardPause:(id)sender
{
    [[Player sharedInstance] hardPause];
}


- (IBAction) showMainWindow:(id)sender
{
    [_playlistController showWindow:self];
}


- (IBAction) showEffectsWindow:(id)sender
{
    [_effectsController showWindow:self];
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
    [_playlistController debugPopulatePlaylist];
}


- (IBAction) showCurrentTrack:(id)sender
{
    if (!_currentTrackController) {
        _currentTrackController = [[CurrentTrackController alloc] init];
    }

    [_currentTrackController showWindow:self];
}


- (IBAction) sendFeedback:(id)sender
{
    //!i: Open contact page
}


- (IBAction) viewOnAppStore:(id)sender
{
    //!i: Open App Store URL
}


@end
