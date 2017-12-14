//
//  CrashReportSender
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>
@class PLCrashReporter;

@interface CrashReportSender : NSObject

+ (BOOL) isDebuggerAttached;

+ (void) sendCrashReportsWithCompletionHandler:(void (^)(BOOL didSend))completionHandler;
+ (void) sendLogsWithCompletionHandler:(void (^)(BOOL))completionHandler;

@end
