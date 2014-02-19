//
//  TrackTableView.h
//  Embrace
//
//  Created by Ricci Adams on 2014-02-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TrackTableView : NSTableView
- (void) updateInsertionPointWorkaround:(BOOL)yn;
@end


@protocol TrackTableViewDelegate <NSTableViewDelegate>
- (void) trackTableView:(TrackTableView *)tableView draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint;
@end