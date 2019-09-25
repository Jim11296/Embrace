// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

typedef struct HugLevelMeter HugLevelMeter;

extern HugLevelMeter *HugLevelMeterCreate(void);
extern void HugLevelMeterFree(HugLevelMeter *meter);

extern void HugLevelMeterReset(HugLevelMeter *meter);
extern void HugLevelMeterProcess(HugLevelMeter *meter, float *buffer, size_t frameCount);

extern void HugLevelMeterSetSampleRate(HugLevelMeter *meter, double sampleRate);
extern double HugLevelMeterGetSampleRate(const HugLevelMeter *meter);

extern void HugLevelMeterSetMaxFrameCount(HugLevelMeter *meter, size_t maxFrameCount);
extern size_t HugLevelMeterGetMaxFrameCount(const HugLevelMeter *meter);

extern void HugLevelMeterSetAverageEnabled(HugLevelMeter *self, UInt8 averageEnabled);
extern UInt8 HugLevelMeterIsAverageEnabled(const HugLevelMeter *self);

extern float HugLevelMeterGetAverageLevel(const HugLevelMeter *meter);
extern float HugLevelMeterGetPeakLevel(const HugLevelMeter *meter);
extern float HugLevelMeterGetHeldLevel(const HugLevelMeter *meter);
