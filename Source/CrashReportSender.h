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

+ (NSString *) deviceModel;

+ (BOOL) isDebuggerAttached;

- (id) initWithAppIdentifier:(NSString *)appIdentifier;

- (void) extractPendingReportFromReporter:(PLCrashReporter *)reporter;
- (void) sendCrashReports;

@property (nonatomic, readonly) BOOL hasCrashReports;
@property (nonatomic, readonly) NSString *appIdentifier;

@end
