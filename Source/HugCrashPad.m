// (c) 2018-2020 Ricci Adams.  All rights reserved.

#import "HugCrashPad.h"

#include <spawn.h>
#include <sys/sysctl.h>

volatile mach_port_t _HugCrashPadIgnoredThread = 0;
volatile BOOL _HugCrashPadEnabled = NO;

static NSString *sHelperPathString = nil;
static char     *sHelperPathBytes  = nil;


extern BOOL HugCrashPadIsDebuggerAttached(void)
{
    return NO;
    
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


mach_port_t HugCrashPadGetIgnoredThread()
{
    return _HugCrashPadIgnoredThread;
}


void HugCrashPadSignalHandler(int signal, siginfo_t *info, ucontext_t *uap)
{
    if (!_HugCrashPadEnabled) {
        return;
    }

    static volatile BOOL sDidLaunchPod = NO;
    
    if (!sDidLaunchPod && sHelperPathBytes) {
        sDidLaunchPod = YES;

        int pid = -1;
        char *args[2] = { sHelperPathBytes, NULL };

        if (posix_spawn(&pid, sHelperPathBytes, NULL, NULL, args, NULL)) {
            return;
        }
    }

    while (1) {
        sleep(1);
    }
}


extern void HugCrashPadSetHelperPath(NSString *helperPath)
{
    sHelperPathString = helperPath;

    free(sHelperPathBytes);
    sHelperPathBytes = NULL;
    
    const char *cString = [helperPath UTF8String];

    if (cString) {
        size_t len = strlen(cString);
        sHelperPathBytes = malloc(len + 1);
        
        memcpy(sHelperPathBytes, cString, len);
        sHelperPathBytes[len] = 0;
    }
}


extern NSString *HugCrashPadGetHelperPath(void)
{
    return sHelperPathString;
}

