//
//  CrashPadClient.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-22.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "CrashPadClient.h"
#import "Player.h"
#import "MTSEscapePod.h"

#include <spawn.h>
#include <sys/sysctl.h>

static char sPath[256];


static void sHandleSignal(int signal, siginfo_t *info, ucontext_t *uap)
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



extern BOOL CrashPadIsDebuggerAttached(void)
{
    static BOOL sIsAttached = NO;
    static BOOL sChecked = NO;

    if (sChecked) return sIsAttached;

    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];
  
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
  
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        sIsAttached = NO;
    }
  
    if (!sIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0) {
        sIsAttached = true;
    }

    sChecked = YES;
  
    return sIsAttached;
}


void SetupCrashPad()
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
    
    MTSEscapePodSetSignalCallback(sHandleSignal);
}


