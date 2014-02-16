//
//  DebugController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-15.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#if DEBUG

#import "DebugController.h"
#import "Player.h"
#import "PlaylistController.h"
#import "AppDelegate.h"
#import "Track.h"
#import "Button.h"


@interface DebugController ()

@end


@implementation DebugController

- (NSString *) windowNibName
{
    return @"DebugWindow";
}


- (PlaylistController *) _playlistController
{
    return [GetAppDelegate() valueForKey:@"playlistController"];
}


- (IBAction) populatePlaylist:(id)sender
{
    NSInteger tag = [sender selectedTag];

    NSMutableArray *fileURLs = [NSMutableArray array];

    void (^add)(NSString *) = ^(NSString *name) {
        NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"m4a"];
        NSURL *result = [NSURL fileURLWithPath:path];
        if (result) [fileURLs addObject:result];
    };
    
    if (tag == 1) {
        add(@"rate_44");
        add(@"rate_44");
        add(@"rate_48");
        add(@"rate_88");
        add(@"rate_96");
        add(@"rate_88");
        add(@"rate_48");
        add(@"rate_44");

    } else {
        add(@"test_c");
        add(@"test_d");
        add(@"test_e");
        add(@"test_f");
        add(@"test_g");
    }

    [[self _playlistController] clearHistory];
    
    for (NSURL *url in fileURLs) {
        [[self _playlistController] openFileAtURL:url];
    }
}


- (IBAction) playPauseLoop:(id)sender
{
    static NSTimer *playPauseTimer = nil;
    if (!playPauseTimer) {
        [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(debugPlayPauseTick:) userInfo:nil repeats:YES];
    }
}


- (IBAction) showIssueDialog:(id)sender
{
    NSInteger tag = [sender selectedTag];
    [[self _playlistController] showAlertForIssue:tag];
}


- (IBAction) doFlipAnimation:(id)sender
{
    Button *button = [[self _playlistController] playButton];

    [button setImage:[NSImage imageNamed:@"pause_template"]];
    [button setEnabled:YES];
    

//    [button flipToImage:[NSImage imageNamed:@"play_template"] enabled:YES];
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


@end

#endif
