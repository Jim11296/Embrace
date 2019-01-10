// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>

@interface NSURL (EmbraceExtension)

- (BOOL) embrace_startAccessingResourceWithKey:(NSString *)key;
- (void) embrace_stopAccessingResourceWithKey:(NSString *)key;

@end
