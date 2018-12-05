// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

typedef struct HugLevelMeter HugLevelMeter;

extern HugLevelMeter *HugLevelMeterCreate(void);
extern void HugLevelMeterFree(HugLevelMeter *meter);

extern void HugLevelMeterReset(HugLevelMeter *meter);
extern void HugLevelMeterProcess(HugLevelMeter *meter, float *buffer);

extern void HugLevelMeterSetSampleRate(HugLevelMeter *meter, double sampleRate);
extern double  HugLevelMeterGetSampleRate(const HugLevelMeter *meter);

extern void HugLevelMeterSetFrameCount(HugLevelMeter *meter, UInt32 frameCount);
extern UInt32 HugLevelMeterGetFrameCount(const HugLevelMeter *meter);

extern void HugLevelMeterSetAverageEnabled(HugLevelMeter *self, UInt8 averageEnabled);
extern UInt8 HugLevelMeterIsAverageEnabled(const HugLevelMeter *self);

extern float HugLevelMeterGetAverageLevel(const HugLevelMeter *meter);
extern float HugLevelMeterGetPeakLevel(const HugLevelMeter *meter);
extern float HugLevelMeterGetHeldLevel(const HugLevelMeter *meter);
