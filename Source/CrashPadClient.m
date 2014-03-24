//
//  CrashPadClient.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-22.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "CrashPadClient.h"
#import <CrashReporter.h>
#import "Player.h"


#include <spawn.h>


static char sPath[256];


static void sHandleSignal(siginfo_t *info, ucontext_t *uap, void *context)
{
    if (PlayerShouldUseCrashPad == 0) {
        return;
    }

    static volatile BOOL sDidLaunchPod = NO;
    
    if (!sDidLaunchPod) {
        sDidLaunchPod = YES;

        int pid = -1;
        char *args[2] = { sPath, NULL };

        if (posix_spawn(&pid, sPath, NULL, NULL, args, NULL)) {
            return;
        }
    }

    while (1) {
        sleep(1);
    }
}

static PLCrashReporterCallbacks sCrashReporterCallbacks = {
    0,
    NULL,
    sHandleSignal
};


void SetupCrashPad(PLCrashReporter *reporter)
{
    NSString *path = [[NSBundle mainBundle] sharedSupportPath];
    path = [path stringByAppendingPathComponent:@"Crash Pad.app"];
    path = [path stringByAppendingPathComponent:@"Contents"];
    path = [path stringByAppendingPathComponent:@"MacOS"];
    path = [path stringByAppendingPathComponent:@"Crash Pad"];
    
    if (!path) {
        NSLog(@"path is nil, not installing crash pad!");
        return;
    }

    strncpy(sPath, [path cStringUsingEncoding:NSUTF8StringEncoding], 256);
    
    [reporter setCrashCallbacks:&sCrashReporterCallbacks];
}


