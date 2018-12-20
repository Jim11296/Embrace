// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "HugAudioDevice.h"
#import "Utils.h"
#import "HugUtils.h"

#import <CoreAudio/CoreAudio.h>


static NSArray        *sConnectedDevices = nil;
static NSMapTable     *sUIDToDeviceMap   = nil;
static HugAudioDevice *sDefaultDevice    = nil;

NSString * const HugAudioDevicesDidRefreshNotification = @"HugAudioDevicesDidRefresh";


static const AudioObjectPropertyAddress sAddressDevices = { 
    kAudioHardwarePropertyDevices, 
    kAudioObjectPropertyScopeGlobal, 0
};

static const AudioObjectPropertyAddress sAddressHogMode = {
    kAudioDevicePropertyHogMode,
    kAudioObjectPropertyScopeGlobal, 0
};

static const AudioObjectPropertyAddress sAddressStreams = {
    kAudioDevicePropertyStreams,
    kAudioObjectPropertyScopeOutput, 0
};


static NSString *sVolumesKey = @"volumes";
static NSString *sMutesKey   = @"mutes";
static NSString *sPansKey    = @"pans";

    
static void *sCopyProperty(AudioObjectID objectID, const AudioObjectPropertyAddress *address, UInt32 *outDataSize)
{
    UInt32 dataSize = 0;
    
    if (AudioObjectGetPropertyDataSize(objectID, address, 0, NULL, &dataSize) != noErr) {
        return NULL;
    }
    
    void *result = malloc(dataSize);
    
    if (AudioObjectGetPropertyData(objectID, address, 0, NULL, &dataSize, result) != noErr) {
        free(result);
        return NULL;
    }

    if (outDataSize) *outDataSize = dataSize;
    
    return result;
}


static NSString *sGetString(AudioObjectID objectID, AudioObjectPropertySelector selector)
{
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    if (objectID && AudioObjectHasProperty(objectID, &address)) {
        CFStringRef data = NULL;
        UInt32 dataSize = sizeof(data);
        
        if (AudioObjectGetPropertyData(objectID, &address, 0, NULL, &dataSize, &data) == noErr) {
            return CFBridgingRelease(data);
        }
    }
    
    return nil;
}


static NSArray<NSNumber *> *sGetAudioRange(AudioObjectID objectID, const AudioObjectPropertySelector selector, NSArray *inValues)
{
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    UInt32 dataSize = 0;
    AudioValueRange *ranges = sCopyProperty(objectID, &address, &dataSize);
    if (!ranges) return nil;

    NSMutableArray *results = [NSMutableArray array];

    UInt32 count = dataSize / sizeof(AudioValueRange);
    for (NSInteger i = 0; i < count; i++) {
        AudioValueRange range = ranges[i];
    
        for (NSNumber *n in inValues) {
            double d = [n doubleValue];

            if (range.mMinimum <= d  && d <= range.mMaximum) {
                if (![results containsObject:n]) {
                    [results addObject:n];
                }
            }
        }
    }
    
    free(ranges);

    return results;
}



static BOOL sCheck(NSString *opName, OSStatus err)
{
    return HugCheckError(err, @"HugAudioDevice", opName);
}
    
    
static BOOL sIsSettable(AudioObjectID objectID, const AudioObjectPropertyAddress *addressPtr)
{
    Boolean settable = 0;
    
    if (objectID &&
        AudioObjectHasProperty(objectID, addressPtr) &&
        AudioObjectIsPropertySettable(objectID, addressPtr, &settable) == noErr
    ) {
        return settable ? YES : NO;
    }
    
    return NO;
}


static void sSaveUInt32(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, UInt32 inValue)
{
    if (!objectID) return;

    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };
    sCheck(opName, AudioObjectSetPropertyData(objectID, &address, 0, NULL, sizeof(inValue), &inValue));
}


static void sSaveDouble(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, double inValue)
{
    if (!objectID) return;

    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };
    sCheck(opName, AudioObjectSetPropertyData(objectID, &address, 0, NULL, sizeof(inValue), &inValue));
}


static void sLoadUInt32(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, UInt32 *outValue)
{
    if (!objectID) return;

    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    UInt32 value = 0;
    UInt32 size  = sizeof(UInt32);

    if (sCheck(opName, AudioObjectGetPropertyData(objectID, &address, 0, NULL, &size, &value))) {
        *outValue = value;
    }
}


