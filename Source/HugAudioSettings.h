//
//  HugAudioConfiguration.h
//  Embrace
//
//  Created by Ricci Adams on 2018-12-08.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSString *HugAudioSettings NS_STRING_ENUM;

// NSNumber, the desired sampling rate.
extern HugAudioSettings const HugAudioSettingSampleRate;

// NSNumber, the desired value of kAudioDevicePropertyBufferFrameSize.
extern HugAudioSettings const HugAudioSettingFrameSize;

// If @YES, Hug uses the highest-quality sample rate converters.
extern HugAudioSettings const HugAudioSettingUseHighestQualityRateConverters;

// If @YES, Hug attempts to take exclusive access of the device (Hog Mode) upon playback.
extern HugAudioSettings const HugAudioSettingTakeExclusiveAccess;

// If @YES, the device is reset to the maximum volume upon playback.
extern HugAudioSettings const HugAudioSettingResetDeviceVolume;


