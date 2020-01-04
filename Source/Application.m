// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "Application.h"
#import "AppDelegate.h"
#import "SetlistController.h"
#import "Preferences.h"


@implementation Application {
    NSHashTable   *_eventListeners;
    NSTimeInterval _lastSpaceBarPress;
    
    id _localMonitor;
    id _globalMonitor;
}

- (id) init
{
    if ((self = [super init])) {
        __weak id weakSelf = self;
    
        _localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFromType(NSEventTypeFlagsChanged) handler:^(NSEvent *event) {
            [weakSelf _handleFlagsChanged:event];
            return event;
        }];

        _globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskFromType(NSEventTypeFlagsChanged) handler:^(NSEvent *event) {
            [weakSelf _handleFlagsChanged:event];
        }];
    
    }
    
    return self;
}


- (void) _handleFlagsChanged:(NSEvent *)event
{
    for (id<ApplicationEventListener> listener in _eventListeners) {
        [listener application:self flagsChanged:event];
    }
}


- (void) sendEvent:(NSEvent *)event
{
    NSEventType eventType = [event type];

    if (eventType == NSEventTypeKeyDown) {
        NSUInteger commonModifiers =
            NSEventModifierFlagShift   |
            NSEventModifierFlagControl |
            NSEventModifierFlagOption  |
            NSEventModifierFlagCommand;

        if ((([event modifierFlags] & commonModifiers) == 0) && ([event keyCode] == 49)) {
            if (![[Preferences sharedInstance] allowsPlaybackShortcuts]) {
                return;
            }
            
            if ([event isARepeat]) {
                EmbraceLog(@"Application", @"Not sending space bar due to isARepeat=YES");
                return;
            }
            
            NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
            NSTimeInterval delta = now - _lastSpaceBarPress;
    
            if (delta < 0.3) {
                EmbraceLog(@"Application", @"Not sending space bar due to previous space bar press: %g", delta);
                _lastSpaceBarPress = now;
                return;
                
            } else {
                _lastSpaceBarPress = now;
            }

            EmbraceLog(@"Application", @"Sending performPreferredPlaybackAction: due to space bar");
            
            [GetAppDelegate() performPreferredPlaybackAction];
            return;
        }

        [[GetAppDelegate() setlistController] handleNonSpaceKeyDown];
    }

    if (eventType == NSEventTypeRightMouseDown) {
        if (![NSApp isActive] && [[Preferences sharedInstance] floatsOnTop]) {
            [NSApp activateIgnoringOtherApps:YES];
            [self performSelector:@selector(sendEvent:) withObject:event afterDelay:0];
            return;
        }
    }

    [super sendEvent:event];
}


- (void) registerEventListener:(id<ApplicationEventListener>)listener
{
    if (!_eventListeners) _eventListeners = [NSHashTable weakObjectsHashTable];
    [_eventListeners addObject:listener];
}


- (void) unregisterEventListener:(id<ApplicationEventListener>)listener
{
    [_eventListeners removeObject:listener];
}


@end
