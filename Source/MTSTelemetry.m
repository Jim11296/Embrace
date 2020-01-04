// (c) 2017-2020 musictheory.net, LLC

#import "MTSTelemetry.h"
#import "MTSBase.h"

#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <sys/sysctl.h>
#import <SystemConfiguration/SystemConfiguration.h>

#if defined(__arm64__)
static const char *sArch = "arm64";
#elif defined(__arm__)
static const char *sArch = "armv7";
#elif defined(__x86_64__)
static const char *sArch = "x86_64";
#elif defined(__i386__)
static const char *sArch = "i386";
#else
#warning MTSEscapePod - Unknown architecture
static const char *sArch = "unknown";
#endif

static const uint8_t s_encoded_0[] = { 232,247,174,237,225,227,232,233,238,229,0 };
static const uint8_t s_encoded_1[] = { 232,247,174,237,239,228,229,236,0         };
static const uint8_t s_encoded_2[] = { 235,229,242,238,174,239,243,246,229,242,243,233,239,238,0 };

#define hw_machine_string     s_encoded_0
#define hw_model_string       s_encoded_1
#define kern_osversion_string s_encoded_2

static void sDecodeString(char *destination, const uint8_t *source)
{
    uint8_t *s = (uint8_t *)source;
    uint8_t *d = (uint8_t *)destination;

    while (1) {
        uint8_t c = *s++;
        if (c == 0) {
            *d++ = 0;
            break;
        } else {
            *d++ = c - 128;
        }
    }
}

static dispatch_queue_t sTelemetryQueue = nil;

static NSMutableDictionary *sURLMap = nil;
static NSMutableDictionary *sSendingFilesMap = nil;
static NSDictionary *sStringMap = nil;

static BOOL sDidInitBasePath = NO;
static NSString *sBasePath = nil;

static void sSetupStringMap()
{
    if (sStringMap) return;

    char  hwmachine[256];
    char  hwmodel[256];
    char  kernosversion[256];
    char  path[256];

    NSMutableDictionary *stringMap = [NSMutableDictionary dictionary];

    CFBundleRef bundle             = CFBundleGetMainBundle();
    CFStringRef bundleName         = CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleNameKey);
    CFStringRef bundleShortVersion = CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("CFBundleShortVersionString"));
    CFStringRef bundleVersion      = CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleVersionKey);
    CFStringRef bundleIdentifier   = CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleIdentifierKey);

    // Get sysctlbyname() strings (hwmachine, hwmodel, and osversion)
    //
    // Note:
    // "{ProductName}{Major},{Minor}" string is "hwmodel" on macOS and "hwmachine" on iOS
    // "{Codename}" is "hwmachine" on iOS 
    //
    {
        const uint8_t *names[3]  = { hw_machine_string, hw_model_string, kern_osversion_string };
        char          *values[3] = { hwmachine,         hwmodel,         kernosversion         };

        for (int i = 0; i < 3; i++) {
            char name[256];
            sDecodeString(name, names[i]);

            size_t length = 256;

            if (sysctlbyname(name, values[i], &length, NULL, 0) != noErr) {
                values[i][0] = 0;
            }
        }
    }

    // Get path
    {
        uint32_t size = sizeof(path);
        if (_NSGetExecutablePath(path, &size) != 0) {
            path[0] = 0;
        }
    }

#if TARGET_OS_IPHONE
    UIDevice *device = [UIDevice currentDevice];
    if (![[device systemVersion] getCString:osversion maxLength:256 encoding:NSUTF8StringEncoding]) {
        osversion[0] = 0;
    }

    [stringMap setObject:@(hwmachine)     forKey:@(MTSTelemetryStringHardwareMachineKey)];
    [stringMap setObject:@(hwmodel)       forKey:@(MTSTelemetryStringHardwareModelKey)];

    [stringMap setObject:@"iOS"           forKey:@(MTSTelemetryStringOSFamilyKey)];
    [stringMap setObject:@(osversion)     forKey:@(MTSTelemetryStringOSVersionKey)];
    [stringMap setObject:@(kernosversion) forKey:@(MTSTelemetryStringOSBuildKey)];
    
#else
    NSOperatingSystemVersion operatingSystemVersion = [[NSProcessInfo processInfo] operatingSystemVersion];

    NSString *osVersion = [NSString stringWithFormat:@"%ld.%ld.%ld",
        (long) operatingSystemVersion.majorVersion,
        (long) operatingSystemVersion.minorVersion,
        (long) operatingSystemVersion.patchVersion];

    [stringMap setObject:@(hwmodel)       forKey:@(MTSTelemetryStringHardwareMachineKey)];

    [stringMap setObject:@"macOS"         forKey:@(MTSTelemetryStringOSFamilyKey)];
    [stringMap setObject:osVersion        forKey:@(MTSTelemetryStringOSVersionKey)];
    [stringMap setObject:@(kernosversion) forKey:@(MTSTelemetryStringOSBuildKey)];

