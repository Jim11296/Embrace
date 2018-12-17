// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "HugAudioDevice.h"
#import "Utils.h"
#import "HugUtils.h"

#import <CoreAudio/CoreAudio.h>


static NSMutableDictionary *sObjectIDToPrehoggedState = nil;


static const AudioObjectPropertyAddress sAddressHogMode = {
    kAudioDevicePropertyHogMode,
    kAudioObjectPropertyScopeGlobal, 0
};


static NSString *sVolumesKey = @"volumes";
static NSString *sMutesKey   = @"mutes";
static NSString *sPansKey    = @"pans";

    
#pragma mark - Helper Functions

static NSString *sGetString(AudioObjectID objectID, AudioObjectPropertySelector selector)
{
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    if (AudioObjectHasProperty(objectID, &address)) {
        CFStringRef data = NULL;
        UInt32 dataSize = sizeof(data);
        
        if (AudioObjectGetPropertyData(objectID, &address, 0, NULL, &dataSize, &data) == noErr) {
            return CFBridgingRelease(data);
        }
    }
    
    return nil;
}


static BOOL sCheck(NSString *opName, OSStatus err)
{
    return HugCheckError(err, @"HugAudioDevice", opName);
}
    
    
static BOOL sIsSettable(AudioObjectID objectID, const AudioObjectPropertyAddress *addressPtr)
{
    Boolean settable = 0;
    
    if (AudioObjectHasProperty(objectID, addressPtr) &&
        AudioObjectIsPropertySettable(objectID, addressPtr, &settable) == noErr) {
        return settable ? YES : NO;
    }
    
    return NO;
}


static void sSaveUInt32(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, UInt32 inValue)
{
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };
    sCheck(opName, AudioObjectSetPropertyData(objectID, &address, 0, NULL, sizeof(inValue), &inValue));
}


static void sSaveDouble(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, double inValue)
{
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };
    sCheck(opName, AudioObjectSetPropertyData(objectID, &address, 0, NULL, sizeof(inValue), &inValue));
}


static void sLoadUInt32(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, UInt32 *outValue)
{
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    UInt32 value = 0;
    UInt32 size  = sizeof(UInt32);

    if (sCheck(opName, AudioObjectGetPropertyData(objectID, &address, 0, NULL, &size, &value))) {
        *outValue = value;
    }
}


static void sLoadDouble(NSString *opName, AudioObjectID objectID, AudioObjectPropertySelector selector, double *outValue)
{
    AudioObjectPropertyAddress address = { selector, kAudioObjectPropertyScopeGlobal, 0 };

    double value = 0;
    UInt32 size  = sizeof(double);

    if (sCheck(opName, AudioObjectGetPropertyData(objectID, &address, 0, NULL, &size, &value))) {
        *outValue = value;
    }
}


#pragma mark - State

#if 0


static void sSetStateDictionaryForDevice(CAHALAudioDevice *device, NSArray *keysToRestore, NSDictionary *dictionary, NSDictionary *defaults)
{

}

#endif



@implementation HugAudioDevice {
    AudioObjectID _objectID;
}

+ (void) releaseHoggedDevices
{
    for (NSNumber *number in sObjectIDToPrehoggedState) {
        UInt32 objectID = [number unsignedIntValue];
        [[HugAudioDevice deviceWithObjectID:objectID] releaseHogMode];
    }

    [sObjectIDToPrehoggedState removeAllObjects];
}


+ (instancetype) deviceWithObjectID:(AudioObjectID)objectID
{
    return [(HugAudioDevice *)[self alloc] initWithObjectID:objectID];
}


+ (instancetype) deviceWithUID:(NSString *)deviceUID
{
    AudioObjectID objectID = kAudioObjectUnknown;

    AudioObjectPropertyAddress address = {
        kAudioHardwarePropertyDeviceForUID,
        kAudioObjectPropertyScopeGlobal, 0
    };

    AudioValueTranslation value = { &deviceUID, sizeof(CFStringRef), &objectID, sizeof(AudioObjectID) };
    UInt32 size = sizeof(AudioValueTranslation);

    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &value) == noErr) {
        return [(HugAudioDevice *)[self alloc] initWithObjectID:objectID];
    }
    
    return nil;
}


- (instancetype) initWithObjectID:(AudioObjectID)objectID
{
    if ((self = [super init])) {
        _objectID = objectID;
    }
    
    return self;
}


#pragma mark - Private Methods

