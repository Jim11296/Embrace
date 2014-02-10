

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#import  <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>

typedef struct LoudnessMeasurer LoudnessMeasurer;

LoudnessMeasurer *LoudnessMeasurerCreate(unsigned int channels, double sampleRate, size_t totalFrames);
void LoudnessMeasurerFree(LoudnessMeasurer *measurer);

void LoudnessMeasurerScanAudioBuffer(LoudnessMeasurer *st, AudioBufferList *bufferList, size_t frames);

NSData *LoudnessMeasurerGetOverview(LoudnessMeasurer *st);

double LoudnessMeasurerGetLoudness(LoudnessMeasurer *st);
double LoudnessMeasurerGetPeak(LoudnessMeasurer *st);


#ifdef __cplusplus
}
#endif