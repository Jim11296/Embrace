//
//  HugUtils.h
//  Embrace
//
//  Created by Ricci Adams on 2018-12-05.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

extern UInt64 HugGetCurrentHostTime(void);

extern NSTimeInterval HugGetSecondsWithHostTime(UInt64 hostTime);
extern UInt64 HugGetHostTimeWithSeconds(NSTimeInterval seconds);
extern NSTimeInterval HugGetDeltaInSecondsForHostTimes(UInt64 time1, UInt64 time2);

extern NSString *HugGetStringForFourCharCode(OSStatus fcc);

extern void HugSetLogger(void (^)(NSString *category, NSString *message));

extern void HugLog(NSString *category, NSString *format, ...) NS_FORMAT_FUNCTION(2,3);

extern void _HugLogMethod(const char *f);

extern BOOL HugCheckError(OSStatus error, NSString *category, NSString *operation);
extern BOOL HugCheckErrorGroup(void (^block)());



#define HugLogMethod() _HugLogMethod(__PRETTY_FUNCTION__)

#ifdef __cplusplus
}
#endif

