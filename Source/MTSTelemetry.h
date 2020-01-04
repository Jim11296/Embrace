// (c) 2017-2020 musictheory.net, LLC

typedef NS_ENUM(NSInteger, MTSTelemetryStringKey) {
    MTSTelemetryStringNoneKey,

    MTSTelemetryStringArchitectureKey,
    MTSTelemetryStringBundleIdentifierKey,

    MTSTelemetryStringApplicationNameKey,
    MTSTelemetryStringApplicationPathKey,
    MTSTelemetryStringApplicationVersionKey,
    MTSTelemetryStringApplicationBuildKey,

    MTSTelemetryStringHardwareMachineKey, 
    MTSTelemetryStringHardwareModelKey, 

    MTSTelemetryStringOSFamilyKey,
    MTSTelemetryStringOSVersionKey,
    MTSTelemetryStringOSBuildKey
};

// Defaults to "~/Library/Application Support/{bundle id}"
extern void MTSTelemetrySetBasePath(NSString *basePath);
extern NSString *MTSTelemetryGetBasePath(void);

extern BOOL MTSTelemetryHasContents(NSString *name);
extern void MTSTelemetryRegisterURL(NSString *name, NSURL *url);
extern void MTSTelemetrySend(NSString *name, BOOL force);
extern void MTSTelemetrySendAll(BOOL force);

extern void MTSTelemetrySendWithCallback(NSString *name, void (^callback)());

extern NSData   *MTSTelemetryGetUUIDData(void);
extern NSString *MTSTelemetryGetUUIDString(void);
extern NSString *MTSTelemetryGetString(MTSTelemetryStringKey key);

