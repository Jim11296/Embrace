//
//  SetlistController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Player.h"


@class WaveformView;
@class TracksController;
@class PlayBar, BorderedView, CloseButton, Button, LevelMeter, WhiteSlider;


typedef NS_ENUM(NSInteger, PlaybackAction) {
    PlaybackActionPlay = 0,
    PlaybackActionStop,
    PlaybackActionShowIssue
};


@interface SetlistController : NSWindowController

- (IBAction) performPreferredPlaybackAction:(id)sender;
- (PlaybackAction) preferredPlaybackAction;
- (BOOL) isPreferredPlaybackActionEnabled;

- (void) handleNonSpaceKeyDown;

- (IBAction) increaseVolume:(id)sender;
- (IBAction) decreaseVolume:(id)sender;
- (IBAction) increaseAutoGap:(id)sender;
- (IBAction) decreaseAutoGap:(id)sender;

- (IBAction) showEffects:(id)sender;
- (IBAction) showCurrentTrack:(id)sender;

- (IBAction) changeVolume:(id)sender;
- (IBAction) delete:(id)sender;
- (IBAction) toggleStopsAfterPlaying:(id)sender;
- (IBAction) toggleMarkAsPlayed:(id)sender;
- (IBAction) showGearMenu:(id)sender;

- (void) clear;
- (void) resetPlayedTracks;
- (BOOL) shouldPromptForClear;

- (BOOL) addTracksWithURLs:(NSArray<NSURL *> *)urls;

- (void) copyToPasteboard:(NSPasteboard *)pasteboard;
- (void) exportToFile;
- (void) exportToPlaylist;

- (IBAction) changeLabel:(id)sender;

- (IBAction) revealEndTime:(id)sender;
- (BOOL) canRevealEndTime;

- (void) showAlertForIssue:(PlayerIssue)issue;

@property (nonatomic) NSInteger minimumSilenceBetweenTracks;
@property (readonly) NSString *autoGapTimeString;

@property (nonatomic, weak) Player *player;
@property (nonatomic, strong, readonly) TracksController *tracksController;

@end
