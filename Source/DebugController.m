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
#import "SetlistController.h"
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


- (SetlistController *) _setlistController
{
    return [GetAppDelegate() valueForKey:@"setlistController"];
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

    [[self _setlistController] clear];
    
    for (NSURL *url in fileURLs) {
        [[self _setlistController] openFileAtURL:url];
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
    [[self _setlistController] showAlertForIssue:tag];
}


- (IBAction) doFlipAnimation:(id)sender
{
    Button *button = [[self _setlistController] playButton];

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


- (IBAction) explode:(id)sender
{
    NSInteger tag = [sender selectedTag];
    NSLog(@"%ld", tag);
    
    NSInteger action = tag % 3;
    NSInteger thread = tag / 3;
    
    dispatch_queue_t q = thread == 0 ? dispatch_get_main_queue() : dispatch_get_global_queue(0, 0);
    
    
    dispatch_async(q, ^{
        if (action == 0) {
            RaiseException();
            
        } else if (action == 1) {
            [[NSException exceptionWithName:@"Debug Exception" reason:@"Debug Exception" userInfo:nil] raise];

        } else if (action == 2) {
            for (NSInteger i = 0; i < 4096; i++) {
                int *moo = (int *)i;
                *moo = 0xdeadbeef;
            }
        }
    });
    
    if (thread == 0) {
    
     
      
    }// C++ Exception
    
    
    NSLog(@"%ld, %ld", thread, action);

}


@end

#endif
