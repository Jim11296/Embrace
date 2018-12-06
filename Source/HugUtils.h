//
//  HugUtils.h
//  Embrace
//
//  Created by Ricci Adams on 2018-12-05.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern UInt64 HugGetCurrentHostTime(void);

extern NSTimeInterval HugGetSecondsWithHostTime(UInt64 hostTime);
extern UInt64 HugGetHostTimeWithSeconds(NSTimeInterval seconds);
extern NSTimeInterval HugGetDeltaInSecondsForHostTimes(UInt64 time1, UInt64 time2);

extern void HugSetLogger(void (^)(NSString *));

extern void HugLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

extern void _HugLogMethod(const char *f);
#define HugLogMethod() _HugLogMethod(__PRETTY_FUNCTION__)