- (UInt32) _channelCount
{
    UInt32 channelCount = 0;

    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyStreamConfiguration,
        kAudioDevicePropertyScopeOutput, 0
    };

    UInt32 size = 0;
    if (!sCheck(@"channelCount", AudioObjectGetPropertyDataSize(_objectID, &address, 0, NULL, &size))) {
        return 0;
    }
    
    AudioBufferList *bufferList = (AudioBufferList *)alloca(size);
    if (!sCheck(@"channelCount", AudioObjectGetPropertyData(_objectID, &address, 0, NULL, &size, bufferList))) {
        return 0;
    }
    
    for (NSInteger i = 0; i < bufferList->mNumberBuffers; i++) {
        channelCount += bufferList->mBuffers[i].mNumberChannels;
    }
    
    return channelCount;
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

    if (didHog) {
        if (state) {
            id key = @( [self objectID] );
            if (!sObjectIDToPrehoggedState) {
                sObjectIDToPrehoggedState = [NSMutableDictionary dictionary];
            }

            if (![sObjectIDToPrehoggedState objectForKey:key]) {
                [sObjectIDToPrehoggedState setObject:state forKey:key];
            }
        }
    }
    
    return didHog;
}


- (void) releaseHogMode
{
    id key = @( [self objectID] );
    NSDictionary *prehoggedState = [sObjectIDToPrehoggedState objectForKey:key];

    if (prehoggedState) {
        [self _restoreState:nil keysToRestore:[prehoggedState allKeys] defaults:@{
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

    if (prehoggedState) {
        [self _restoreState:prehoggedState keysToRestore:[prehoggedState allKeys] defaults:nil];
        [sObjectIDToPrehoggedState removeObjectForKey:key];
    }
}


- (pid_t) hogModeOwner
{
    pid_t  data = -1;
    UInt32 size = sizeof(data);
    
    if (
        sCheck(@"hogModeOwner", AudioObjectHasProperty(    _objectID, &sAddressHogMode)) &&
        sCheck(@"hogModeOwner", AudioObjectGetPropertyData(_objectID, &sAddressHogMode, 0, NULL, &size, &data))
    ) {
        return data;
    } else {
        return -1;
    }
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

- (UInt32) transportType
{
    UInt32 transportType = kAudioDeviceTransportTypeUnknown;
    sLoadUInt32(@"-transportType", _objectID, kAudioDevicePropertyTransportType, &transportType);
    return transportType;
}


- (NSString *) name
{
    return sGetString(_objectID, kAudioObjectPropertyName);
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
    NSMutableArray *frameSizes = [NSMutableArray array];

    AudioObjectPropertyAddress address = { kAudioDevicePropertyBufferFrameSizeRange, kAudioObjectPropertyScopeGlobal, 0 };

    if (AudioObjectHasProperty(_objectID, &address)) {
        AudioValueRange range = { 0, 0 };
        UInt32 size = sizeof(range);
        
        if (sCheck(@"availableFrameSizes", AudioObjectGetPropertyData(_objectID, &address, 0, NULL, &size, &range))) {
            for (NSNumber *n in @[
            #if DEBUG
                @32, @64, @128, @256,
            #endif
                @512, @1024, @2048, @4096, @6144, @8192
            ]) {
                NSInteger i = [n integerValue];

                if (range.mMinimum <= i  && i <= range.mMaximum) {
                    [frameSizes addObject:n];
                }
            }
        }
    
    } else {
        UInt32 frameSize = 0;
        sLoadUInt32(@"availableFrameSizes", _objectID, kAudioDevicePropertyBufferFrameSize, &frameSize);
        if (frameSize) [frameSizes addObject:@(frameSize)];
    }

    return frameSizes;
}


- (NSArray *) availableSampleRates
{
    NSMutableArray *sampleRates = [NSMutableArray array];

    AudioObjectPropertyAddress address = {
        kAudioDevicePropertyAvailableNominalSampleRates,
        kAudioObjectPropertyScopeGlobal, 0
    };

    UInt32 dataSize = 0;
    
    if (!sCheck(@"availableSampleRates", AudioObjectGetPropertyDataSize(_objectID, &address, 0, NULL, &dataSize))) {
        return sampleRates;
    }
    
    AudioValueRange *ranges = (AudioValueRange *)alloca(dataSize);
    
    if (!sCheck(@"availableSampleRates", AudioObjectGetPropertyData(_objectID, &address, 0, NULL, &dataSize, ranges))) {
        return sampleRates;
    }
    
    UInt32 count = dataSize / sizeof(AudioValueRange);
    for (NSInteger i = 0; i < count; i++) {
        AudioValueRange range = ranges[i];
    
        for (NSNumber *n in @[ @44100.0, @48000.0, @88200.0, @96000.0, @176400.0, @192000.0 ]) {
            double d = [n doubleValue];

            if (range.mMinimum <= d  && d <= range.mMaximum) {
                if (![sampleRates containsObject:n]) {
                    [sampleRates addObject:n];
                }
            }
        }
    }
    
    return sampleRates;
}


@end
