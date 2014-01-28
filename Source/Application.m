//
//  Application.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-22.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Application.h"
#import "AppDelegate.h"

@implementation Application

- (void) sendEvent:(NSEvent *)event
{
    NSEventType eventType = [event type];

    if (eventType == NSKeyDown) {
        NSString* keysPressed = [event characters];
        
        NSUInteger commonModifiers = NSShiftKeyMask |
            NSControlKeyMask |
            NSAlternateKeyMask |
            NSCommandKeyMask;

        if (([event modifierFlags] & commonModifiers) == 0 && [keysPressed isEqualToString:@" "]) {
            [(AppDelegate *)[self delegate] playOrSoftPause:self];
            return;
        }
    }
    
    [super sendEvent:event];
}

@end
