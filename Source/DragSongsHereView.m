//
//  DragPreventingImageView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-08.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "DragSongsHereView.h"

@implementation DragSongsHereView

- (BOOL) wantsUpdateLayer
{
    return YES;
}

- (void) updateLayer
{
    [[self layer] setContents:[NSImage imageNamed:@"drag_songs"]];
}

@end
