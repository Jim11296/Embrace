// (c) 2017-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "Telemetry.h"

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
#warning EscapePod - Unknown architecture
static const char *sArch = "unknown";
#endif


static dispatch_queue_t sTelemetryQueue = nil;

static NSMutableDictionary *sURLMap = nil;
static NSMutableDictionary *sSendingFilesMap = nil;
static NSDictionary *sStringMap = nil;
static NSMutableDictionary *sKeyMap = nil;

static BOOL sDidInitBasePath = NO;
static NSString *sBasePath = nil;

static void sSetupStringMap()
{
    if (sStringMap) return;

    NSMutableDictionary *stringMap = [NSMutableDictionary dictionary];

    CFBundleRef bundle             = CFBundleGetMainBundle();
    CFStringRef bundleName         = CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleNameKey);
    CFStringRef bundleShortVersion = CFBundleGetValueForInfoDictionaryKey(bundle, CFSTR("CFBundleShortVersionString"));
    CFStringRef bundleVersion      = CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleVersionKey);
    CFStringRef bundleIdentifier   = CFBundleGetValueForInfoDictionaryKey(bundle, kCFBundleIdentifierKey);

    NSOperatingSystemVersion operatingSystemVersion = [[NSProcessInfo processInfo] operatingSystemVersion];

    NSString *osVersion = [NSString stringWithFormat:@"%ld.%ld.%ld",
        (long) operatingSystemVersion.majorVersion,
        (long) operatingSystemVersion.minorVersion,
        (long) operatingSystemVersion.patchVersion];

    [stringMap setObject:@"macOS"  forKey:@(TelemetryStringOSNameKey)];
    [stringMap setObject:osVersion forKey:@(TelemetryStringOSVersionKey)];

    if (bundleName)         [stringMap setObject:(__bridge id)bundleName         forKey:@(TelemetryStringApplicationNameKey)];
    if (bundleIdentifier)   [stringMap setObject:(__bridge id)bundleIdentifier   forKey:@(TelemetryStringBundleIdentifierKey)];
    if (bundleShortVersion) [stringMap setObject:(__bridge id)bundleShortVersion forKey:@(TelemetryStringApplicationVersionKey)];
    if (bundleVersion)      [stringMap setObject:(__bridge id)bundleVersion      forKey:@(TelemetryStringApplicationBuildKey)];

    if (sArch) [stringMap setObject:@(sArch) forKey:@(TelemetryStringDeviceArchitectureKey)];

    sStringMap = stringMap;
}



static void sSendContents(NSString *name, BOOL force, void (^callback)())
{
    BOOL shouldSend = NO;

    NSURL *URL = [sURLMap objectForKey:name];
    if (!URL) return;

    NSString *basePath = [TelemetryGetBasePath() stringByAppendingPathComponent:name];
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
            
            NSString *path = [basePath stringByAppendingPathComponent:filename];
            NSURLRequest *request = TelemetryMakeURLRequest(name, [NSData dataWithContentsOfFile:path]);

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

void TelemetrySetBasePath(NSString *basePath)
{
    sBasePath = basePath;
    sDidInitBasePath = YES;
}


NSString *TelemetryGetBasePath(void)
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


BOOL TelemetryHasContents(NSString *name)
{
    NSString *basePath = [TelemetryGetBasePath() stringByAppendingPathComponent:name];
    NSArray  *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL];

    return [contents count] > 0;
}


void TelemetryRegisterURL(NSString *name, NSURL *url, NSData *key)
{
    if (url) {
        if (!sURLMap) sURLMap = [NSMutableDictionary dictionary];
        [sURLMap setObject:url forKey:name];
    }

    if (key) {
        if (!sKeyMap) sKeyMap = [NSMutableDictionary dictionary];
        [sKeyMap setObject:key forKey:name];
    }
}


static void _TelemetrySend(NSString *name, BOOL force, void (^callback)())
{
    if (!sTelemetryQueue) {
        sTelemetryQueue = dispatch_queue_create("Telemetry", DISPATCH_QUEUE_SERIAL);
    }

    dispatch_async(sTelemetryQueue, ^{
        sSendContents(name, force, callback);
    });

}


void TelemetrySend(NSString *name, BOOL force)
{
    _TelemetrySend(name, force, nil);
}


void TelemetrySendAll(BOOL force)
{
    for (NSString *name in sURLMap) {
        _TelemetrySend(name, force, nil);
    }
}

extern void TelemetrySendWithCallback(NSString *name, void (^callback)())
{
    _TelemetrySend(name, YES, callback);
}


NSURLRequest *TelemetryMakeURLRequest(NSString *name, NSData *data)
{
    NSURL  *URL = [sURLMap objectForKey:name];
    NSData *key = [sKeyMap objectForKey:name];
    
    if (!URL) return nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: URL
                                                           cachePolicy: NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval: 60];

    if (key) {
        NSString *encoded = [key base64EncodedStringWithOptions:0];
        [request setValue:encoded forHTTPHeaderField:@"X-Key"];
    }

    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:data];

    return request;
}


NSNumber *TelemetryGetUIDNumber()
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSNumber *uidNumber = [defaults objectForKey:@"TelemetryUID"];
    if (!uidNumber) {
        uidNumber = @( arc4random() % 0xfffff);
        [defaults setObject:uidNumber forKey:@"TelemetryUID"];
        [defaults synchronize];
    }

    return uidNumber;
}


NSString *TelemetryGetString(TelemetryStringKey key)
{
    if (!sStringMap) sSetupStringMap();
    return [sStringMap objectForKey:@(key)];
}

