// (c) 2015-2020 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@interface HugProtectedBuffer : NSObject

- (id) initWithCapacity:(NSUInteger)capacity;

- (void *) bytes NS_RETURNS_INNER_POINTER;

- (void) lock;


@end
