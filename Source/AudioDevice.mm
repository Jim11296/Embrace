//
//  AudioDevice.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-12.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "AudioDevice.h"
#import "CAHALAudioDevice.h"

static NSString * const sDeviceUIDKey = @"DeviceUID";
static NSString * const sModelUIDKey  = @"ModelUID";

static NSArray      *sAllOutputDevices    = nil;
static NSDictionary *sUIDToDeviceMap      = nil;
static AudioDevice  *sDefaultOutputDevice = nil;


@implementation AudioDevice {
    CAHALAudioDevice *_audioDevice;
    NSArray *_availableNominalSampleRates;
    NSArray *_availableIOBufferSizes;
    BOOL _isDefaultOutputDevice;
}


+ (void) _refreshAudioDevices
{
    if (!sAllOutputDevices) sAllOutputDevices = [NSMutableArray array];
    if (!sUIDToDeviceMap)   sUIDToDeviceMap   = [NSMutableDictionary dictionary];

    NSMutableArray *devices = [NSMutableArray array];
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    AudioDevice *defaultOutputDevice = nil;

    AudioObjectPropertyAddress propertyAddress = { 
        kAudioHardwarePropertyDevices, 
        kAudioObjectPropertyScopeGlobal, 
        kAudioObjectPropertyElementMaster 
    };

    UInt32 dataSize = 0;
   
    if (!CheckError(
        AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize),
        "AudioObjectGetPropertyDataSize"
    )) return;
    
    UInt32 deviceCount = dataSize / sizeof(AudioDeviceID);

    AudioDeviceID *audioDevices = (AudioDeviceID *)malloc(dataSize);

    if (!CheckError(
        AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize, audioDevices),
        "AudioObjectGetPropertyData[kAudioHardwarePropertyDevices]"
    )) {
        free(audioDevices), audioDevices = NULL;
        return;
    }

    propertyAddress.mScope = kAudioDevicePropertyScopeOutput;
    for (UInt32 i = 0; i < deviceCount; ++i) {
        CFStringRef cfDeviceUID = NULL;
        dataSize = sizeof(cfDeviceUID);
        
        propertyAddress.mSelector = kAudioDevicePropertyDeviceUID;
        
        if (!CheckError(
            AudioObjectGetPropertyData(audioDevices[i], &propertyAddress, 0, NULL, &dataSize, &cfDeviceUID),
            "AudioObjectGetPropertyData[kAudioDevicePropertyDeviceUID]"
        )) continue;

        dataSize = 0;
        propertyAddress.mSelector = kAudioDevicePropertyStreams;
        
        if (!CheckError(
            AudioObjectGetPropertyDataSize(audioDevices[i], &propertyAddress, 0, NULL, &dataSize),
            "AudioObjectGetPropertyDataSize[kAudioDevicePropertyStreamConfiguration]"
        )) continue;
        
        NSInteger streamCount = dataSize / sizeof(AudioStreamID);
        if (streamCount < 1) {
            continue;
        }

        NSString *deviceUID = (__bridge NSString *)cfDeviceUID;
        
        AudioDevice *device = [sUIDToDeviceMap objectForKey:deviceUID];

        if (!device) {
            device = [[AudioDevice alloc] _initWithDeviceUID:deviceUID];
        }

        if ([device isDefaultOutputDevice]) {
            defaultOutputDevice = device;
        }
        
        [devices addObject:device];
        [map setObject:device forKey:deviceUID];
    }
    
    sAllOutputDevices = devices;
    sUIDToDeviceMap = map;
    sDefaultOutputDevice = defaultOutputDevice;
}


+ (NSArray *) outputAudioDevices
{
    [self _refreshAudioDevices];
    return sAllOutputDevices;
}


+ (instancetype) audioDeviceWithDeviceUID:(NSString *)UID
{
    [self _refreshAudioDevices];
    return [sUIDToDeviceMap objectForKey:UID];
}


+ (instancetype) defaultOutputDevice
{
    [self _refreshAudioDevices];
    return sDefaultOutputDevice;
}


- (id) _initWithDeviceUID:(NSString *)UID
{
    if ((self = [super init])) {
        _audioDevice = new CAHALAudioDevice((__bridge CFStringRef)UID);
    }
    
    return self;
}


- (NSString *) name
{
    return CFBridgingRelease(_audioDevice->CopyName());
}


- (NSString *) manufacturer
{
    return CFBridgingRelease(_audioDevice->CopyManufacturer());
}


- (AudioObjectID) objectID
{
    return _audioDevice->GetObjectID();
}


- (NSString *) deviceUID
{
    return CFBridgingRelease(_audioDevice->CopyDeviceUID());
}


