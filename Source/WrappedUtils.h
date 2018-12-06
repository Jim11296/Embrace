// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#define EXTERN extern "C"
#else
#define EXTERN extern
#endif

EXTERN void RaiseException(void);

EXTERN void PrintStreamBasicDescription(AudioStreamBasicDescription asbd);
EXTERN NSString *GetStreamBasicDescriptionString(AudioStreamBasicDescription asbd);

EXTERN AudioStreamBasicDescription GetPCMStreamBasicDescription(double inSampleRate, UInt32 inNumChannels, BOOL interleaved);

#undef EXTERN
