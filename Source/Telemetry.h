// (c) 2017-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

typedef NS_ENUM(NSInteger, TelemetryStringKey) {
    TelemetryStringNoneKey,

    TelemetryStringBundleIdentifierKey,

    TelemetryStringApplicationNameKey,
    TelemetryStringApplicationVersionKey,
    TelemetryStringApplicationBuildKey,

    TelemetryStringDeviceArchitectureKey,

    TelemetryStringOSNameKey,
    TelemetryStringOSVersionKey
};

// Defaults to "~/Library/Application Support/{bundle id}"
extern void TelemetrySetBasePath(NSString *basePath);
extern NSString *TelemetryGetBasePath(void);

extern BOOL TelemetryHasContents(NSString *name);
extern void TelemetryRegisterURL(NSString *name, NSURL *url, NSData *key);
extern void TelemetrySend(NSString *name, BOOL force);
extern void TelemetrySendAll(BOOL force);

extern void TelemetrySendWithCallback(NSString *name, void (^callback)());

extern NSURLRequest *TelemetryMakeURLRequest(NSString *name, NSData *data);

extern NSNumber *TelemetryGetUIDNumber(void);
extern NSString *TelemetryGetString(TelemetryStringKey key);

