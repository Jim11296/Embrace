// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>


extern void HugApplySilenceToAudioBuffer(UInt32 inNumberFrames, AudioBufferList *ioData);

extern void HugApplyFadeToAudioBuffer(UInt32 inNumberFrames, AudioBufferList *ioData, float fromValue, float toValue);
