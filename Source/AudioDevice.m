// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "AudioDevice.h"
#import "WrappedAudioDevice.h"

NSString * const AudioDevicesDidRefreshNotification = @"AudioDevicesDidRefresh";

static NSString * const sDeviceUIDKey     = @"DeviceUID";
static NSString * const sNameKey          = @"Name";
static NSString * const sManufacturerKey  = @"Manufacturer";
static NSString * const sModelUIDKey      = @"ModelUID";
static NSString * const sSampleRatesKey   = @"SampleRates";
static NSString * const sFrameSizesKey    = @"FrameSizes";
static NSString * const sHoggableKey      = @"Hoggable";
static NSString * const sTransportTypeKey = @"TransportType";
static NSString * const sHasVolumeControl = @"HasVolumeControl";


static NSArray      *sAllOutputDevices    = nil;
static NSDictionary *sUIDToDeviceMap      = nil;

static AudioDevice  *sDefaultOutputDevice = nil;
static AudioDevice  *sChosenAudioDevice   = nil;


@interface AudioDevice ()
@property (nonatomic, copy) NSString *deviceUID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *manufacturer;
@property (nonatomic, copy) NSString *modelUID;
@property (nonatomic) NSArray *sampleRates;
@property (nonatomic) NSArray *frameSizes;
@property (nonatomic) UInt32 transportType;
@property (nonatomic, getter=isHoggable)  BOOL hoggable;
@property (nonatomic) BOOL hasVolumeControl;
@property (nonatomic, getter=isConnected) BOOL connected;
@end


static NSDictionary *sGetDictionaryForDeviceUID(NSString *deviceUID)
{
    WrappedAudioDevice *device = [[WrappedAudioDevice alloc] initWithDeviceUID:deviceUID];

    NSString *name             = [device name];
    NSString *manufacturer     = [device manufacturer];
    NSString *modelUID         = [device modelUID];
    NSArray  *frameSizes       = [device availableFrameSizes];
    NSArray  *sampleRates      = [device availableSampleRates];
    BOOL      hoggable         = [device isHogModeSettable];
    BOOL      hasVolumeControl = [device hasVolumeControl];
    UInt32    transportType    = [device transportType];
    
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    if (deviceUID)        [result setObject:deviceUID    forKey:sDeviceUIDKey];
    if (name)             [result setObject:name         forKey:sNameKey];
    if (manufacturer)     [result setObject:manufacturer forKey:sManufacturerKey];
    if (modelUID)         [result setObject:modelUID     forKey:sModelUIDKey];
    if (sampleRates)      [result setObject:sampleRates  forKey:sSampleRatesKey];
    if (frameSizes)       [result setObject:frameSizes   forKey:sFrameSizesKey];
    if (hoggable)         [result setObject:@YES         forKey:sHoggableKey];
    if (hasVolumeControl) [result setObject:@YES         forKey:sHasVolumeControl];
    
    [result setObject:@(transportType) forKey:sTransportTypeKey];

    return result;
}


@implementation AudioDevice

+ (void) selectChosenAudioDevice:(AudioDevice *)device
{
    sChosenAudioDevice = device;
    [self _refreshAudioDevices];
}


+ (void) initialize
{
    AudioObjectPropertyAddress propertyAddress = { 
        kAudioHardwarePropertyDevices, 
        kAudioObjectPropertyScopeGlobal, 
        kAudioObjectPropertyElementMaster 
    };

    AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &propertyAddress, dispatch_get_main_queue(), ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress inAddresses[]) {
        [AudioDevice _refreshAudioDevices];
    });
    
    [AudioDevice _refreshAudioDevices];
}


