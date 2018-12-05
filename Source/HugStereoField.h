// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

typedef struct HugStereoField HugStereoField;

extern HugStereoField *HugStereoFieldCreate(void);
extern void HugStereoFieldFree(HugStereoField *field);

extern void HugStereoFieldSetFrameCount(HugStereoField *field, size_t frameCount);
extern size_t HugStereoFieldGetFrameCount(const HugStereoField *field);

extern void HugStereoFieldReset(HugStereoField *self, float balance, float width);
extern void HugStereoFieldProcess(HugStereoField *self, AudioBufferList *ioData, float balance, float width);
