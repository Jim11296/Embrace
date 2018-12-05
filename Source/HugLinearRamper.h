// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

typedef struct HugLinearRamper HugLinearRamper;

extern HugLinearRamper *HugLinearRamperCreate(void);
extern void HugLinearRamperFree(HugLinearRamper *meter);

extern void HugLinearRamperSetFrameCount(HugLinearRamper *ramper, UInt32 frameCount);
extern UInt32 HugLinearRamperGetFrameCount(HugLinearRamper *ramper);

extern void HugLinearRamperReset(HugLinearRamper *ramper, float level);
extern void HugLinearRamperProcess(HugLinearRamper *ramper, AudioBufferList *bufferList, float level);
