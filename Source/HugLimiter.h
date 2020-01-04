// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

typedef struct HugLimiter HugLimiter;

extern HugLimiter *HugLimiterCreate(void);
extern void HugLimiterFree(HugLimiter *limiter);

extern void HugLimiterReset(HugLimiter *limiter);
extern void HugLimiterProcess(HugLimiter *self, float *left, float *right, size_t frameCount);

extern void HugLimiterSetSampleRate(HugLimiter *limiter, double sampleRate);
extern double HugLimiterGetSampleRate(const HugLimiter *limiter);

extern BOOL HugLimiterIsActive(const HugLimiter *limiter);
