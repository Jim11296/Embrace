// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "HugFastUtils.h"


void HugApplySilence(float *samples, size_t frameCount)
{
    if (!samples) return;

    for (NSInteger i = 0; i < frameCount; i++) {
        samples[i] = 0;
    }
}


void HugApplyFade(float *samples, size_t frameCount, float inFromValue, float inToValue)
{
    if (!samples) return;

    const double sSilence = pow(10.0, -120.0 / 20.0); // Silence is -120dB

    double fromValue = inFromValue ? inFromValue : sSilence;
    double toValue   = inToValue   ? inToValue   : sSilence;
    
    double multiplier = pow(toValue / fromValue, 1 / (double)frameCount);
    double env = fromValue;

    for (NSInteger i = 0; i < frameCount; i++) {
        samples[i] *= env;
        env *= multiplier;
    }
}