static void sLoadDouble(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, double *outValue)
{
    if (!objectID) return;

    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    double value = 0;
    UInt32 size  = sizeof(double);

    if (sCheck(opName, AudioObjectGetPropertyData(objectID, &address, 0, NULL, &size, &value))) {
        *outValue = value;
    }
}


@implementation HugAudioDevice {
    AudioObjectID _objectID;
    NSString *_deviceUID;
    NSString *_name;

    NSDictionary *_prehoggedState;
    UInt32 _transportType;
}


#pragma mark - Static

+ (void) _refreshAudioDevices
{
    static BOOL isRefreshing = NO;
    
    if (isRefreshing) return;
    isRefreshing = YES;

    NSMutableArray *connectedDevices = [NSMutableArray array];

    UInt32 dataSize = 0;
    AudioDeviceID *audioDevices = sCopyProperty(kAudioObjectSystemObject, &sAddressDevices, &dataSize);
    
    if (!audioDevices) {
        HugLog(@"HugAudioDevice", @"Error when querying kAudioObjectSystemObject for devices");
        return;
    }

    UInt32 deviceCount = dataSize / sizeof(AudioDeviceID);
    BOOL foundDefaultDevice = NO;

    for (UInt32 i = 0; i < deviceCount; ++i) {
        AudioObjectID objectID = audioDevices[i];

        NSString *deviceUID = sGetString(objectID, kAudioDevicePropertyDeviceUID);
        if (!deviceUID) continue;

        dataSize = 0;
        
        if (!sCheck(
            @"AudioObjectGetPropertyDataSize[kAudioDevicePropertyStreamConfiguration]",
            AudioObjectGetPropertyDataSize(objectID, &sAddressStreams, 0, NULL, &dataSize)
        )) continue;
        
        NSInteger streamCount = dataSize / sizeof(AudioStreamID);
        if (streamCount < 1) {
            continue;
        }

        UInt32 transportType = kAudioDeviceTransportTypeUnknown;
        sLoadUInt32(@"-transportType", objectID, kAudioDevicePropertyTransportType, &transportType);
        
        HugAudioDevice *device = nil;

        if (!foundDefaultDevice && (transportType == kAudioDeviceTransportTypeBuiltIn)) {
            device = sDefaultDevice;
            foundDefaultDevice = YES;
        } else {
            device = [sUIDToDeviceMap objectForKey:deviceUID];
            if (!device) device = [[HugAudioDevice alloc] init];
        }

        device->_deviceUID = deviceUID;
        [device _updateObjectID:objectID];

        [connectedDevices addObject:device];
        [sUIDToDeviceMap setObject:device forKey:deviceUID];
    }
    
    if (foundDefaultDevice) {
        [sUIDToDeviceMap removeObjectForKey:@""];
    } else {
        [sUIDToDeviceMap setObject:sDefaultDevice forKey:@""];
    }
    
    // Disconnect 
    for (HugAudioDevice *device in [sUIDToDeviceMap objectEnumerator]) {
        if (![connectedDevices containsObject:device]) {
            [device _updateObjectID:0];
        }
    }

    sConnectedDevices = connectedDevices;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:HugAudioDevicesDidRefreshNotification object:self];

    free(audioDevices);
    
    isRefreshing = NO;
}


+ (void) initialize
{
    AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &sAddressDevices, dispatch_get_main_queue(), ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress inAddresses[]) {
        [HugAudioDevice _refreshAudioDevices];
    });

    if (!sUIDToDeviceMap) {
        sUIDToDeviceMap = [NSMapTable strongToWeakObjectsMapTable]; 
    }
    
    if (!sDefaultDevice) {
        sDefaultDevice = [[HugAudioDevice alloc] initWithWithDeviceUID:@"" name:nil];
    }

    [HugAudioDevice _refreshAudioDevices];
}


+ (instancetype) defaultDevice
{
    return sDefaultDevice;
}


+ (NSArray<HugAudioDevice *> *) allDevices
{
    NSArray *allDevices = [[sUIDToDeviceMap objectEnumerator] allObjects];

    return [allDevices sortedArrayUsingComparator:^(id objectA, id objectB) {
        HugAudioDevice *deviceA = (HugAudioDevice *)objectA;
        HugAudioDevice *deviceB = (HugAudioDevice *)objectB;
        
        BOOL isBuiltInA = [deviceA isBuiltIn];
        BOOL isBuiltInB = [deviceB isBuiltIn];
        
        if (isBuiltInA && !isBuiltInB) {
            return NSOrderedAscending;
        } else if (!isBuiltInA && isBuiltInB) {
            return NSOrderedDescending;
        } else {
            return [[deviceA name] caseInsensitiveCompare:[deviceB name]];
        }
    }];
}


