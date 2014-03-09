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
- (Track *) selectedTrack;

- (void) addTrackAtURL:(NSURL *)fileURL;
- (void) removeAllTracks;
- (void) deselectAllTracks;
- (void) resetPlayedTracks;

- (BOOL) canDeleteSelectedObjects;
- (BOOL) canChangeTrackStatusOfTrack:(Track *)track;

- (void) revealEndTimeForTrack:(Track *)track;

- (BOOL) acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;

- (Track *) trackAtIndex:(NSUInteger)index;
@property (nonatomic, readonly) NSArray *tracks;

@property (nonatomic, readonly) NSTimeInterval modificationTime;


@property (nonatomic, weak) IBOutlet TrackTableView *tableView;
- (IBAction) delete:(id)sender;


@end
