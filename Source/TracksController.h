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

- (void) copy:(id)sender;
- (void) paste:(id)sender;

- (Track *) firstQueuedTrack;
- (NSArray *) selectedTracks;

- (BOOL) addTracksWithURLs:(NSArray<NSURL *> *)urls;

- (void) removeAllTracks;
- (void) deselectAllTracks;
- (void) resetPlayedTracks;

- (void) revealTime:(id)sender;

- (void) toggleStopsAfterPlaying:(id)sender;
- (void) toggleIgnoreAutoGap:(id)sender;
- (void) toggleMarkAsPlayed:(id)sender;

- (void) detectDuplicates;

- (BOOL) acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;

- (void) didFinishTrack:(Track *)finishedTrack;

- (Track *) trackAtIndex:(NSUInteger)index;
@property (nonatomic, readonly) NSArray *tracks;

@property (nonatomic, readonly) NSTimeInterval modificationTime;

- (IBAction) delete:(id)sender;


@end