#pragma mark - Lifecycle / Overrides

- (instancetype) initWithWithDeviceUID:(NSString *)deviceUID name:(NSString *)name
{
    HugAudioDevice *existing = [sUIDToDeviceMap objectForKey:deviceUID];
    
    if (existing) {
        self = nil;
        return existing;
    }

    if ((self = [super init])) {
        _deviceUID = deviceUID;
        _name = [name copy];

        if (_deviceUID) {
            [sUIDToDeviceMap setObject:self forKey:_deviceUID];
        }
    }
    
    return self;
}


- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: %p '%@'>", NSStringFromClass([self class]), self, [self name]];
}


#pragma mark - Private Methods

- (UInt32) _transportType
{
    if (_transportType == kAudioDeviceTransportTypeUnknown) {
        UInt32 transportType = kAudioDeviceTransportTypeUnknown;
        sLoadUInt32(@"_transportType", _objectID, kAudioDevicePropertyTransportType, &transportType);
        _transportType = transportType;
    }
    
    return _transportType;
}


- (UInt32) _channelCount
{
    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyStreamConfiguration,
        kAudioDevicePropertyScopeOutput, 0
    };

    if (![self isConnected]) {
        return 0;
    }

    UInt32 size = 0;
    AudioBufferList *bufferList = sCopyProperty(_objectID, &address, &size);
    if (!bufferList) return 0;

    UInt32 channelCount = 0;

    for (NSInteger i = 0; i < bufferList->mNumberBuffers; i++) {
        channelCount += bufferList->mBuffers[i].mNumberChannels;
    }
    
    free(bufferList);
    
    return channelCount;
}


- (void) _updateObjectID:(AudioObjectID)objectID
{
    BOOL oldConnected = [self isConnected];
    BOOL newConnected = objectID > 0;

    if (oldConnected != newConnected) {
        [self willChangeValueForKey:@"connected"];
    }

    if (_objectID != objectID) {
        [self willChangeValueForKey:@"objectID"];
        _objectID = objectID;
        [self didChangeValueForKey:@"objectID"];
    }

    if (oldConnected != newConnected) {
        [self didChangeValueForKey:@"connected"];
    }
}


#pragma mark - State Dictionary

- (NSDictionary *) _stateWithKeys:(NSArray<NSString *> *)keys
{
    UInt32 channels = [self _channelCount];
    if (!channels) return nil;

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    for (NSString *key in keys) {
        [dictionary setObject:[NSMutableDictionary dictionary] forKey:key];
    }
    
    NSMutableDictionary *outVolumes = [dictionary objectForKey:sVolumesKey];
    NSMutableDictionary *outMutes   = [dictionary objectForKey:sMutesKey];
    NSMutableDictionary *outPans    = [dictionary objectForKey:sPansKey];
    
    for (UInt32 i = 0; i < (channels + 1); i++) {
        AudioObjectPropertyAddress address = { 0, kAudioObjectPropertyScopeOutput, i };
        
        if (outVolumes) {
            address.mSelector = kAudioDevicePropertyVolumeScalar;

            if (sIsSettable(_objectID, &address)) {
                Float32 value = 0;
                UInt32 size = sizeof(value);
                
                if (AudioObjectGetPropertyData(_objectID, &address, 0, NULL, &size, &value) == noErr) {
                    [outVolumes setObject:@(value) forKey:@(i)];
                }
            }
        }

        if (outMutes) {
            address.mSelector = kAudioDevicePropertyMute;

            if (sIsSettable(_objectID, &address)) {
                UInt32 value = 0;
                UInt32 size = sizeof(value);
                
                if (AudioObjectGetPropertyData(_objectID, &address, 0, NULL, &size, &value) == noErr) {
                    [outMutes setObject:(value > 0 ? @YES : @NO) forKey:@(i)];
                }
            }
        }

        if (outPans) {
            address.mSelector = kAudioDevicePropertyStereoPan;

            if (sIsSettable(_objectID, &address)) {
                Float32 value = 0;
                UInt32 size = sizeof(value);
                
                if (AudioObjectGetPropertyData(_objectID, &address, 0, NULL, &size, &value) == noErr) {
                    [outPans setObject:@(value) forKey:@(i)];
                }
            }
        }
    }

    return dictionary;
}


