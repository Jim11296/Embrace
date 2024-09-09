// (c) 2018-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#ifdef __cplusplus
extern "C" {
#endif

#define HugAuto     __auto_type
#define HugWeakAuto __auto_type __weak

extern UInt64 HugGetCurrentHostTime(void);

extern NSTimeInterval HugGetSecondsWithHostTime(UInt64 hostTime);
extern UInt64 HugGetHostTimeWithSeconds(NSTimeInterval seconds);
extern NSTimeInterval HugGetDeltaInSecondsForHostTimes(UInt64 time1, UInt64 time2);

extern AudioBufferList *HugAudioBufferListCreate(UInt32 channelCount, UInt32 frameCount, BOOL allocateData);
extern void HugAudioBufferListFree(AudioBufferList *bufferList, BOOL freeData);

extern NSString *HugGetStringForFourCharCode(OSStatus fcc);

extern void HugSetLogger(void (^)(NSString *category, NSString *message));

extern void HugLog(NSString *category, NSString *format, ...) NS_FORMAT_FUNCTION(2,3);

extern void _HugLogMethod(const char *f);

extern BOOL HugCheckError(OSStatus error, NSString *category, NSString *operation);
extern BOOL HugCheckErrorGroup(void (^block)());



#define HugLogMethod() _HugLogMethod(__PRETTY_FUNCTION__)

#ifdef __cplusplus
}
#endif

