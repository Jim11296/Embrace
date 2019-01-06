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
    float *samples,
    size_t frameCount,
    float fromMultiplier,
    float toMultiplier,
    NSInteger toIndex)
{
    // If toIndex is specified, apply linear ramp from fromMultiplier to toMultiplier
    if (toIndex) {
        if (toIndex > frameCount) toIndex = frameCount;
    
        for (NSInteger s = 0; s < toIndex; s++) {
            samples[s] *= lerp(fromMultiplier, toMultiplier, (s / (float)toIndex));
        }
    }

    if ((frameCount - toIndex) > 0) {
        vDSP_vsmul(samples + toIndex, 1, &toMultiplier, samples + toIndex, 1, frameCount - toIndex);
    }
}

inline static void sGetMax(float *samples, size_t frameCount, float *outMax, NSInteger *outMaxIndex)
{
    float     max      = 0;
    NSInteger maxIndex = 0;

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
    
    *outMax = max;
    *outMaxIndex = maxIndex;
}


inline static void sGetStereoMax(float *left, float *right, size_t frameCount, float *outMax, NSInteger *outMaxIndex)
{
    float     leftMax      = 0;
    NSInteger leftMaxIndex = 0;

    float     rightMax      = 0;
    NSInteger rightMaxIndex = 0;

    if (left)  sGetMax(left,  frameCount, &leftMax,  &leftMaxIndex);
    if (right) sGetMax(right, frameCount, &rightMax, &rightMaxIndex);
 
    if (rightMax > leftMax) {
        leftMax      = rightMax;
        leftMaxIndex = rightMaxIndex;
    }
    
    *outMax      = leftMax;
    *outMaxIndex = leftMaxIndex;
}


inline static void sRamp(HugLimiter *self, float *left, float *right, size_t frameCount, float max, NSInteger index)
{
    float toMultiplier = sPeakValue / max;

    if (left)  sApplyEnvelope(left,  frameCount, self->_multiplier, toMultiplier, index);
    if (right) sApplyEnvelope(right, frameCount, self->_multiplier, toMultiplier, index);

    self->_multiplier = toMultiplier;
    self->_state = HugLimiterStateHolding;
    self->_samplesHeld = 0;
    self->_samplesDecayed = 0;
}


inline static void sHold(HugLimiter *self, float *left, float *right, size_t frameCount)
{
    if (left)  sApplyEnvelope(left,  frameCount, self->_multiplier, self->_multiplier, 0);
    if (right) sApplyEnvelope(right, frameCount, self->_multiplier, self->_multiplier, 0);

    self->_samplesHeld += frameCount;

    if (self->_samplesHeld > self->_holdTime) {
        self->_state = HugLimiterStateDecaying;
        self->_multiplierAtDecayStart = self->_multiplier;
        self->_samplesDecayed = 0;
    }
}


inline static void sDecay(HugLimiter *self, float *left, float *right, size_t frameCount)
{
    float percent = ((self->_samplesDecayed + frameCount) / (float)self->_decayTime);
    if (percent > 1.0) percent = 1.0;
    
    float toMultiplier = lerp(self->_multiplierAtDecayStart, 1.0, percent);

    if (left)  sApplyEnvelope(left,  frameCount, self->_multiplier, toMultiplier, frameCount);
    if (right) sApplyEnvelope(right, frameCount, self->_multiplier, toMultiplier, frameCount);

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


void HugLimiterProcess(HugLimiter *self, float *left, float *right, size_t frameCount)
{
    float max;
    NSInteger maxIndex;

    sGetStereoMax(left, right, frameCount, &max, &maxIndex);
    
    if (max > self->_lastMax) {
        self->_lastMax = max;
        sRamp(self, left, right, frameCount, max, maxIndex);
    
    } else if (self->_state == HugLimiterStateHolding) {
        sHold(self, left, right, frameCount);

    } else if (self->_state == HugLimiterStateDecaying) {
        sDecay(self, left, right, frameCount);
        sGetStereoMax(left, right, frameCount, &max, &maxIndex);
        
        if (max > sPeakValue) {
            float oldMultiplier = self->_multiplier;
            self->_multiplier = 1.0;
            sRamp(self, left, right, frameCount, max, maxIndex);
            
            self->_multiplier *= oldMultiplier;
            self->_lastMax = sPeakValue / oldMultiplier;
            
            self->_decayTime *= 2;

            if (self->_decayTime > self->_maxDecayTime) {
                self->_decayTime = self->_maxDecayTime;
            }
        }
    }

#if CHECK_RESULTS
        sGetStereoMax(left, right, frameCount, &max, &maxIndex);
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