- (void) _restoreState: (NSDictionary *) state
         keysToRestore: (NSArray<NSString *> *) keysToRestore
              defaults: (NSDictionary *) defaults
{
    UInt32 channels = [self _channelCount];
    if (!channels) return;

    NSDictionary *inVolumes = [state objectForKey:sVolumesKey];
    NSDictionary *inMutes   = [state objectForKey:sMutesKey];
    NSDictionary *inPans    = [state objectForKey:sPansKey];

    for (UInt32 i = 0; i < (channels + 1); i++) {
        AudioObjectPropertyAddress address = { 0, kAudioObjectPropertyScopeOutput, i };

        if ([keysToRestore containsObject:sVolumesKey]) {
            address.mSelector = kAudioDevicePropertyVolumeScalar;

            if (sIsSettable(_objectID, &address)) {
                NSNumber *number = [inVolumes objectForKey:@(i)];
                if (!number) number = [defaults objectForKey:sVolumesKey];
        
                float value = [number floatValue];
                AudioObjectSetPropertyData(_objectID, &address, 0, NULL, sizeof(float), &value);
            }
        }

        if ([keysToRestore containsObject:sMutesKey]) {
            address.mSelector = kAudioDevicePropertyMute;

            if (sIsSettable(_objectID, &address)) {
                NSNumber *number = [inMutes objectForKey:@(i)];
                if (!number) number = [defaults objectForKey:sMutesKey];

                UInt32 value = [number boolValue] ? 1 : 0;
                AudioObjectSetPropertyData(_objectID, &address, 0, NULL, sizeof(UInt32), &value);
            }
        }

        if ([keysToRestore containsObject:sPansKey]) {
            address.mSelector = kAudioDevicePropertyStereoPan;

            if (sIsSettable(_objectID, &address)) {
                NSNumber *number = [inPans objectForKey:@(i)];
                if (!number) number = [defaults objectForKey:sPansKey];

                float value = [number floatValue];
                AudioObjectSetPropertyData(_objectID, &address, 0, NULL, sizeof(float), &value);
            }
        }
    }
}


#pragma mark - Hog Mode
   
- (BOOL) takeHogModeAndResetVolume:(BOOL)resetsVolume
{
    if (![self isConnected]) return NO;

    BOOL didHog = NO;
    NSDictionary *state = nil;

    if ([self isHogModeSettable]) {
        pid_t owner = [self hogModeOwner];

        if (owner == getpid()) {
            didHog = YES;

        } else if (owner == -1) {
            NSArray *keysToFetch = resetsVolume ? @[ sVolumesKey, sMutesKey, sPansKey ] : @[ sMutesKey ];

            state = [self _stateWithKeys:keysToFetch];
            
            pid_t pid = getpid();
            UInt32 size = sizeof(pid_t);

            if (!sCheck(@"takeHogMode - set", AudioObjectSetPropertyData(_objectID, &sAddressHogMode, 0, NULL, size, &pid))) {
                return NO;
            };

            if (!sCheck(@"takeHogMode - get", AudioObjectGetPropertyData(_objectID, &sAddressHogMode, 0, NULL, &size, &pid))) {
                return NO;
            }
            
            didHog = (pid == getpid());
            
            [self _restoreState:nil keysToRestore:keysToFetch defaults:@{
                sVolumesKey: @(1.0),
                sMutesKey:   @NO,
                sPansKey:    @(0.5)
            }];
        }
    }

    if (didHog && state && !_prehoggedState) {
        _prehoggedState = state;
    }
    
    return didHog;
}


- (void) releaseHogMode
{
    if (![self isConnected]) return;

    if (_prehoggedState) {
        [self _restoreState:nil keysToRestore:[_prehoggedState allKeys] defaults:@{
            sVolumesKey: @(0.0),
            sMutesKey:   @YES,
            sPansKey:    @(0.5)
        }];
    }
    
    if ([self isHogModeSettable]) {
        pid_t pid = -1;
        UInt32 size = sizeof(pid_t);

        sCheck(@"releaseHogMode", AudioObjectSetPropertyData(_objectID, &sAddressHogMode, 0, NULL, size, &pid));
    }

    if (_prehoggedState) {
        [self _restoreState:_prehoggedState keysToRestore:[_prehoggedState allKeys] defaults:nil];
        _prehoggedState = nil;
    }
}


