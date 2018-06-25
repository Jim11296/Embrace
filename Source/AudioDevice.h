// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@class WrappedAudioDevice;

extern NSString * const AudioDevicesDidRefreshNotification;


@interface AudioDevice : NSObject

+ (NSArray *) outputAudioDevices;
+ (void) selectChosenAudioDevice:(AudioDevice *)device;

+ (instancetype) defaultOutputDevice;
+ (instancetype) audioDeviceWithDictionary:(NSDictionary *)dictionary;

@property (nonatomic, readonly, copy) NSString *deviceUID;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *manufacturer;
@property (nonatomic, readonly, copy) NSString *modelUID;

@property (nonatomic, readonly) NSArray *sampleRates;
@property (nonatomic, readonly) NSArray *frameSizes;

@property (nonatomic, readonly) UInt32 transportType;

@property (nonatomic, readonly, getter=isHoggable)  BOOL hoggable;
@property (nonatomic, readonly, getter=isConnected) BOOL connected;

@property (nonatomic, readonly) BOOL hasVolumeControl;

@property (nonatomic, readonly, getter=isBuiltIn) BOOL builtIn;
@property (nonatomic, readonly, getter=isDefaultOutputDevice) BOOL defaultOutputDevice;

- (WrappedAudioDevice *) controller;

@end
