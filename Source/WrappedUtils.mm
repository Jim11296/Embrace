// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "WrappedUtils.h"
#import "CAStreamBasicDescription.h"

#include <exception>


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

