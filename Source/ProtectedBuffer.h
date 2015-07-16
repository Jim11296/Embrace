//
//  ProtectedData.h
//  Embrace
//
//  Created by Ricci Adams on 2015-07-08.
//  Copyright (c) 2015 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ProtectedBuffer : NSObject

- (id) initWithCapacity:(NSUInteger)capacity;

- (void *) bytes NS_RETURNS_INNER_POINTER;

- (void) lock;


@end
