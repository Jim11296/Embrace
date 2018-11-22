// (c) 2012-2018 musictheory.net, LLC


typedef void (*MTSEscapePodSignalCallback)(int signal, siginfo_t *info, ucontext_t *uap);

// Telemetry name must be set prior to MTSEscapePodInstall
extern void MTSEscapePodSetTelemetryName(NSString *telemetryName);
extern NSString *MTSEscapePodGetTelemetryName(void);

extern OSStatus MTSEscapePodInstall(void);

extern void MTSEscapePodSetCustomString(UInt8 zeroToThree, NSString *string);

extern void MTSEscapePodSetSignalCallback(MTSEscapePodSignalCallback callback);
extern MTSEscapePodSignalCallback MTSEscapePodGetSignalCallback(void);

extern void MTSEscapePodSetIgnoredThread(mach_port_t thread);
extern mach_port_t MTSEscapePodGetIgnoredThread(void);

