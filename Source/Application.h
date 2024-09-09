// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Cocoa/Cocoa.h>

@protocol ApplicationEventListener;

@interface Application : NSApplication

- (void) registerEventListener:(id<ApplicationEventListener>)listener;
- (void) unregisterEventListener:(id<ApplicationEventListener>)listener;

@end


@protocol ApplicationEventListener <NSObject>
- (void) application:(Application *)application flagsChanged:(NSEvent *)event;
@end

