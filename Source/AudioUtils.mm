//
//  AudioUtils.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "AudioUtils.h"
#import "CAHostTimeBase.h"
#import "CAStreamBasicDescription.h"

AudioTimeStamp myAudioQueueStartTime = {0};


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

extern "C" BOOL CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return YES;
	
	char str[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(str, "%d", (int)error);
	
	fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
    return NO;
}


extern "C" void PrintStreamBasicDescription(AudioStreamBasicDescription asbd)
{
    CAStreamBasicDescription(asbd).Print();
}


