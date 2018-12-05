// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "HugLevelMeter.h"

#import <Accelerate/Accelerate.h>


inline static void sGetPeak(UInt32 frameCount, float *samples, float *outMax, NSInteger *outMaxIndex)
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


struct HugLevelMeter {
    UInt32 _frameCount;
    double _sampleRate;
    UInt8  _averageEnabled;

    float *_scratch;

    double _averageLevel;
    double _peakLevel;
    double _heldLevel;
    double _decay;
    
    UInt32 _heldIndex;
    UInt32 _heldCount;
    
};


#pragma mark - Lifecycle

HugLevelMeter *HugLevelMeterCreate()
{
    HugLevelMeter *self = calloc(1, sizeof(HugLevelMeter));
    
    HugLevelMeterReset(self);
    
    return self;
}


void HugLevelMeterFree(HugLevelMeter *meter)
{
    if (!meter) return;

    if (meter->_scratch) {
        free(meter->_scratch);
    }

    free(meter);
}


#pragma mark - Public Methods

void HugLevelMeterReset(HugLevelMeter *self)
{
    self->_averageLevel = 0;
    self->_peakLevel = 0;
    self->_heldLevel = 0;

    if (self->_sampleRate > 0) {
        self->_heldCount = self->_sampleRate * 0.8;
        
        double peakDecayRateDB = (self->_frameCount / self->_sampleRate) * -11.8;
        self->_decay = pow(10, peakDecayRateDB / 20.0);

    } else {
        self->_heldCount = 0;
        self->_decay = 0;
    }
    

    free(self->_scratch);
    self->_scratch = NULL;

    if (self->_averageEnabled && self->_frameCount) {
        self->_scratch = malloc(sizeof(float) * self->_frameCount);
    }
}


void HugLevelMeterProcess(HugLevelMeter *self, float *buffer)
{
    
    UInt32 frameCount = self->_frameCount;

    float currentAverage;
    float currentPeak;
    NSInteger peakIndex;

    sGetPeak(frameCount, buffer, &currentPeak, &peakIndex);

    // Calculate RMS of scratch buffer
    if (self->_scratch) {
        vDSP_vsq(buffer, 1, self->_scratch, 1, frameCount);
        vDSP_meanv(self->_scratch, 1, &currentAverage, frameCount);
        currentAverage = sqrtf(currentAverage);
    } else {
        currentAverage = 0;
    }

    double decayedAverageLevel = self->_averageLevel;
    double decayedPeakLevel    = self->_peakLevel;
    double decayedHeldLevel    = self->_heldLevel;
    double decay               = self->_decay;
    
    // Always decay average and peak
    {
        decayedAverageLevel *= decay;
        decayedPeakLevel *= decay;
    }
    
    // Decay held level once we've held it for a second
    self->_heldIndex += self->_frameCount;
    if (self->_heldIndex >= self->_heldCount) {
        decayedHeldLevel *= decay;
    }
    
    if (currentAverage > decayedAverageLevel) {
        self->_averageLevel = currentAverage;
    } else {
        self->_averageLevel = decayedAverageLevel;
    }

    if (currentPeak > decayedPeakLevel) {
        self->_peakLevel = currentPeak;
    } else {
        self->_peakLevel = decayedPeakLevel;
    }

    if (currentPeak > decayedHeldLevel) {
        self->_heldLevel = currentPeak;
        self->_heldIndex = 0;
    } else {
        self->_heldLevel = decayedHeldLevel;
    }
}


#pragma mark - Accessors

void HugLevelMeterSetSampleRate(HugLevelMeter *self, double sampleRate)
{
    self->_sampleRate = sampleRate;
    HugLevelMeterReset(self);
}


double HugLevelMeterGetSampleRate(const HugLevelMeter *self)
{
    return self->_sampleRate;
}


void HugLevelMeterSetFrameCount(HugLevelMeter *self, UInt32 frameCount)
{
    self->_frameCount = frameCount;
    HugLevelMeterReset(self);
}


UInt32 HugLevelMeterGetFrameCount(const HugLevelMeter *self)
{
    return self->_frameCount;
}


void HugLevelMeterSetAverageEnabled(HugLevelMeter *self, UInt8 averageEnabled)
{
    self->_averageEnabled = averageEnabled;
    HugLevelMeterReset(self);
}


UInt8 HugLevelMeterIsAverageEnabled(const HugLevelMeter *self)
{
    return self->_averageEnabled > 0;
}


float HugLevelMeterGetAverageLevel(const HugLevelMeter *self)
{
    return self->_averageLevel;
}


float HugLevelMeterGetPeakLevel(const HugLevelMeter *self)
{
    return self->_peakLevel;
}


float HugLevelMeterGetHeldLevel(const HugLevelMeter *self)
{
    return self->_heldLevel;
}

