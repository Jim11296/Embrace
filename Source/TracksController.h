//
//  TracksController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-03-01.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const TracksControllerDidModifyTracksNotificationName;

@class Track, TrackTableView;

@interface TracksController : NSObject <NSTableViewDelegate, NSTableViewDataSource>

- (void) saveState;

- (Track *) firstQueuedTrack;
- (NSArray *) selectedTracks;

- (void) addTrackAtURL:(NSURL *)fileURL;
- (void) removeAllTracks;
- (void) deselectAllTracks;
- (void) resetPlayedTracks;

- (void) revealEndTime:(id)sender;
- (BOOL) canRevealEndTime;

- (void) toggleStopsAfterPlaying:(id)sender;
- (void) toggleIgnoreAutoGap:(id)sender;
- (void) toggleMarkAsPlayed:(id)sender;

- (BOOL) acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;

- (void) didFinishTrack:(Track *)finishedTrack;

- (Track *) trackAtIndex:(NSUInteger)index;
@property (nonatomic, readonly) NSArray *tracks;

@property (nonatomic, readonly) NSTimeInterval modificationTime;

- (IBAction) delete:(id)sender;


@end
