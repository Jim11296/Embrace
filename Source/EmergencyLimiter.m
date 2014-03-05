//
//  EmergencyLimiter.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-16.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "EmergencyLimiter.h"

#import <Accelerate/Accelerate.h>

#define CHECK_RESULTS 1

static float sPeakValue =  1.0 - (2.0 / 32767.0);

enum {
    EmergencyLimiterStateOff,
    EmergencyLimiterStateHolding,
    EmergencyLimiterStateDecaying
} EmergencyLimiterState;

struct EmergencyLimiter {
    NSInteger _holdTime;
    NSInteger _decayTime;
    NSInteger _initialDecayTime;
    NSInteger _maxDecayTime;
    double _sampleRate;


    NSInteger _state;

    float     _lastMax;
    float     _multiplier;
    float     _multiplierAtDecayStart;

    NSInteger _samplesHeld;
    NSInteger _samplesDecayed;
    
};

inline static float lerp(float v0, float v1, float t)
{
    return (v0 * (1.0f - t)) + (v1 * t);
}


inline static void sApplyEnvelope(
    UInt32 frameCount,
    AudioBufferList *bufferList,
    float fromMultiplier,
    float toMultiplier,
    NSInteger toIndex)
{
    NSInteger bufferCount = bufferList->mNumberBuffers;
    

    for (NSInteger i = 0; i < bufferCount; i++) {
        AudioBuffer buffer = bufferList->mBuffers[i];
        
        float *samples = (float *)buffer.mData;
        NSInteger sampleCount = buffer.mDataByteSize / sizeof(float);
    
    
        // If toIndex is specified, apply linear ramp from fromMultiplier to toMultiplier
        if (toIndex) {
            if (toIndex > sampleCount) toIndex = sampleCount;
        
            float step  = -(fromMultiplier - toMultiplier) / (float)toIndex;
            vDSP_vrampmul(samples, 1, &fromMultiplier, &step, samples, 1, toIndex);
        }

        if ((sampleCount - toIndex) > 0) {
            vDSP_vsmul(samples + toIndex, 1, &toMultiplier, samples + toIndex, 1, sampleCount - toIndex);
        }
    }
}


inline static void sGetMax(UInt32 frameCount, AudioBufferList *bufferList, float *outMax, NSInteger *outMaxIndex)
{
    float     max      = 0;
    NSInteger maxIndex = 0;

    NSInteger bufferCount = bufferList->mNumberBuffers;

    for (NSInteger i = 0; i < bufferCount; i++) {
        AudioBuffer buffer = bufferList->mBuffers[i];
        
        float *samples = (float *)buffer.mData;
        NSInteger sampleCount = buffer.mDataByteSize / sizeof(float);

        float channelMax;
        vDSP_maxv(samples, 1, &channelMax, sampleCount);

        float channelMin;
        vDSP_maxv(samples, 1, &channelMin, sampleCount);

        if (-channelMin > channelMax) {
            channelMax = -channelMin;
        }
        
        if (channelMax > max) {
            max = channelMax;
        }
    }
    
    if (max > sPeakValue) {
        for (NSInteger i = 0; i < bufferCount; i++) {
            AudioBuffer buffer = bufferList->mBuffers[i];

            NSInteger channelIndex = 0;
            
            float *samples = (float *)buffer.mData;
            NSInteger sampleCount = buffer.mDataByteSize / sizeof(float);
            
            for (NSInteger s = 0; s < sampleCount; s++) {
                float sample = samples[s];

                if ((sample > sPeakValue) || (sample < -sPeakValue)) {
                    channelIndex = s;
                    break;
                }
            }
            
            if (channelIndex < maxIndex) {
                maxIndex = channelIndex;
            }
        }
    }
    
    *outMax = max;
    *outMaxIndex = maxIndex;
}


inline static void sRamp(EmergencyLimiter *self, UInt32 frameCount, AudioBufferList *bufferList, float max, NSInteger index)
{
    float toMultiplier = sPeakValue / max;

    sApplyEnvelope(frameCount, bufferList, self->_multiplier, toMultiplier, index);

    self->_multiplier = toMultiplier;
    self->_state = EmergencyLimiterStateHolding;
    self->_samplesHeld = 0;
    self->_samplesDecayed = 0;
}


