//
//  TrackTableView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackTableView.h"

@implementation TrackTableView


- (void) draggingSession:(NSDraggingSession *)session movedToPoint:(NSPoint)screenPoint
{
    id delegate = [self delegate];
    
    if ([delegate respondsToSelector:@selector(trackTableView:draggingSession:movedToPoint:)]) {
        [delegate trackTableView:self draggingSession:session movedToPoint:screenPoint];
    }
}


@end
