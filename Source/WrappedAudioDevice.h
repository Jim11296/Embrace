//
//  WrappedAudioDevice.h
//  Embrace
//
//  Created by Ricci Adams on 2014-02-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WrappedAudioDevice : NSObject

+ (void) releaseHoggedDevices;

- (id) initWithDeviceUID:(NSString *)deviceUID;

@property (nonatomic, readonly) AudioObjectID objectID;

@property (nonatomic, readonly) UInt32 transportType;

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *manufacturer;
@property (nonatomic, readonly, copy) NSString *modelUID;

@property (nonatomic, readonly) pid_t hogModeOwner;
@property (nonatomic, readonly) BOOL isHoggedByMe;
@property (nonatomic, readonly) BOOL isHoggedByAnotherProcess;
@property (nonatomic, readonly) BOOL isHogModeSettable;

- (BOOL) takeHogMode;
- (void) releaseHogMode;

@property (nonatomic) double nominalSampleRate;
@property (nonatomic) UInt32 frameSize;

- (UInt32) preferredAvailableFrameSize;

@property (nonatomic, readonly) NSArray *availableFrameSizes;
@property (nonatomic, readonly) NSArray *availableSampleRates;

@end