- (NSString *) modelUID
{
    if (_audioDevice->HasModelUID()){
        return CFBridgingRelease(_audioDevice->CopyModelUID());
    }
    
    return nil;
}


- (NSURL *) iconLocation
{
    return CFBridgingRelease(_audioDevice->CopyIconLocation());
}


- (BOOL) isAlive
{
    return _audioDevice->IsAlive();
}


- (BOOL) isHidden
{
    return _audioDevice->IsHidden();
}


- (BOOL) isHogModeSettable
{
    return _audioDevice->IsHogModeSettable();
}


- (pid_t) hogModeOwner
{
    return _audioDevice->GetHogModeOwner();
}



- (BOOL) isHoggedByMe
{
    return _audioDevice->GetHogModeOwner() == getpid();
}


- (BOOL) takeHogMode
{
    return (BOOL)_audioDevice->TakeHogMode();
}


- (void) releaseHogMode
{
    _audioDevice->ReleaseHogMode();
}


- (void) setNominalSampleRate:(double)rate
{
    _audioDevice->SetNominalSampleRate(rate);
}


- (BOOL) isBuiltIn
{
    return _audioDevice->GetTransportType() == kAudioDeviceTransportTypeBuiltIn;
}


- (BOOL) isDefaultOutputDevice
{
    return [self isBuiltIn];
}


- (double) nominalSampleRate
{
    return _audioDevice->GetNominalSampleRate();
}


- (NSArray *) availableNominalSampleRates
{
    if (!_availableNominalSampleRates) {
        UInt32 count = _audioDevice->GetNumberAvailableNominalSampleRateRanges();
        NSMutableArray *result = [NSMutableArray array];
        
        for (UInt32 i = 0; i < count; i++) {
            Float64 minimum, maximum;

            _audioDevice->GetAvailableNominalSampleRateRangeByIndex(i, minimum, maximum);

            if (minimum <= 44100  && 44100 <= maximum) {
                [result addObject:@44100.0];
            }
            if (minimum <= 48000  && 48000 <= maximum) {
                [result addObject:@48000.0];
            }
            if (minimum <= 88200  && 88200 <= maximum) {
                [result addObject:@88200.0];
            }
            if (minimum <= 96000  && 96000 <= maximum) {
                [result addObject:@96000.0];
            }
            if (minimum <= 176400 && 176400 <= maximum) {
                [result addObject:@176400.0];
            }
            if (minimum <= 192000 && 192000 <= maximum) {
                [result addObject:@192000.0];
            }
        }

        _availableNominalSampleRates = result;
    }
    
    return _availableNominalSampleRates;
}


- (BOOL) isIOBufferSizeSettable
{
    return _audioDevice->IsIOBufferSizeSettable();
}


- (UInt32) IOBufferSize
{
    return _audioDevice->GetIOBufferSize();
}


- (void) setIOBufferSize:(UInt32)size
{
    _audioDevice->SetIOBufferSize(size);
}


- (NSArray *) availableIOBufferSizes
{
    if (!_audioDevice->HasIOBufferSizeRange()) {
        return @[ @( _audioDevice->GetIOBufferSize() ) ];
    }

    if (!_availableIOBufferSizes) {
        NSMutableArray *result = [NSMutableArray array];
        
        UInt32 minimum, maximum;
        _audioDevice->GetIOBufferSizeRange(minimum, maximum);
        
        if (minimum <= 512  && 512 <= maximum) {
            [result addObject:@512];
        }
        if (minimum <= 1024  && 1024 <= maximum) {
            [result addObject:@1024];
        }
        if (minimum <= 2048  && 2048 <= maximum) {
            [result addObject:@2048];
        }
        if (minimum <= 4096  && 4096 <= maximum) {
            [result addObject:@4096];
        }
        if (minimum <= 6144 && 6144 <= maximum) {
            [result addObject:@6144];
        }
        if (minimum <= 8192 && 8192 <= maximum) {
            [result addObject:@8192];
        }

        _availableIOBufferSizes = result;
    }
    
    return _availableIOBufferSizes;
}


- (BOOL) hasIOBufferSizeRange
{
    return _audioDevice->HasIOBufferSizeRange();
}


- (UInt32) minimumIOBufferSize
{
    if (!_audioDevice->HasIOBufferSizeRange()) return 0;

    UInt32 minimum, maximum;
    _audioDevice->GetIOBufferSizeRange(minimum, maximum);
    return minimum;
}


- (UInt32) maximumIOBufferSize
{
    if (!_audioDevice->HasIOBufferSizeRange()) return 0;

    UInt32 minimum, maximum;
    _audioDevice->GetIOBufferSizeRange(minimum, maximum);
    return maximum;
}


@end
