//
//  CrashPadClient.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-22.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "CrashPadClient.h"
#import <CrashReporter/CrashReporter.h>

#include <spawn.h>


static char sPath[256];


static void sHandleSignal(siginfo_t *info, ucontext_t *uap, void *context)
{
    static BOOL sDidLaunchPod = NO;
    
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
    NSString *path = [[NSBundle mainBundle] executablePath];
    path = [path stringByDeletingLastPathComponent];
    path = [path stringByAppendingPathComponent:@"CrashPad"];
    
    if (!path) {
        NSLog(@"path is nil, not installing crash pad!");
        return;
    }

    strncpy(sPath, [path cStringUsingEncoding:NSUTF8StringEncoding], 256);
    
    [reporter setCrashCallbacks:&sCrashReporterCallbacks];
}