- (pid_t) hogModeOwner
{
    if (_objectID && AudioObjectHasProperty(_objectID, &sAddressHogMode)) {
        pid_t  data = -1;
        UInt32 size = sizeof(data);

        if (sCheck(
            @"hogModeOwner",
            AudioObjectGetPropertyData(_objectID, &sAddressHogMode, 0, NULL, &size, &data)
        )) {
            return data;
        }

    }

    return -1;
}


- (BOOL) isHoggedByAnotherProcess
{
    pid_t hogModeOwner = [self hogModeOwner];
    
    if (hogModeOwner < 0) {
        return NO;
    }

    return hogModeOwner != getpid();
}


- (BOOL) isHoggedByMe
{
    return [self hogModeOwner] == getpid();
}


- (BOOL) isHogModeSettable
{
    return sIsSettable(_objectID, &sAddressHogMode);
}


#pragma mark - Accessors

- (NSString *) deviceUID
{
    if (!_deviceUID && _objectID) {
        _deviceUID = sGetString(_objectID, kAudioDevicePropertyDeviceUID);
    }

    return _deviceUID;
}


- (NSString *) name
{
    if (!_name && _objectID) {
        _name = sGetString(_objectID, kAudioObjectPropertyName);
    }

    return _name;
}


- (NSString *) manufacturer
{
    return sGetString(_objectID, kAudioObjectPropertyManufacturer);
}


- (NSString *) modelUID
{
    return sGetString(_objectID, kAudioDevicePropertyModelUID);
}


- (BOOL) hasVolumeControl
{
    NSInteger channels = [self _channelCount];

    if (channels) {
        for (UInt32 i = 0; i < (channels + 1); i++) {
            AudioObjectPropertyAddress address = {
                kAudioDevicePropertyVolumeScalar,
                kAudioObjectPropertyScopeOutput, i
            };

            if (sIsSettable(_objectID, &address)) {
                return YES;
            }
        }
    }

    return NO;
}


#pragma mark - Accessors

- (BOOL) isBuiltIn
{
    return [self _transportType] == kAudioDeviceTransportTypeBuiltIn;
}


- (void) setNominalSampleRate:(double)rate
{
    if ([[self availableSampleRates] containsObject:@(rate)]) {
        sSaveDouble(@"setNominalSampleRate", _objectID, kAudioDevicePropertyNominalSampleRate, rate);
    }   
}


- (double) nominalSampleRate
{
    double result = 0;
    sLoadDouble(@"nominalSampleRate", _objectID, kAudioDevicePropertyNominalSampleRate, &result);
    return result;
}


- (void) setFrameSize:(UInt32)frameSize
{
    AudioObjectPropertyAddress address = { kAudioDevicePropertyBufferFrameSize, kAudioObjectPropertyScopeGlobal, 0 };

    if (sIsSettable(_objectID, &address)) {
        if ([[self availableFrameSizes] containsObject:@(frameSize)]) {
            sSaveUInt32(@"setFrameSize:", _objectID, kAudioDevicePropertyBufferFrameSize, frameSize);
        }
    }
}


- (UInt32) frameSize
{
    UInt32 frameSize = 0;
    sLoadUInt32(@"frameSize", _objectID, kAudioDevicePropertyBufferFrameSize, &frameSize);
    return frameSize;
}


- (NSArray<NSNumber *> *) availableFrameSizes
{
    if (![self isConnected]) return nil;

    NSArray *validFrameSizes = @[
    #if DEBUG
        @32, @64, @128, @256,
    #endif
        @512, @1024, @2048, @4096, @6144, @8192
    ];

    return sGetAudioRange(_objectID, kAudioDevicePropertyBufferFrameSizeRange, validFrameSizes);
}


- (NSArray *) availableSampleRates
{
    if (![self isConnected]) return nil;

    NSArray *validRates = @[ @44100.0, @48000.0, @88200.0, @96000.0, @176400.0, @192000.0 ];
    
    return sGetAudioRange(_objectID, kAudioDevicePropertyAvailableNominalSampleRates, validRates);
}


- (BOOL) isConnected
{
    return _objectID > 0;
}


@end
