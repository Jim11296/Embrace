// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>

extern NSString * const HugAudioDevicesDidRefreshNotification;


@interface HugAudioDevice : NSObject

+ (instancetype) placeholderDevice;
+ (instancetype) archivedDeviceWithDeviceUID:(NSString *)deviceUID name:(NSString *)name;
+ (instancetype) bestDefaultDevice;


+ (NSArray<HugAudioDevice *> *) allDevices; 

- (instancetype) initWithDeviceUID:(NSString *)deviceUID name:(NSString *)name;

@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, readonly) AudioObjectID objectID;

@property (nonatomic, readonly, copy) NSString *deviceUID;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *manufacturer;
@property (nonatomic, readonly, copy) NSString *modelUID;

- (BOOL) takeHogModeAndResetVolume:(BOOL)resetsVolume;
- (void) releaseHogMode;

@property (nonatomic, readonly) pid_t hogModeOwner;
@property (nonatomic, readonly) BOOL isHoggedByMe;
@property (nonatomic, readonly) BOOL isHoggedByAnotherProcess;
@property (nonatomic, readonly) BOOL isHogModeSettable;

@property (nonatomic) double nominalSampleRate;
@property (nonatomic) UInt32 frameSize;

@property (nonatomic, readonly) BOOL hasVolumeControl;
@property (nonatomic, readonly, getter=isBuiltIn) BOOL builtIn;

@property (nonatomic, readonly) NSArray<NSNumber *> *availableFrameSizes;
@property (nonatomic, readonly) NSArray<NSNumber *> *availableSampleRates;

@end
