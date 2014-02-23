//
//  AudioUtils.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#define EXTERN extern "C"
#else
#define EXTERN extern
#endif

EXTERN void FillAudioTimeStampWithFutureSeconds(AudioTimeStamp *timeStamp, NSTimeInterval interval);

EXTERN UInt64 GetCurrentHostTime(void);

EXTERN void RaiseException(void);

EXTERN NSTimeInterval GetDeltaInSecondsForHostTimes(UInt64 time1, UInt64 time2);

EXTERN void PrintStreamBasicDescription(AudioStreamBasicDescription asbd);
EXTERN NSString *GetStreamBasicDescriptionString(AudioStreamBasicDescription asbd);

EXTERN AudioStreamBasicDescription GetPCMStreamBasicDescription(double inSampleRate, UInt32 inNumChannels, BOOL interleaved);

#undef EXTERN
