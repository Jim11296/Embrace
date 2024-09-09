// (c) 2015-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>

@interface HugProtectedBuffer : NSObject

- (id) initWithCapacity:(NSUInteger)capacity;

- (void *) bytes NS_RETURNS_INNER_POINTER;

- (void) lock;


@end
