// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "HugLevelMeter.h"

#import <Accelerate/Accelerate.h>


inline static void sGetPeak(float *samples, size_t frameCount, float *outMax, NSInteger *outMaxIndex)
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
    size_t _maxFrameCount;
    double _sampleRate;
    UInt8  _averageEnabled;

    float *_scratch;
    size_t _scratchSize;

    double _averageLevel;
    double _peakLevel;
    double _heldLevel;
    
    size_t _heldIndex;
    size_t _heldCount;
    
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


#pragma mark - Private Methods

static void sRemakeScratch(HugLevelMeter *self)
{
    size_t scratchSize = 0;
    if (self->_averageEnabled && self->_maxFrameCount) {
        scratchSize = sizeof(float) * self->_maxFrameCount;
    }

    if (scratchSize != self->_scratchSize) {
        free(self->_scratch);
        self->_scratch = scratchSize ? malloc(scratchSize) : NULL;
        self->_scratchSize = scratchSize;
    }

    HugLevelMeterReset(self);
}


#pragma mark - Public Methods

void HugLevelMeterReset(HugLevelMeter *self)
{
    self->_averageLevel = 0;
    self->_peakLevel = 0;
    self->_heldLevel = 0;

    if (self->_sampleRate > 0) {
        self->_heldCount = self->_sampleRate * 0.8;
    } else {
        self->_heldCount = 0;
    }
}


extern void HugLevelMeterProcess(HugLevelMeter *self, float *buffer, size_t frameCount)
{
    if (frameCount > self->_maxFrameCount) {
        frameCount = self->_maxFrameCount;
    }

    float currentAverage;
    float currentPeak;
    NSInteger peakIndex;

    sGetPeak(buffer, frameCount, &currentPeak, &peakIndex);

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

    double decayRateDB = (frameCount / self->_sampleRate) * -11.8;
    double decay = pow(10, decayRateDB / 20.0);    
    
    // Always decay average and peak
    {
        decayedAverageLevel *= decay;
        decayedPeakLevel *= decay;
    }
    
    // Decay held level once we've held it for a second
    self->_heldIndex += frameCount;
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
    sRemakeScratch(self);
}


double HugLevelMeterGetSampleRate(const HugLevelMeter *self)
{
    return self->_sampleRate;
}


void HugLevelMeterSetMaxFrameCount(HugLevelMeter *self, size_t maxFrameCount)
{
    self->_maxFrameCount = maxFrameCount;
    sRemakeScratch(self);
}


size_t HugLevelMeterGetMaxFrameCount(const HugLevelMeter *self)
{
    return self->_maxFrameCount;
}


void HugLevelMeterSetAverageEnabled(HugLevelMeter *self, UInt8 averageEnabled)
{
    self->_averageEnabled = averageEnabled;
    sRemakeScratch(self);
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

