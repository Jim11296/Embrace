// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>


@interface HugAudioDevice : NSObject

+ (void) releaseHoggedDevices;

+ (instancetype) deviceWithUID:(NSString *)deviceUID;
+ (instancetype) deviceWithObjectID:(AudioObjectID)objectID;

- (instancetype) initWithObjectID:(AudioObjectID)objectID;

- (BOOL) takeHogModeAndResetVolume:(BOOL)resetsVolume;
- (void) releaseHogMode;

@property (nonatomic, readonly) pid_t hogModeOwner;
@property (nonatomic, readonly) BOOL isHoggedByMe;
@property (nonatomic, readonly) BOOL isHoggedByAnotherProcess;
@property (nonatomic, readonly) BOOL isHogModeSettable;

@property (nonatomic, readonly) AudioObjectID objectID;

@property (nonatomic, readonly) UInt32 transportType;

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *manufacturer;
@property (nonatomic, readonly, copy) NSString *modelUID;

@property (nonatomic, readonly) BOOL hasVolumeControl;

@property (nonatomic) double nominalSampleRate;
@property (nonatomic) UInt32 frameSize;

@property (nonatomic, readonly) NSArray<NSNumber *> *availableFrameSizes;
@property (nonatomic, readonly) NSArray<NSNumber *> *availableSampleRates;

@end
