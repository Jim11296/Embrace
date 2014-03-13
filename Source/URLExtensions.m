//
//  URLExtensions.m
//  Embrace
//
//  Created by Ricci Adams on 2014-03-12.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "URLExtensions.h"
#import <objc/objc-runtime.h>

static NSMutableDictionary *sURLToKeyMap = nil;


@implementation NSURL (EmbraceExtension)

- (BOOL) embrace_startAccessingResourceWithKey:(NSString *)key
{
    BOOL result = YES;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sURLToKeyMap = [NSMutableDictionary dictionary];
    });

    @synchronized(sURLToKeyMap) {
        NSMutableSet *set = [sURLToKeyMap objectForKey:self];
        if (!set) {
            set = [NSMutableSet set];
            [sURLToKeyMap setObject:set forKey:self];
        }
    
        NSInteger count = [set count];
        
        if (count == 0) {
            EmbraceLog(@"URL", @"+1: %@ access set empty, calling -startAccessingSecurityScopedResource", self);
            result = [self startAccessingSecurityScopedResource];
        }

        if (result) {
            [set addObject:key];
        }
        
        EmbraceLog(@"URL", @"+1: %@ access set is now %@, added %@", self, set, key);
    }
    
    return result;
}


- (void) embrace_stopAccessingResourceWithKey:(NSString *)key
{
    @synchronized(sURLToKeyMap) {
        NSMutableSet *set = [sURLToKeyMap objectForKey:self];

        if ([set containsObject:key]) {
            [set removeObject:key];
            
            if ([set count] == 0) {
                EmbraceLog(@"URL", @"-1: %@ access set empty, calling -stopAccessingSecurityScopedResource", self);
                [self stopAccessingSecurityScopedResource];
            }

            EmbraceLog(@"URL", @"-1: %@ access set is now %@, removed %@", self, set, key);
        }
    }
}


@end