+ (void) _refreshAudioDevices
{
    static BOOL isRefreshing = NO;
    
    if (isRefreshing) return;
    isRefreshing = YES;

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

        NSString     *deviceUID  = (__bridge NSString *)cfDeviceUID;
        NSDictionary *dictionary = sGetDictionaryForDeviceUID(deviceUID);
        
        AudioDevice *device = [sUIDToDeviceMap objectForKey:deviceUID];

        if (device) {
            [device _fillDictionary:dictionary];
        } else {
            device = [[AudioDevice alloc] _initWithDictionary:dictionary];
        }

        if ([device isDefaultOutputDevice]) {
            defaultOutputDevice = device;
        }

        // Player uses KVO to observe this, don't set it to YES unless it's currently NO
        if (![device isConnected]) {
            [device setConnected:YES];
        }

        if (device) {
            [devices addObject:device];
            [map setObject:device forKey:deviceUID];
        }
    }
    
    NSString *chosenDeviceUID = [sChosenAudioDevice deviceUID];
    if (chosenDeviceUID && ![map objectForKey:chosenDeviceUID]) {
        if (sChosenAudioDevice) {
            [devices addObject:sChosenAudioDevice];
            [map setObject:sChosenAudioDevice forKey:chosenDeviceUID];
            [sChosenAudioDevice setConnected:NO];
        }
    }
    
    sAllOutputDevices = devices;
    sUIDToDeviceMap = map;
    sDefaultOutputDevice = defaultOutputDevice;
    
    free(audioDevices);
    audioDevices = NULL;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AudioDevicesDidRefreshNotification object:self];

    isRefreshing = NO;
}


+ (NSArray *) outputAudioDevices
{
    return sAllOutputDevices;
}


+ (instancetype) defaultOutputDevice
{
    return sDefaultOutputDevice;
}


+ (instancetype) audioDeviceWithDictionary:(NSDictionary *)dictionary
{
    NSString *deviceUID = [dictionary objectForKey:sDeviceUIDKey];
    if (!deviceUID) return nil;
    
    // If we have an existing device, use it
    AudioDevice *device = [sUIDToDeviceMap objectForKey:deviceUID];
        
    // If not, this is the chosen device but it is no longer present
    if (!device) {
        device = [[self alloc] _initWithDictionary:dictionary];
    }
    
    return device;
}


- (id) _initWithDictionary:(NSDictionary *)dictionary
{
    if ((self = [super init])) {
        [self _fillDictionary:dictionary];
    }
    
    return self;
}


- (void) _fillDictionary:(NSDictionary *)dictionary
{
    [self setDeviceUID:         [dictionary objectForKey:sDeviceUIDKey]];
    [self setName:              [dictionary objectForKey:sNameKey]];
    [self setManufacturer:      [dictionary objectForKey:sManufacturerKey]];
    [self setModelUID:          [dictionary objectForKey:sModelUIDKey]];
    [self setSampleRates:       [dictionary objectForKey:sSampleRatesKey]];
    [self setFrameSizes:        [dictionary objectForKey:sFrameSizesKey]];
    [self setHoggable:         [[dictionary objectForKey:sHoggableKey] boolValue]];
    [self setHasVolumeControl: [[dictionary objectForKey:sHasVolumeControl] boolValue]];
    [self setTransportType:    [[dictionary objectForKey:sTransportTypeKey] unsignedIntValue]];
}


- (BOOL) isBuiltIn
{
    return _transportType == kAudioDeviceTransportTypeBuiltIn;
}


- (BOOL) isDefaultOutputDevice
{
    return [self isBuiltIn];
}

- (NSDictionary *) dictionaryRepresentation
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    if (_deviceUID)        [result setObject:_deviceUID    forKey:sDeviceUIDKey];
    if (_name)             [result setObject:_name         forKey:sNameKey];
    if (_manufacturer)     [result setObject:_manufacturer forKey:sManufacturerKey];
    if (_modelUID)         [result setObject:_modelUID     forKey:sModelUIDKey];
    if (_sampleRates)      [result setObject:_sampleRates  forKey:sSampleRatesKey];
    if (_frameSizes)       [result setObject:_frameSizes   forKey:sFrameSizesKey];
    if (_hoggable)         [result setObject:@YES          forKey:sHoggableKey];
    if (_hasVolumeControl) [result setObject:@YES          forKey:sHasVolumeControl];
    
    [result setObject:@(_transportType) forKey:sTransportTypeKey];

    return result;
}


- (WrappedAudioDevice *) controller
{
    if (_connected) {
        return [[WrappedAudioDevice alloc] initWithDeviceUID:_deviceUID];
    }
    
    return nil;
}


@end

