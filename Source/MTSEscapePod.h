// (c) 2012-2018 musictheory.net, LLC


typedef void (*MTSEscapePodSignalCallback)(int signal, siginfo_t *info, ucontext_t *uap);
typedef mach_port_t (*MTSEscapePodIgnoredThreadProvider)(void);

// Telemetry name must be set prior to MTSEscapePodInstall
extern void MTSEscapePodSetTelemetryName(NSString *telemetryName);
extern NSString *MTSEscapePodGetTelemetryName(void);

extern OSStatus MTSEscapePodInstall(void);

extern void MTSEscapePodSetCustomString(UInt8 zeroToThree, NSString *string);

extern void MTSEscapePodSetSignalCallback(MTSEscapePodSignalCallback callback);
extern MTSEscapePodSignalCallback MTSEscapePodGetSignalCallback(void);

extern void MTSEscapePodSetIgnoredThreadProvider(MTSEscapePodIgnoredThreadProvider provider);
extern MTSEscapePodIgnoredThreadProvider MTSEscapePodGetIgnoredThreadProvider(void);

