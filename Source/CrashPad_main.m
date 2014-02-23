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


@implementation CrashPadAppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
    NSString *messageText     = NSLocalizedString(@"Embrace encountered a critical error.", nil);
    NSString *informativeText = NSLocalizedString(@"Your current song will continue to play, but you must restart the app to play other songs or access other features.", nil);
    NSString *defaultButton   = NSLocalizedString(@"Restart", nil);
    NSString *alternateButton = NSLocalizedString(@"Quit", nil);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp activateIgnoringOtherApps:YES];

        NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:defaultButton alternateButton:alternateButton otherButton:nil informativeTextWithFormat:@"%@", informativeText];
        [alert setAlertStyle:NSCriticalAlertStyle];

        BOOL restart = ([alert runModal] == NSOKButton);

        NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.iccir.Embrace"];
        NSURL *bundleURL = nil;
        for (NSRunningApplication *app in apps) {
            bundleURL = [app bundleURL];
            kill([app processIdentifier], 9);
        }

        if (restart) {
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

