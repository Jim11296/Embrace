// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "WrappedAudioDevice.h"
#import "CAHALAudioDevice.h"
#import "CAHALAudioSystemObject.h"
#import "Utils.h"


static NSMutableDictionary *sObjectIDToPrehoggedState = nil;

static NSString *sVolumesKey = @"volumes";
static NSString *sMutesKey   = @"mutes";
static NSString *sPansKey    = @"pans";


static NSDictionary *sGetStateDictionaryForDevice(CAHALAudioDevice *device, NSArray *keysToFetch)
{
    UInt32 channels = 0;
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for (NSString *key in keysToFetch) {
        [dictionary setObject:[NSMutableDictionary dictionary] forKey:key];
    }
    
    NSMutableDictionary *outVolumes = [dictionary objectForKey:sVolumesKey];
    NSMutableDictionary *outMutes   = [dictionary objectForKey:sMutesKey];
    NSMutableDictionary *outPans    = [dictionary objectForKey:sPansKey];
    
    try {
        channels = device->GetTotalNumberChannels(false);
    } catch (...) { }

    if (!channels) return nil;

    for (UInt32 i = 0; i < (channels + 1); i++) {
        if (outVolumes) {
            try {
                if (device->HasVolumeControl(kAudioDevicePropertyScopeOutput, i) &&
                    device->VolumeControlIsSettable(kAudioDevicePropertyScopeOutput, i))
                {
                    Float32 outVolume = device->GetVolumeControlScalarValue(kAudioDevicePropertyScopeOutput, i);
                    [outVolumes setObject:@(outVolume) forKey:@(i)];
                }
            } catch (...) { }
        }

        if (outMutes) {
            try {
                if (device->HasMuteControl(kAudioDevicePropertyScopeOutput, i) &&
                    device->MuteControlIsSettable(kAudioDevicePropertyScopeOutput, i))
                {
                    bool outMute = device->GetMuteControlValue(kAudioDevicePropertyScopeOutput, i);
                    [outMutes setObject:@(outMute) forKey:@(i)];
                }
            } catch (...) { }
        }

        if (outPans) {
            try {
                if (device->HasStereoPanControl(kAudioDevicePropertyScopeOutput, i) &&
                    device->StereoPanControlIsSettable(kAudioDevicePropertyScopeOutput, i))
                {
                    Float32 outPan = device->GetMuteControlValue(kAudioDevicePropertyScopeOutput, i);
                    [outPans setObject:@(outPan) forKey:@(i)];
                }
            } catch (...) { }
        }
    }
    
    return dictionary;
}


static void sSetStateDictionaryForDevice(CAHALAudioDevice *device, NSArray *keysToRestore, NSDictionary *dictionary, NSDictionary *defaults)
{
    UInt32 channels = 0;
    
    try {
        channels = device->GetTotalNumberChannels(false);
    } catch (...) { }

    if (!channels) return;

    for (UInt32 i = 0; i < (channels + 1); i++) {
        if ([keysToRestore containsObject:sVolumesKey]) {
            NSDictionary *inVolumes = [dictionary objectForKey:sVolumesKey];

            try {
                if (device->HasVolumeControl(kAudioDevicePropertyScopeOutput, i) &&
                    device->VolumeControlIsSettable(kAudioDevicePropertyScopeOutput, i))
                {
                    NSNumber *number = [inVolumes objectForKey:@(i)];
                    if (!number) number = [defaults objectForKey:sVolumesKey];
                    
                    device->SetVolumeControlScalarValue(kAudioDevicePropertyScopeOutput, i, [number floatValue]);
                }
            } catch (...) { }
        }

        if ([keysToRestore containsObject:sMutesKey]) {
            NSDictionary *inMutes = [dictionary objectForKey:sMutesKey];

            try {
                if (device->HasMuteControl(kAudioDevicePropertyScopeOutput, i) &&
                    device->MuteControlIsSettable(kAudioDevicePropertyScopeOutput, i))
                {
                    NSNumber *number = [inMutes objectForKey:@(i)];
                    if (!number) number = [defaults objectForKey:sMutesKey];
                    
                    device->SetMuteControlValue(kAudioDevicePropertyScopeOutput, i, [number boolValue]);
                }
            } catch (...) { }
        }

        if ([keysToRestore containsObject:sPansKey]) {
            NSDictionary *inPans = [dictionary objectForKey:sPansKey];

            try {
                if (device->HasStereoPanControl(kAudioDevicePropertyScopeOutput, i) &&
                    device->StereoPanControlIsSettable(kAudioDevicePropertyScopeOutput, i))
                {
                    NSNumber *number = [inPans objectForKey:@(i)];
                    if (!number) number = [defaults objectForKey:sPansKey];

                    device->SetStereoPanControlValue(kAudioDevicePropertyScopeOutput, i, [number floatValue]);
                }
            } catch (...) { }
        }
    }
}


