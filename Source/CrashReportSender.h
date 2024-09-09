// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>


@interface CrashReportSender : NSObject

+ (NSString *) logsTelemetryName;

+ (BOOL) isDebuggerAttached;

+ (void) sendCrashReportsWithCompletionHandler:(void (^)(BOOL didSend))completionHandler;
+ (void) sendLogsWithCompletionHandler:(void (^)(BOOL))completionHandler;

@end
