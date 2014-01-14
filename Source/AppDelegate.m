//
//  AppDelegate.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "AppDelegate.h"

#import "PlaylistController.h"
#import "EffectsController.h"
#import "PreferencesController.h"
#import "EditEffectController.h"
#import "EditTrackController.h"

#import "Effect.h"
#import "Track.h"

#import "iTunesManager.h"

@implementation AppDelegate {
    PlaylistController    *_playlistController;
    EffectsController     *_effectsController;
    PreferencesController *_preferencesController;

    NSMutableArray        *_editEffectControllers;
    NSMutableArray        *_editTrackControllers;
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Start parsing iTunes XML
    [iTunesManager sharedInstance];
    
    _playlistController = [[PlaylistController alloc] init];
    _effectsController  = [[EffectsController  alloc] init];
    [_playlistController showWindow:self];
    
    // Not the cleanest, but needed to break a retain cycle due to the way AudioUnit UI works
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleEffectDidDealloc:) name:EffectDidDeallocNotification object:nil];
}


- (void) _handleEffectDidDealloc:(NSNotification *)note
{
    NSMutableArray *toRemove = [NSMutableArray array];

    for (EditEffectController *controller in _editEffectControllers) {
        if (![controller effect]) {
            [controller close];
            [toRemove addObject:controller];
        }
    }
    
    [_editEffectControllers removeObjectsInArray:toRemove];
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


- (EditTrackController *) editControllerForTrack:(Track *)track
{
    if (!_editTrackControllers) {
        _editTrackControllers = [NSMutableArray array];
    }

    for (EditTrackController *controller in _editEffectControllers) {
        if ([[controller track] isEqual:track]) {
            return controller;
        }
    }
    
    EditTrackController *controller = [[EditTrackController alloc] initWithTrack:track];
    [_editEffectControllers addObject:controller];
    return controller;
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


@end
