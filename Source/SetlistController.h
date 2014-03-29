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
    PlaybackActionPause,
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
- (IBAction) togglePauseAfterPlaying:(id)sender;
- (IBAction) toggleMarkAsPlayed:(id)sender;
- (IBAction) showGearMenu:(id)sender;

- (void) clear;
- (void) resetPlayedTracks;
- (BOOL) shouldPromptForClear;

- (void) openFileAtURL:(NSURL *)url;

- (void) copyToPasteboard:(NSPasteboard *)pasteboard;
- (void) saveToFileAtURL:(NSURL *)url;
- (void) exportToPlaylist;

- (IBAction) revealEndTime:(id)sender;
- (BOOL) canRevealEndTime;

- (void) showAlertForIssue:(PlayerIssue)issue;

@property (nonatomic) NSTimeInterval minimumSilenceBetweenTracks;

@property (nonatomic, strong) IBOutlet TracksController *tracksController;

@property (nonatomic, weak) Player *player;

@property (nonatomic, strong) IBOutlet NSView *dragSongsView;

@property (nonatomic, strong) IBOutlet NSMenu *gearMenu;

@property (nonatomic, strong) IBOutlet NSMenu *tableMenu;

@property (nonatomic, strong) IBOutlet BorderedView *headerView;
@property (nonatomic, weak)   IBOutlet NSTextField  *playOffsetField;
@property (nonatomic, weak)   IBOutlet PlayBar      *playBar;
@property (nonatomic, weak)   IBOutlet NSTextField  *playRemainingField;
@property (nonatomic, weak)   IBOutlet Button       *playButton;
@property (nonatomic, weak)   IBOutlet Button       *gearButton;
@property (nonatomic, weak)   IBOutlet LevelMeter   *levelMeter;
@property (nonatomic, weak)   IBOutlet WhiteSlider  *volumeSlider;

@property (nonatomic, weak)   IBOutlet NSView *mainView;
@property (nonatomic, weak)   IBOutlet NSScrollView *scrollView;
@property (nonatomic, weak)   IBOutlet BorderedView *bottomContainer;
@property (nonatomic, weak)   IBOutlet WhiteSlider  *autoGapSlider;


@end