inline static void sHold(EmergencyLimiter *self, UInt32 frameCount, AudioBufferList *bufferList)
{
    sApplyEnvelope(frameCount, bufferList, 0, self->_multiplier, 0);
    
    self->_samplesHeld += frameCount;

    if (self->_samplesHeld > self->_holdTime) {
        self->_state = EmergencyLimiterStateDecaying;
        self->_multiplierAtDecayStart = self->_multiplier;
        self->_samplesDecayed = 0;
    }
}


inline static void sDecay(EmergencyLimiter *self, UInt32 frameCount, AudioBufferList *bufferList)
{
    float percent = ((self->_samplesDecayed + frameCount) / (float)self->_decayTime);
    if (percent > 1.0) percent = 1.0;
    
    float toMultiplier = lerp(self->_multiplierAtDecayStart, 1.0, percent);

    sApplyEnvelope(frameCount, bufferList, self->_multiplier, toMultiplier, frameCount);

    self->_samplesDecayed += frameCount;
    self->_multiplier = toMultiplier;

    if (self->_samplesDecayed > self->_decayTime) {
        EmergencyLimiterReset(self);
    }
}


#pragma mark - Public Functions

EmergencyLimiter *EmergencyLimiterCreate(NSInteger holdTime, NSInteger decayTime)
{
    EmergencyLimiter *self = malloc(sizeof(EmergencyLimiter));
    
    self->_holdTime  = holdTime;
    self->_decayTime = decayTime;
    self->_initialDecayTime = decayTime;

    EmergencyLimiterReset(self);
    
    return self;
}


void EmergencyLimiterFree(EmergencyLimiter *limiter)
{
    free(limiter);
}


void EmergencyLimiterReset(EmergencyLimiter *self)
{
    self->_state = EmergencyLimiterStateOff;
    self->_lastMax = sPeakValue;
    self->_multiplier = 1.0;
    self->_multiplierAtDecayStart = 1.0;
    self->_samplesHeld = 0;
    self->_samplesDecayed = 0;
    self->_decayTime = self->_initialDecayTime;
}


void EmergencyLimiterProcess(EmergencyLimiter *self, UInt32 frameCount, AudioBufferList *bufferList)
{
    float max;
    NSInteger maxIndex;

    sGetMax(frameCount, bufferList, &max, &maxIndex);
    
    if (max > self->_lastMax) {
        self->_lastMax = max;
        sRamp(self, frameCount, bufferList, max, maxIndex);
    
    } else if (self->_state == EmergencyLimiterStateHolding) {
        sHold(self, frameCount, bufferList);

    } else if (self->_state == EmergencyLimiterStateDecaying) {
        sDecay(self, frameCount, bufferList);
        sGetMax(frameCount, bufferList, &max, &maxIndex);
        
        if (max > sPeakValue) {
            float oldMultiplier = self->_multiplier;
            self->_multiplier = 1.0;
            sRamp(self, frameCount, bufferList, max, maxIndex);
            
            self->_multiplier *= oldMultiplier;
            self->_lastMax = sPeakValue / oldMultiplier;
            
            self->_decayTime *= 2;

            if (self->_decayTime > self->_maxDecayTime) {
                self->_decayTime = self->_maxDecayTime;
            }
        }
    }

#if CHECK_RESULTS
        sGetMax(frameCount, bufferList, &max, &maxIndex);
        if (max >= 1.0) {
            NSLog(@"Still clipping after emergency limiter");
        }
#endif
}


void EmergencyLimiterSetSampleRate(EmergencyLimiter *self, double sampleRate)
{
    self->_sampleRate   = sampleRate;
    self->_holdTime     = sampleRate * 0.25;

    self->_initialDecayTime = sampleRate * 0.25;
    self->_maxDecayTime     = sampleRate * 16;

    self->_decayTime = self->_initialDecayTime;
    
    EmergencyLimiterReset(self);
}


double EmergencyLimiterGetSampleRate(EmergencyLimiter *self)
{
    return self->_sampleRate;
}


BOOL EmergencyLimiterIsActive(EmergencyLimiter *self)
{
    return self->_state != EmergencyLimiterStateOff;
}

