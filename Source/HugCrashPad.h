// (c) 2018-2019 Ricci Adams.  All rights reserved.

/*
    Wiring up a crash pad:

    1) Prior to crashing, call HugCrashPadSetHelperPath with a valid path to
       a helper application. This application should display a dialog, such as:
       
       TheAppName encountered a critical error.
       Your current song will continue to play, but you must reopen the app to
       play other songs or access other features.
    
    2) In your crash reporter's signal handler, you must *NOT* call
       thread_suspend() on the thread returned by HugCrashPadGetIgnoredThread()
       
    3) In your crash reporter's signal handler, call HugCrashPadSignalHandler()
       prior to re-raising the signal.
       
    When a non-audio thread crashes, HugCrashPadSignalHandler will launch the
    helper application and then sleep indefinitely.
*/

#import <Foundation/Foundation.h>

extern BOOL HugCrashPadIsDebuggerAttached(void);

extern void HugCrashPadSignalHandler(int signal, siginfo_t *info, ucontext_t *uap);
extern mach_port_t HugCrashPadGetIgnoredThread(void);

extern void HugCrashPadSetHelperPath(NSString *helperPath);
extern NSString *HugCrashPadGetHelperPath(void);