static void sReleaseHogMode(CAHALAudioDevice *device, NSDictionary *prehoggedState)
{
    try {
        if (prehoggedState) {
            sSetStateDictionaryForDevice(device, [prehoggedState allKeys], nil, @{
                sVolumesKey: @(0.0),
                sMutesKey:   @YES,
                sPansKey:    @(0.5)
            });
        }
        
        device->ReleaseHogMode();
        
        if (prehoggedState) {
            sSetStateDictionaryForDevice(device, [prehoggedState allKeys], prehoggedState, nil);
        }
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
}


@implementation WrappedAudioDevice {
    CAHALAudioDevice *_device;
}

+ (void) releaseHoggedDevices
{
    for (NSNumber *number in sObjectIDToPrehoggedState) {
        UInt32 objectID = [number unsignedIntValue];

        NSDictionary *prehoggedState = [sObjectIDToPrehoggedState objectForKey:@(objectID)];
        CAHALAudioDevice device = CAHALAudioDevice(objectID);

        sReleaseHogMode(&device, prehoggedState);
    }

    [sObjectIDToPrehoggedState removeAllObjects];
}


- (id) initWithDeviceUID:(NSString *)deviceUID
{
    if ((self = [super init])) {
        try {
            _device = new CAHALAudioDevice((__bridge CFStringRef)deviceUID);
        } catch (CAException e) {
            EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
        } catch (...) {
            _device = NULL;
        }

        if (!_device) {
            self = nil;
            return nil;
        }
    }

    return self;
}


- (void) dealloc
{
    if (_device) {
        delete _device;
        _device = NULL;
    }
}


- (AudioObjectID) objectID
{
    return _device->GetObjectID();
}


- (UInt32) transportType
{
    UInt32 transportType = kAudioDeviceTransportTypeUnknown;
    
    try {
        transportType = _device->GetTransportType();
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
    
    return transportType;
}


- (NSString *) name
{
    NSString *name = nil;

    try {
        name = CFBridgingRelease(_device->CopyName());
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
    
    return name;
}


- (NSString *) manufacturer
{
    NSString *manufacturer = nil;

    try {
        manufacturer = CFBridgingRelease(_device->CopyManufacturer());
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
    
    return manufacturer;
}


- (NSString *) modelUID
{
    NSString *modelUID = nil;

    try {
        if (_device->HasModelUID()){
            modelUID = CFBridgingRelease(_device->CopyModelUID());
        }
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
    
    return modelUID;
}


- (pid_t) hogModeOwner
{
    pid_t pid = -1;

    try {
        pid = _device->GetHogModeOwner();
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }

    return pid;
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
    return _device->GetHogModeOwner() == getpid();
}


- (BOOL) isHogModeSettable
{
    BOOL result = NO;

    try {
        result = (BOOL)_device->IsHogModeSettable();
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
    
    return result;
}


- (BOOL) hasVolumeControl
{
    UInt32 channels = 0;

    try {
        channels = _device->GetTotalNumberChannels(false);
    } catch (...) { }

    if (channels) {
        for (UInt32 i = 0; i < (channels + 1); i++) {
            try {
                if (_device->HasVolumeControl(kAudioDevicePropertyScopeOutput, i) &&
                    _device->VolumeControlIsSettable(kAudioDevicePropertyScopeOutput, i))
                {
                    return YES;
                }
            } catch (...) { }
        }
    }

    return NO;
}


- (BOOL) takeHogModeAndResetVolume:(BOOL)resetsVolume
{
    BOOL didHog = NO;
    NSDictionary *state = nil;

    try {
        if (_device->IsHogModeSettable()) {
            pid_t owner = _device->GetHogModeOwner();
            
            if (owner == getpid()) {
                didHog = YES;
            } else if (owner == -1) {
                NSArray *keysToFetch = resetsVolume ? @[ sVolumesKey, sMutesKey, sPansKey ] : @[ sMutesKey ];

                CAHALAudioSystemObject systemObject = CAHALAudioSystemObject();
                
                state = sGetStateDictionaryForDevice(_device, keysToFetch);
                didHog = (BOOL)_device->TakeHogMode();

                sSetStateDictionaryForDevice(_device, keysToFetch, nil, @{
                    sVolumesKey: @(1.0),
                    sMutesKey:   @NO,
                    sPansKey:    @(0.5)
                });
            }
        }
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
    
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

    sReleaseHogMode(_device, prehoggedState);

    if (prehoggedState) {
        [sObjectIDToPrehoggedState removeObjectForKey:key];
    }
}


- (void) setNominalSampleRate:(double)rate
{
    try {
        if (_device->IsValidNominalSampleRate(rate)) {
            _device->SetNominalSampleRate(rate);
        }
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
}


- (double) nominalSampleRate
{
    double result = 0;

    try {
        result = _device->GetNominalSampleRate();
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
    
    return result;
}


- (void) setFrameSize:(UInt32)frameSize
{
    try {
        if (_device->IsIOBufferSizeSettable()) {
            _device->SetIOBufferSize(frameSize);
        }
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
}


- (UInt32) frameSize
{
    UInt32 frameSize = 0;
    
    try {
        frameSize = _device->GetIOBufferSize();
    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    } catch (...) { }
    
    return frameSize;
}


- (NSArray *) availableFrameSizes
{
    NSMutableArray *frameSizes = [NSMutableArray array];

    NSArray *allFrameSizes = @[
#if DEBUG
        @32, @64, @128, @256,
#endif
        @512, @1024, @2048, @4096, @6144, @8192
    ];

    try {
        if (!_device->HasIOBufferSizeRange()) {
            [frameSizes addObject:@( _device->GetIOBufferSize() )];

        } else {
            UInt32 minimum, maximum;
            _device->GetIOBufferSizeRange(minimum, maximum);
            
            for (NSNumber *n in allFrameSizes) {
                NSInteger i = [n integerValue];

                if (minimum <= i  && i <= maximum) {
                    [frameSizes addObject:n];
                }
            }
        }

    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));

    } catch (...) { }
    
    return frameSizes;
}


- (NSArray *) availableSampleRates
{
    NSMutableArray *sampleRates = [NSMutableArray array];

    try {
        UInt32 count = _device->GetNumberAvailableNominalSampleRateRanges();
    
        for (UInt32 i = 0; i < count; i++) {
            Float64 minimum, maximum;
            _device->GetAvailableNominalSampleRateRangeByIndex(i, minimum, maximum);

            for (NSNumber *n in @[ @44100.0, @48000.0, @88200.0, @96000.0, @176400.0, @192000.0 ]) {
                double d = [n doubleValue];

                if (minimum <= d  && d <= maximum) {
                    if (![sampleRates containsObject:n]) {
                        [sampleRates addObject:n];
                    }
                }
            }
        }

    } catch (CAException e) {
        EmbraceLog(@"CAException", @"%s failed: %ld", __PRETTY_FUNCTION__, (long)GetStringForFourCharCode(e.GetError()));
    
    } catch (...) { }
    
    return sampleRates;
}


@end
