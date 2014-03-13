//
//  URLExtensions.h
//  Embrace
//
//  Created by Ricci Adams on 2014-03-12.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSURL (EmbraceExtension)

- (BOOL) embrace_startAccessingResourceWithKey:(NSString *)key;
- (void) embrace_stopAccessingResourceWithKey:(NSString *)key;

@end
