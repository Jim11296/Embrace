//
//  AudioFileTableCellView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "AudioFileTableCellView.h"
#import "Track.h"
#import "BorderedView.h"

@implementation AudioFileTableCellView

- (NSArray *) keyPathsToObserve
{
    NSArray *result = [super keyPathsToObserve];
    
    return [result arrayByAddingObjectsFromArray:@[  @"artist" ]];
}


- (void) update
{
    [super update];
    
    Track *track = [self track];
    if (!track) return;

    NSString *artist = [track artist];
    if (!artist) artist = @"";
    [[self artistField] setStringValue:artist];
}


@end
