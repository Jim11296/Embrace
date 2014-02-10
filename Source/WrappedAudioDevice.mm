//
//  WrappedAudioDevice.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WrappedAudioDevice.h"
#import "CAHALAudioDevice.h"


@implementation WrappedAudioDevice {
    CAHALAudioDevice *_device;
}


- (id) initWithDeviceUID:(NSString *)deviceUID
{
    if ((self = [super init])) {
        try {
            _device = new CAHALAudioDevice((__bridge CFStringRef)deviceUID);
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
    } catch (...) { }
    
    return transportType;
}


- (NSString *) name
{
    NSString *name = nil;

    try {
        name = CFBridgingRelease(_device->CopyName());
    } catch (...) { }
    
    return name;
}


- (NSString *) manufacturer
{
    NSString *manufacturer = nil;

    try {
        manufacturer = CFBridgingRelease(_device->CopyManufacturer());
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
    } catch (...) { }
    
    return modelUID;
}


- (pid_t) hogModeOwner
{
    pid_t pid = -1;

    try {
        pid = _device->GetHogModeOwner();
    } catch (...) { }

    return pid;
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
    } catch (...) { }
    
    return result;
}


- (BOOL) takeHogMode
{
    BOOL result = NO;

    try {
        if (_device->IsHogModeSettable()) {
            pid_t owner = _device->GetHogModeOwner();
            
            if (owner == getpid()) {
                result = YES;
            } else if (owner == -1) {
                result = (BOOL)_device->TakeHogMode();
            }
        }
    } catch (...) { }
    
    return result;
}


- (void) releaseHogMode
{
    try {
        _device->ReleaseHogMode();
    } catch (...) { }
}


- (void) setNominalSampleRate:(double)rate
{
    try {
        if (_device->IsValidNominalSampleRate(rate)) {
            _device->SetNominalSampleRate(rate);
        }
    } catch (...) { }
}


- (double) nominalSampleRate
{
    double result = 0;

    try {
        result = _device->GetNominalSampleRate();
    } catch (...) { }
    
    return result;
}


- (void) setFrameSize:(UInt32)frameSize
{
    try {
        if (_device->IsIOBufferSizeSettable()) {
            _device->SetIOBufferSize(frameSize);
        }
    } catch (...) { }
}


- (UInt32) frameSize
{
    UInt32 frameSize = 0;
    
    try {
        frameSize = _device->GetIOBufferSize();
    } catch (...) { }
    
    return frameSize;
}


- (NSArray *) availableFrameSizes
{
    NSMutableArray *frameSizes = [NSMutableArray array];

    try {
        if (!_device->HasIOBufferSizeRange()) {
            [frameSizes addObject:@( _device->GetIOBufferSize() )];

        } else {
            UInt32 minimum, maximum;
            _device->GetIOBufferSizeRange(minimum, maximum);
            
            for (NSNumber *n in @[ @512, @1024, @2048, @4096, @6144, @8192 ]) {
                NSInteger i = [n integerValue];

                if (minimum <= i  && i <= maximum) {
                    [frameSizes addObject:n];
                }
            }
        }
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
    } catch (...) { }
    
    return sampleRates;
}


@end