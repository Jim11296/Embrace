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

@property (nonatomic, readonly) NSInteger rowWithMouseInside;
@end


@protocol TrackTableViewDelegate <NSTableViewDelegate>
- (void) trackTableView:(TrackTableView *)tableView draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint;
- (void) trackTableView:(TrackTableView *)tableView didModifyRowWithMouseInside:(NSInteger)row oldRow:(NSInteger)oldRow;
@end