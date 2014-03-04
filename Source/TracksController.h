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

- (BOOL) canDeleteSelectedObjects;
- (BOOL) canChangeTrackStatusOfTrack:(Track *)track;

- (void) revealEndTimeForTrack:(Track *)track;

- (Track *) trackAtIndex:(NSUInteger)index;
@property (nonatomic, readonly) NSArray *tracks;

@property (nonatomic, readonly) NSTimeInterval modificationTime;


@property (nonatomic, weak) IBOutlet TrackTableView *tableView;
- (IBAction) delete:(id)sender;


@end
