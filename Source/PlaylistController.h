//
//  MainWindowController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WaveformView;
@class TracksManager;
@class Player, PlayBar, BorderedView, CloseButton, Button, LevelMeter;

@interface PlaylistController : NSWindowController

- (IBAction) playOrSoftPause:(id)sender;

- (IBAction) showEffects:(id)sender;
- (IBAction) showCurrentTrack:(id)sender;

- (IBAction) changeVolume:(id)sender;
- (IBAction) delete:(id)sender;
- (IBAction) togglePauseAfterPlaying:(id)sender;
- (IBAction) toggleMarkAsPlayed:(id)sender;
- (IBAction) addSilence:(id)sender;
- (IBAction) showGearMenu:(id)sender;

- (void) clearHistory;
- (void) openFileAtURL:(NSURL *)url;
- (void) copyHistoryToPasteboard:(NSPasteboard *)pasteboard;
- (void) saveHistoryToFileAtURL:(NSURL *)url;
- (void) exportHistory;

- (void) debugPopulatePlaylistWithSet:(NSInteger)set;

@property (nonatomic) NSTimeInterval minimumSilenceBetweenTracks;

@property (nonatomic, strong) NSArray *tracks;
@property (nonatomic, weak) Player *player;

@property (nonatomic, strong) IBOutlet NSView *dragSongsView;

@property (nonatomic, strong) IBOutlet NSMenu *gearMenu;

@property (nonatomic, strong) IBOutlet NSArrayController *tracksController;
@property (nonatomic, strong) IBOutlet NSMenu *tableMenu;

@property (nonatomic, strong) IBOutlet BorderedView *headerView;
@property (nonatomic, weak)   IBOutlet NSTextField  *playOffsetField;
@property (nonatomic, weak)   IBOutlet PlayBar      *playBar;
@property (nonatomic, weak)   IBOutlet NSTextField  *playRemainingField;
@property (nonatomic, weak)   IBOutlet Button       *playButton;
@property (nonatomic, weak)   IBOutlet Button       *gearButton;
@property (nonatomic, weak)   IBOutlet LevelMeter   *levelMeter;

@property (nonatomic, weak)   IBOutlet NSView *mainView;
@property (nonatomic, weak)   IBOutlet NSTableView  *tableView;
@property (nonatomic, weak)   IBOutlet BorderedView *bottomContainer;


@end
