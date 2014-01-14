//
//  AudioDevice.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-12.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioDevice : NSObject

+ (NSArray *) outputAudioDevices;

+ (instancetype) defaultOutputDevice;
+ (instancetype) audioDeviceWithDeviceUID:(NSString *)UID;

@property (nonatomic, readonly) AudioObjectID objectID;

@property (nonatomic, readonly, copy) NSString *deviceUID;

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *manufacturer;

@property (nonatomic, readonly, copy) NSString *modelUID;
@property (nonatomic, readonly, copy) NSURL *iconLocation;

@property (nonatomic, readonly, getter=isAlive) BOOL alive;
@property (nonatomic, readonly, getter=isHidden) BOOL hidden;

@property (nonatomic, readonly, getter=isHogModeSettable) BOOL hogModeSettable;
@property (nonatomic, readonly) pid_t hogModeOwner;
@property (nonatomic, readonly) BOOL isHoggedByMe;
- (BOOL) takeHogMode;
- (void) releaseHogMode;

@property (nonatomic, readonly, getter=isBuiltIn) BOOL builtIn;
@property (nonatomic, readonly, getter=isDefaultOutputDevice) BOOL defaultOutputDevice;

@property (nonatomic) double nominalSampleRate;
@property (nonatomic, readonly) NSArray *availableNominalSampleRates;

@property (nonatomic, readonly, getter=isIOBufferSizeSettable) BOOL IOBufferSizeSettable;
@property (nonatomic) UInt32 IOBufferSize;
@property (nonatomic, readonly) NSArray *availableIOBufferSizes;

@property (nonatomic, readonly) BOOL hasIOBufferSizeRange;
@property (nonatomic, readonly) UInt32 minimumIOBufferSize;
@property (nonatomic, readonly) UInt32 maximumIOBufferSize;

@end
