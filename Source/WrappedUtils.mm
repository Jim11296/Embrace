//
//  WrappedUtils
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WrappedUtils.h"
#import "CAHostTimeBase.h"
#import "CAStreamBasicDescription.h"

#include <exception>

extern "C" void FillAudioTimeStampWithFutureSeconds(AudioTimeStamp *timeStamp, NSTimeInterval seconds)
{
    Float64 hostTimeFreq = CAHostTimeBase::GetFrequency();
    UInt64 startHostTime = CAHostTimeBase::GetCurrentTime() + seconds * hostTimeFreq;

    timeStamp->mFlags = kAudioTimeStampHostTimeValid;
    timeStamp->mHostTime = startHostTime;
}


extern "C" UInt64 GetCurrentHostTime(void)
{
    return CAHostTimeBase::GetTheCurrentTime();
}


extern "C" NSTimeInterval GetDeltaInSecondsForHostTimes(UInt64 time1, UInt64 time2)
{
    Float64 hostTimeFreq = CAHostTimeBase::GetFrequency();

    if (time1 > time2) {
        return (time1 - time2) /  hostTimeFreq;
    } else {
        return (time2 - time1) / -hostTimeFreq;
    }
}


extern "C" void PrintStreamBasicDescription(AudioStreamBasicDescription asbd)
{
    CAStreamBasicDescription(asbd).Print();
}


extern "C" NSString *GetStreamBasicDescriptionString(AudioStreamBasicDescription asbd)
{
    char buf[1024];
    char *s = CAStreamBasicDescription(asbd).AsString(buf, sizeof(buf));

    return [NSString stringWithCString:s encoding:NSUTF8StringEncoding];
}


extern "C" AudioStreamBasicDescription GetPCMStreamBasicDescription(double sampleRate, UInt32 channelCount, BOOL interleaved)
{
    AudioStreamBasicDescription result = CAStreamBasicDescription(
        sampleRate,
        channelCount,
        CAStreamBasicDescription::kPCMFormatFloat32,
        interleaved
    );

    return result;
}


extern "C" void RaiseException(void)
{
    throw "";
}

