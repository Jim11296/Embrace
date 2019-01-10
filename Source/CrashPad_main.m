// (c) 2014-2019 Ricci Adams.  All rights reserved.

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
    [NSApp activateIgnoringOtherApps:YES];

    NSAlert *alert = [[NSAlert alloc] init];

    [alert setMessageText:    NSLocalizedString(@"Embrace encountered a critical error.", nil)];
    [alert setInformativeText:NSLocalizedString(@"Your current song will continue to play, but you must reopen the app to play other songs or access other features.", nil)];
    
    NSButton *reopenButton = [alert addButtonWithTitle:NSLocalizedString(@"Reopen",  nil)];
    NSButton *quitButton   = [alert addButtonWithTitle:NSLocalizedString(@"Quit", nil)];
        
    [reopenButton setKeyEquivalent:@""];
    [quitButton   setKeyEquivalent:@""];
        
    return [alert runModal] == NSAlertFirstButtonReturn;
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
            [[NSWorkspace sharedWorkspace] launchApplicationAtURL:bundleURL options:NSWorkspaceLaunchNewInstance configuration:@{ } error:&error];
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

