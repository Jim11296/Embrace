//
//  NoDropImageView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-03-08.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "NoDropImageView.h"

@implementation NoDropImageView

- (id) initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self unregisterDraggedTypes];
    }
    
    return self;
}

@end
