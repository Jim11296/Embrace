// (c) 2018-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>

typedef NSString *HugAudioSettings NS_STRING_ENUM;

// NSNumber, the desired sampling rate.
extern HugAudioSettings const HugAudioSettingSampleRate;

// NSNumber, the desired value of kAudioDevicePropertyBufferFrameSize.
extern HugAudioSettings const HugAudioSettingFrameSize;

// If @YES, Hug attempts to take exclusive access of the device (Hog Mode) upon playback.
extern HugAudioSettings const HugAudioSettingTakeExclusiveAccess;

// If @YES, the device is reset to the maximum volume upon playback.
extern HugAudioSettings const HugAudioSettingResetDeviceVolume;


