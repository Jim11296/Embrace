// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "HugLinearRamper.h"

#import <Accelerate/Accelerate.h>


struct HugLinearRamper {
    UInt32 _frameCount;
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


void HugLinearRamperProcess(HugLinearRamper *self, AudioBufferList *bufferList, float level)
{
    // Build envelope
    
    UInt32 frameCount = self->_frameCount;
    float previousLevel = self->_previousLevel;
    float *scratch = self->_scratch;

    // Determine frame count
    for (NSInteger i = 0; i < bufferList->mNumberBuffers; i++) {
        AudioBuffer *buffer = &bufferList->mBuffers[i];
        UInt32 bufferFrameCount = buffer->mDataByteSize / sizeof(float);
        
        frameCount = MIN(frameCount, bufferFrameCount);
    }

    // Fast path, level is the same as previous
    if (level == previousLevel) {
        for (NSInteger i = 0; i < bufferList->mNumberBuffers; i++) {
            AudioBuffer *buffer = &bufferList->mBuffers[i];
            vDSP_vsmul(buffer->mData, 1, &level, buffer->mData, 1, frameCount);
        }

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
        
        // buffer.mData *= scratch
        for (NSInteger i = 0; i < bufferList->mNumberBuffers; i++) {
            AudioBuffer buffer = bufferList->mBuffers[i];
            vDSP_vmul(buffer.mData, 1, scratch, 1, buffer.mData, 1, frameCount);
        }
    }
    
    self->_previousLevel = level;
}


#pragma mark - Accessors

void HugLinearRamperSetFrameCount(HugLinearRamper *self, UInt32 frameCount)
{
    self->_frameCount = frameCount;

    free(self->_scratch);
    self->_scratch = frameCount ? malloc(sizeof(float) * frameCount) : NULL;
}


UInt32 HugLinearRamperGetFrameCount(HugLinearRamper *self)
{
    return self->_frameCount;
}
