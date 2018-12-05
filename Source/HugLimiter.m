// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "HugLimiter.h"

#import <Accelerate/Accelerate.h>

#define CHECK_RESULTS 0

static float sPeakValue =  1.0 - (2.0 / 32767.0);

enum {
    HugLimiterStateOff,
    HugLimiterStateHolding,
    HugLimiterStateDecaying
} HugLimiterState;

struct HugLimiter {
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

    for (NSInteger b = 0; b < bufferCount; b++) {
        AudioBuffer buffer = bufferList->mBuffers[b];
        
        float *samples = (float *)buffer.mData;
        NSInteger sampleCount = buffer.mDataByteSize / sizeof(float);
    
        // If toIndex is specified, apply linear ramp from fromMultiplier to toMultiplier
        if (toIndex) {
            if (toIndex > sampleCount) toIndex = sampleCount;
        
            for (NSInteger s = 0; s < toIndex; s++) {
                samples[s] *= lerp(fromMultiplier, toMultiplier, (s / (float)toIndex));
            }
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
        AudioBuffer buffer  = bufferList->mBuffers[i];
        float      *samples = (float *)buffer.mData;

        float bufferMax;
        vDSP_Length bufferMaxIndex;
        vDSP_maxvi(samples, 1, &bufferMax, &bufferMaxIndex, frameCount);

        float bufferMin;
        vDSP_Length bufferMinIndex;
        vDSP_minvi(samples, 1, &bufferMin, &bufferMinIndex, frameCount);

        if (-bufferMin > bufferMax) {
            bufferMax = -bufferMin;
            bufferMaxIndex = bufferMinIndex;
        }
        
        if (bufferMax > max) {
            max = bufferMax;
            maxIndex = bufferMaxIndex;
        }
    }
    
    *outMax = max;
    *outMaxIndex = maxIndex;
}


inline static void sRamp(HugLimiter *self, UInt32 frameCount, AudioBufferList *bufferList, float max, NSInteger index)
{
    float toMultiplier = sPeakValue / max;

    sApplyEnvelope(frameCount, bufferList, self->_multiplier, toMultiplier, index);

    self->_multiplier = toMultiplier;
    self->_state = HugLimiterStateHolding;
    self->_samplesHeld = 0;
    self->_samplesDecayed = 0;
}


inline static void sHold(HugLimiter *self, UInt32 frameCount, AudioBufferList *bufferList)
{
    sApplyEnvelope(frameCount, bufferList, 0, self->_multiplier, 0);
    
    self->_samplesHeld += frameCount;

    if (self->_samplesHeld > self->_holdTime) {
        self->_state = HugLimiterStateDecaying;
        self->_multiplierAtDecayStart = self->_multiplier;
        self->_samplesDecayed = 0;
    }
}


inline static void sDecay(HugLimiter *self, UInt32 frameCount, AudioBufferList *bufferList)
{
    float percent = ((self->_samplesDecayed + frameCount) / (float)self->_decayTime);
    if (percent > 1.0) percent = 1.0;
    
    float toMultiplier = lerp(self->_multiplierAtDecayStart, 1.0, percent);

    sApplyEnvelope(frameCount, bufferList, self->_multiplier, toMultiplier, frameCount);

    self->_samplesDecayed += frameCount;
    self->_multiplier = toMultiplier;

    if (self->_samplesDecayed > self->_decayTime) {
        HugLimiterReset(self);
    }
}


#pragma mark - Lifecycle

HugLimiter *HugLimiterCreate()
{
    HugLimiter *self = malloc(sizeof(HugLimiter));
    
    self->_holdTime  = 0.0;
    self->_decayTime = 0.0;
    self->_initialDecayTime = 0.0;

    HugLimiterReset(self);
    
    return self;
}


void HugLimiterFree(HugLimiter *limiter)
{
    free(limiter);
}


#pragma mark - Public Methods

void HugLimiterReset(HugLimiter *self)
{
    self->_state = HugLimiterStateOff;
    self->_lastMax = sPeakValue;
    self->_multiplier = 1.0;
    self->_multiplierAtDecayStart = 1.0;
    self->_samplesHeld = 0;
    self->_samplesDecayed = 0;
    self->_decayTime = self->_initialDecayTime;
}


void HugLimiterProcess(HugLimiter *self, UInt32 frameCount, AudioBufferList *bufferList)
{
    float max;
    NSInteger maxIndex;

    sGetMax(frameCount, bufferList, &max, &maxIndex);
    
    if (max > self->_lastMax) {
        self->_lastMax = max;
        sRamp(self, frameCount, bufferList, max, maxIndex);
    
    } else if (self->_state == HugLimiterStateHolding) {
        sHold(self, frameCount, bufferList);

    } else if (self->_state == HugLimiterStateDecaying) {
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
            NSLog(@"Still clipping after limiter");
        }
#endif
}


#pragma mark - Accessors

void HugLimiterSetSampleRate(HugLimiter *self, double sampleRate)
{
    self->_sampleRate   = sampleRate;
    self->_holdTime     = sampleRate * 0.25;

    self->_initialDecayTime = sampleRate * 0.25;
    self->_maxDecayTime     = sampleRate * 16;

    self->_decayTime = self->_initialDecayTime;
    
    HugLimiterReset(self);
}


double HugLimiterGetSampleRate(const HugLimiter *self)
{
    return self->_sampleRate;
}


BOOL HugLimiterIsActive(const HugLimiter *self)
{
    return self->_state != HugLimiterStateOff;
}

