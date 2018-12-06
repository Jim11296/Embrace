// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "HugStereoField.h"

#import <Accelerate/Accelerate.h>


struct HugStereoField {
    size_t _maxFrameCount;
    float  _previousBalance;
    float  _previousWidth;
};


#pragma mark - Public Functions

HugStereoField *HugStereoFieldCreate()
{
    HugStereoField *self = calloc(1, sizeof(HugStereoField));
    return self;
}


void HugStereoFieldFree(HugStereoField *self)
{
    free(self);
}


void HugStereoFieldReset(HugStereoField *self, float balance, float width)
{
    self->_previousBalance = balance;
    self->_previousWidth = width;
}


void HugStereoFieldProcess(HugStereoField *self, float *left, float *right, size_t frameCount, float balance, float width)
{
    if (!left || !right) return;

    float previousWidth = self->_previousWidth;

    if (balance < -1.0f) balance = -1.0f;
    if (balance >  1.0f) balance =  1.0f;

    if (width   < -1.0f) width   = -1.0f;
    if (width   >  1.0f) width   =  1.0f;

    if (previousWidth != 1.0 || width != 1.0) {
        if (previousWidth == width) {
            const float myWidth    = (width + 1.0f) *  0.5f;
            const float otherWidth = (width - 1.0f) * -0.5f;

            for (size_t i = 0; i < frameCount; i++) {
                const float l = left[i];
                const float r = right[i];

                left[i]  = (l * myWidth) + (r * otherWidth);
                right[i] = (r * myWidth) + (l * otherWidth);
            }
        
        } else {
            for (size_t i = 0; i < frameCount; i++) {
                float t = (float)i / ((float)frameCount - 1);
                float stereoLevel = (previousWidth * (1.0f - t)) + (width * t);

                float l = left[i];
                float r = right[i];

                const float myWidth    = (stereoLevel + 1.0f) *  0.5f;
                const float otherWidth = (stereoLevel - 1.0f) * -0.5f;

                left[i]  = (l * myWidth) + (r * otherWidth);
                right[i] = (r * myWidth) + (l * otherWidth);
            }
        }
    }

    float previousBalance = self->_previousBalance;

    if (previousBalance != 0.0 || balance != 0.0) {
        if (previousBalance == balance) {
            float m;
            
            m = pow(1.0 - balance, 3);
            if (m < 1.0) vDSP_vsmul(left, 1, &m, left, 1, frameCount);

            m = pow(1.0 + balance, 3);
            if (m < 1.0) vDSP_vsmul(right, 1, &m, right, 1, frameCount);
 
        } else {
            for (size_t i = 0; i < frameCount; i++) {
                float t = (float)i / ((float)frameCount - 1);
                float b = (previousBalance * (1.0f - t)) + (balance * t);
                float m;
                
                m = pow(1.0 - b, 3);
                if (m < 1.0) left[i] *= m;

                m = pow(1.0 + b, 3);
                if (m < 1.0) right[i] *= m;
            }
        }
    }
    
    self->_previousWidth   = width;
    self->_previousBalance = balance;
}


void HugStereoFieldSetMaxFrameCount(HugStereoField *self, size_t maxFrameCount)
{
    self->_maxFrameCount = maxFrameCount;
}


size_t HugStereoFieldGetMaxFrameCount(const HugStereoField *self)
{
    return self->_maxFrameCount;
}