#endif

    [stringMap setObject:@(path) forKey:@(MTSTelemetryStringApplicationPathKey)];

    if (bundleName)         [stringMap setObject:(__bridge id)bundleName         forKey:@(MTSTelemetryStringApplicationNameKey)];
    if (bundleIdentifier)   [stringMap setObject:(__bridge id)bundleIdentifier   forKey:@(MTSTelemetryStringBundleIdentifierKey)];
    if (bundleShortVersion) [stringMap setObject:(__bridge id)bundleShortVersion forKey:@(MTSTelemetryStringApplicationVersionKey)];
    if (bundleVersion)      [stringMap setObject:(__bridge id)bundleVersion      forKey:@(MTSTelemetryStringApplicationBuildKey)];

    if (sArch) [stringMap setObject:@(sArch) forKey:@(MTSTelemetryStringArchitectureKey)];

    sStringMap = stringMap;
}



static void sSendContents(NSString *name, BOOL force, void (^callback)())
{
    BOOL shouldSend = NO;

    NSURL    *URL = [sURLMap objectForKey:name];

    NSString *basePath = [MTSTelemetryGetBasePath() stringByAppendingPathComponent:name];
    NSArray  *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL];

    if ([contents count] > 0) {
        if (force) {
            shouldSend = YES;

        } else {
            const char *hostCString = [[URL host] cStringUsingEncoding:NSUTF8StringEncoding];
            
            if (hostCString) {
                SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, hostCString);
                SCNetworkReachabilityFlags flags = 0;

                if (SCNetworkReachabilityGetFlags(reachability, &flags)) {
                    shouldSend = (flags & (kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsConnectionOnTraffic)) > 0;
                }

                CFRelease(reachability);
            }
        }
    }

    if (shouldSend) {
        if (!sSendingFilesMap) {
            sSendingFilesMap = [NSMutableDictionary dictionary];
        }
        
        NSMutableSet *sendingFilesSet = [sSendingFilesMap objectForKey:name];
        if (!sendingFilesSet) {
            sendingFilesSet = [NSMutableSet set];
            [sSendingFilesMap setObject:sendingFilesSet forKey:name];
        }

        for (NSString *filename in contents) {
            if ([sendingFilesSet containsObject:filename]) {
                return;
            }
            
            [sendingFilesSet addObject:filename];
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];

            NSString *path = [basePath stringByAppendingPathComponent:filename];

            [request setHTTPMethod:@"POST"];
            [request setHTTPBody:[NSData dataWithContentsOfFile:path]];

            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSHTTPURLResponse *httpResponse = nil;

                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    httpResponse = (NSHTTPURLResponse *)response;
                }

                if ([httpResponse statusCode] == 400) {
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                } else if (!error && ([httpResponse statusCode] == 200)) {
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                }
                
                dispatch_async(sTelemetryQueue, ^{
                    BOOL hadFiles = [sendingFilesSet count] > 0;

                    [sendingFilesSet removeObject:filename];

                    if (hadFiles && callback && ([sendingFilesSet count] == 0)) {
                        callback();
                    }
                });
            }];

            [task resume];
        }
    }
}


#pragma mark - Public Functions

void MTSTelemetrySetBasePath(NSString *basePath)
{
    sBasePath = basePath;
    sDidInitBasePath = YES;
}


NSString *MTSTelemetryGetBasePath(void)
{
    if (!sDidInitBasePath) {
        NSArray *appSupportPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        if (![appSupportPaths count]) return nil;

        NSString *appSupportPath = [appSupportPaths firstObject];
        sBasePath = [appSupportPath stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        
        sDidInitBasePath = YES;
    }

    return sBasePath;
}


BOOL MTSTelemetryHasContents(NSString *name)
{
    NSString *basePath = [MTSTelemetryGetBasePath() stringByAppendingPathComponent:name];
    NSArray  *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL];

    return [contents count] > 0;
}


void MTSTelemetryRegisterURL(NSString *name, NSURL *url)
{
    if (!sURLMap) sURLMap = [NSMutableDictionary dictionary];
    [sURLMap setObject:url forKey:name];
}


static void _MTSTelemetrySend(NSString *name, BOOL force, void (^callback)())
{
    if (!sTelemetryQueue) {
        sTelemetryQueue = dispatch_queue_create("MTSTelemetry", DISPATCH_QUEUE_SERIAL);
    }

    dispatch_async(sTelemetryQueue, ^{
        sSendContents(name, force, callback);
    });

}


void MTSTelemetrySend(NSString *name, BOOL force)
{
    _MTSTelemetrySend(name, force, nil);
}


void MTSTelemetrySendAll(BOOL force)
{
    for (NSString *name in sURLMap) {
        _MTSTelemetrySend(name, force, nil);
    }
}

extern void MTSTelemetrySendWithCallback(NSString *name, void (^callback)())
{
    _MTSTelemetrySend(name, YES, callback);
}


NSData *MTSTelemetryGetUUIDData()
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSData *uuidData = [defaults objectForKey:@"IXUUID"];
    if (!uuidData) {
        uuid_t uuidBytes;
        [[NSUUID UUID] getUUIDBytes:uuidBytes];

        uuidData = [[NSData alloc] initWithBytes:uuidBytes length:sizeof(uuidBytes)];
        [defaults setObject:uuidData forKey:@"IXUUID"];
        [defaults synchronize];
    }

    return uuidData;
}


NSString *MTSTelemetryGetUUIDString()
{
    return MTSGetHexStringWithData(MTSTelemetryGetUUIDData());
}


NSString *MTSTelemetryGetString(MTSTelemetryStringKey key)
{
    if (!sStringMap) sSetupStringMap();
    return [sStringMap objectForKey:@(key)];
}

