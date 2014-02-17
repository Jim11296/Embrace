//
//  EmergencyLimiter.h
//  Embrace
//
//  Created by Ricci Adams on 2014-02-16.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct EmergencyLimiter EmergencyLimiter;

extern EmergencyLimiter *EmergencyLimiterCreate();
extern void EmergencyLimiterFree(EmergencyLimiter *limiter);

extern void EmergencyLimiterReset(EmergencyLimiter *limiter);

extern void EmergencyLimiterSetSampleRate(EmergencyLimiter *limiter, double sampleRate);
extern double EmergencyLimiterGetSampleRate(EmergencyLimiter *limiter);

extern void EmergencyLimiterProcess(EmergencyLimiter *limiter, UInt32 frameCount, AudioBufferList *bufferList);

extern BOOL EmergencyLimiterIsActive(EmergencyLimiter *limiter);
