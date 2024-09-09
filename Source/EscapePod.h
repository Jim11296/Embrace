// (c) 2012-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

typedef void (*EscapePodSignalCallback)(int signal, siginfo_t *info, ucontext_t *uap);
typedef mach_port_t (*EscapePodIgnoredThreadProvider)(void);

// Telemetry name must be set prior to EscapePodInstall
extern void EscapePodSetTelemetryName(NSString *telemetryName);
extern NSString *EscapePodGetTelemetryName(void);

extern OSStatus EscapePodInstall(void);

extern void EscapePodSetCustomString(UInt8 zeroToThree, NSString *string);

extern void EscapePodSetSignalCallback(EscapePodSignalCallback callback);
extern EscapePodSignalCallback EscapePodGetSignalCallback(void);

extern void EscapePodSetIgnoredThreadProvider(EscapePodIgnoredThreadProvider provider);
extern EscapePodIgnoredThreadProvider EscapePodGetIgnoredThreadProvider(void);

