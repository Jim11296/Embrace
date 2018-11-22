// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>


@interface CrashReportSender : NSObject

+ (BOOL) isDebuggerAttached;

+ (void) sendCrashReportsWithCompletionHandler:(void (^)(BOOL didSend))completionHandler;
+ (void) sendLogsWithCompletionHandler:(void (^)(BOOL))completionHandler;

@end
