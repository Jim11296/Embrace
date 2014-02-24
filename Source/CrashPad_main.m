//
//  EscapePod.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-22.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface CrashPadAppDelegate : NSObject <NSApplicationDelegate>

@end


@implementation CrashPadAppDelegate {
    NSArray *_embracesAtLaunch;
    NSTimer *_timer;
}


- (void) _tick:(NSTimer *)timer
{
    for (NSRunningApplication *app in _embracesAtLaunch) {
        if (![app isTerminated]) {
            return;
        }
    }

    exit(0);
}


- (BOOL) _runAlert
{
    NSString *messageText     = NSLocalizedString(@"Embrace encountered a critical error.", nil);
    NSString *informativeText = NSLocalizedString(@"Your current song will continue to play, but you must restart the app to play other songs or access other features.", nil);
    NSString *defaultButton   = NSLocalizedString(@"Restart", nil);
    NSString *alternateButton = NSLocalizedString(@"Quit", nil);

    [NSApp activateIgnoringOtherApps:YES];

    NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:defaultButton alternateButton:alternateButton otherButton:nil informativeTextWithFormat:@"%@", informativeText];
    [alert setAlertStyle:NSCriticalAlertStyle];

    return [alert runModal] == NSOKButton;
}



- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
    _embracesAtLaunch = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.iccir.Embrace"];

    _timer = [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(_tick:) userInfo:nil repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL restart = [self _runAlert];
        NSURL *bundleURL = nil;
        
        for (NSRunningApplication *app in _embracesAtLaunch) {
            bundleURL = [app bundleURL];
            kill([app processIdentifier], 9);
        }

        if (restart && bundleURL) {
            NSError *error = nil;
            [[NSWorkspace sharedWorkspace] launchApplicationAtURL:bundleURL options:NSWorkspaceLaunchNewInstance configuration:nil error:&error];
        }

        [NSApp terminate:self];
    });
}

@end


int main(int argc, const char * argv[])
{
@autoreleasepool {
    NSApplication *application = [NSApplication sharedApplication];
    CrashPadAppDelegate *appDelegate = [[CrashPadAppDelegate alloc] init];
    
    [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [application setDelegate:appDelegate];
    [application run];
    
}
    return 0;
}

