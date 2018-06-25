// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "StereoField.h"

void ApplyStereoField(UInt32 inNumberFrames, AudioBufferList *ioData, float previousStereoLevel, float newStereoLevel)
{
    float *left       = (float *)ioData->mBuffers[0].mData;
    float *right      = (float *)ioData->mBuffers[1].mData;

    size_t leftCount  = ioData->mBuffers[0].mDataByteSize / sizeof(float);
    size_t rightCount = ioData->mBuffers[1].mDataByteSize / sizeof(float);

    size_t frameCount = inNumberFrames;
    frameCount = MIN(leftCount,  frameCount);
    frameCount = MIN(rightCount, frameCount);
    
    if (previousStereoLevel == newStereoLevel) {
        const float myWidth    = (newStereoLevel + 1.0f) *  0.5f;
        const float otherWidth = (newStereoLevel - 1.0f) * -0.5f;

        for (NSInteger i = 0; i < frameCount; i++) {
            const float l = left[i];
            const float r = right[i];

            left[i]  = (l * myWidth) + (r * otherWidth);
            right[i] = (r * myWidth) + (l * otherWidth);
        }
    
    } else {
        for (NSInteger i = 0; i < frameCount; i++) {
            float t = (float)i / ((float)frameCount - 1);
            float stereoLevel = (previousStereoLevel * (1.0f - t)) + (newStereoLevel * t);

            float l = left[i];
            float r = right[i];

            const float myWidth    = (stereoLevel + 1.0f) *  0.5f;
            const float otherWidth = (stereoLevel - 1.0f) * -0.5f;

            left[i]  = (l * myWidth) + (r * otherWidth);
            right[i] = (r * myWidth) + (l * otherWidth);
        }
    }
}
