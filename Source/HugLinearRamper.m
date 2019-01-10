// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import "HugLinearRamper.h"

#import <Accelerate/Accelerate.h>


struct HugLinearRamper {
    size_t _maxFrameCount;
    float  _previousLevel;
    float *_scratch;
};


#pragma mark - Lifecycle

HugLinearRamper *HugLinearRamperCreate()
{
    HugLinearRamper *self = calloc(1, sizeof(HugLinearRamper));
    return self;
}


void HugLinearRamperFree(HugLinearRamper *ramper)
{
    if (!ramper) return;

    if (ramper->_scratch) {
        free(ramper->_scratch);
    }

    free(ramper);
}


#pragma mark - Public Methods

void HugLinearRamperReset(HugLinearRamper *self, float level)
{
    self->_previousLevel = level;
}


void HugLinearRamperProcess(HugLinearRamper *self, float *left, float *right, size_t frameCount, float level)
{  
    float previousLevel = self->_previousLevel;
    float *scratch = self->_scratch;

    // Fast path, level is the same as previous
    if (level == previousLevel) {
        if (left)  vDSP_vsmul(left,  1, &level, left,  1, frameCount);
        if (right) vDSP_vsmul(right, 1, &level, right, 1, frameCount);

    // Slower path, we need to calculate envelope from previousLevel -> level and apply
    } else {
        // scratch = linspace(0, 1, frameCount) 
        for (NSInteger i = 0; i < frameCount; i++) {
            scratch[i] = (float)i;
        }

        float a = 1.0 / ((float)frameCount - 1);
        vDSP_vsmul(scratch, 1, &a, scratch, 1, frameCount);

        // scratch *= (level - previousLevel)
        float b = (level - previousLevel);
        vDSP_vsmul(scratch, 1, &b, scratch, 1, frameCount);

        // scratch += previousLevel
        vDSP_vsadd(scratch, 1, &previousLevel, scratch, 1, frameCount);

        if (left)  vDSP_vmul(left,  1, scratch, 1, left,  1, frameCount);
        if (right) vDSP_vmul(right, 1, scratch, 1, right, 1, frameCount);
    }
    
    self->_previousLevel = level;
}


#pragma mark - Accessors

void HugLinearRamperSetMaxFrameCount(HugLinearRamper *self, size_t maxFrameCount)
{
    self->_maxFrameCount = maxFrameCount;

    free(self->_scratch);
    self->_scratch = maxFrameCount ? malloc(sizeof(float) * maxFrameCount) : NULL;
}


size_t HugLinearRamperGetMaxFrameCount(HugLinearRamper *self)
{
    return self->_maxFrameCount;
}
