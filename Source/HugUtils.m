//
//  HugUtils.m
//  Embrace
//
//  Created by Ricci Adams on 2018-12-05.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "HugUtils.h"
#include <mach/mach_time.h>

static double sTimeBaseFrequency = 0;

static void sInitTimeBase()
{
    struct mach_timebase_info info;
    mach_timebase_info(&info);

    UInt32 numerator   = info.numer;
    UInt32 denominator = info.denom;

    sTimeBaseFrequency = ((double)denominator / (double)numerator) * 1000000000.0;
}


UInt64 HugGetCurrentHostTime(void)
{
    return mach_absolute_time();
}


NSTimeInterval HugGetSecondsWithHostTime(UInt64 hostTime)
{
    if (!sTimeBaseFrequency) sInitTimeBase();
    return hostTime / sTimeBaseFrequency;
}


UInt64 HugGetHostTimeWithSeconds(NSTimeInterval seconds)
{
    if (!sTimeBaseFrequency) sInitTimeBase();
    return seconds * sTimeBaseFrequency;
}


NSTimeInterval HugGetDeltaInSecondsForHostTimes(UInt64 time1, UInt64 time2)
{
    if (!sTimeBaseFrequency) sInitTimeBase();

    if (time1 > time2) {
        return (time1 - time2) /  sTimeBaseFrequency;
    } else {
        return (time2 - time1) / -sTimeBaseFrequency;
    }
}


static void (^sHugLogger)(NSString *, NSString *) = NULL;


void HugSetLogger(void (^logger)(NSString *category, NSString *message))
{
    sHugLogger = logger;
}


void HugLog(NSString *category, NSString *format, ...)
{
    if (!sHugLogger) return;

    va_list v;

    va_start(v, format);

    NSString *contents = [[NSString alloc] initWithFormat:format arguments:v];
    if (sHugLogger) sHugLogger(category, contents);
    
    va_end(v);
}


void _HugLogMethod(const char *f)
{
    if (!sHugLogger) return;

    NSString *string = [NSString stringWithUTF8String:f];

    if ([string hasPrefix:@"-["] || [string hasPrefix:@"+["]) {
        NSCharacterSet *cs = [NSCharacterSet characterSetWithCharactersInString:@"+-[]"];
        
        string = [string stringByTrimmingCharactersInSet:cs];
        NSArray *components = [string componentsSeparatedByString:@" "];
        
        sHugLogger([components firstObject], [components lastObject]);
        
    } else {
        sHugLogger(@"Function", string);
    }
}

