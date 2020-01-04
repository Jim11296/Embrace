// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol ApplicationEventListener;

@interface Application : NSApplication

- (void) registerEventListener:(id<ApplicationEventListener>)listener;
- (void) unregisterEventListener:(id<ApplicationEventListener>)listener;

@end


@protocol ApplicationEventListener <NSObject>
- (void) application:(Application *)application flagsChanged:(NSEvent *)event;
@end

