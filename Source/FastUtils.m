//
//  FastUtils.m
//  Embrace
//
//  Created by Ricci Adams on 2016-05-27.
//  Copyright © 2016 Ricci Adams. All rights reserved.
//

#import "FastUtils.h"



void ApplySilenceToAudioBuffer(UInt32 inNumberFrames, AudioBufferList *ioData)
{
    for (NSInteger i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer *buffer = &ioData->mBuffers[i];
        
        float *samples = (float *)buffer->mData;

        size_t bufferCount = buffer->mDataByteSize / sizeof(float);
        bufferCount = MIN(bufferCount, inNumberFrames);
        
        for (NSInteger j = 0; j < bufferCount; j++) {
            samples[j] = 0;
        }
    }
}


void ApplyFadeToAudioBuffer(UInt32 inNumberFrames, AudioBufferList *ioData, float inFromValue, float inToValue)
{
    const double sSilence = pow(10.0, -120.0 / 20.0); // Silence is -120dB

    double fromValue = inFromValue ? inFromValue : sSilence;
    double toValue   = inToValue   ? inToValue   : sSilence;

    
    for (NSInteger i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer *buffer = &ioData->mBuffers[i];
        
        float *samples = (float *)buffer->mData;

        size_t bufferCount = buffer->mDataByteSize / sizeof(float);
        bufferCount = MIN(bufferCount, inNumberFrames);

        double multiplier = pow(toValue / fromValue, 1 / (double)bufferCount);
        double env = fromValue;

        for (NSInteger j = 0; j < bufferCount; j++) {
            samples[j] *= env;
            env *= multiplier;
        }
    }
}
