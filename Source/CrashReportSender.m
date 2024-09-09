// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "CrashReportSender.h"

#import <sys/sysctl.h>
#import <objc/runtime.h>

#import "Telemetry.h"
#import "EscapePod.h"


@implementation CrashReportSender

+ (NSString *) logsTelemetryName
{
    return @"Logs";
}


+ (BOOL) isDebuggerAttached
{
    static BOOL sIsAttached = NO;
    static BOOL sChecked = NO;

    if (sChecked) return sIsAttached;

    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];
  
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
  
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        sIsAttached = NO;
    }
  
    if (!sIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0) {
        sIsAttached = true;
    }

    sChecked = YES;
  
    return sIsAttached;
}


#pragma mark - Public Methods

+ (NSURLRequest *) _urlRequestWithSnapshot:(NSDictionary *)snapshot
{
    NSMutableData *body = [[NSMutableData alloc] init];

    void (^encodeData)(NSData *) = ^(NSData *data) {
        NSUInteger length = [data length];

        if (length > INT32_MAX) {
            UInt32 lengthAsInt = 0;
            [body appendBytes:&lengthAsInt length:sizeof(UInt32)];

        } else {
            UInt32 lengthAsInt = (int)length;
            lengthAsInt = htonl(lengthAsInt);
            [body appendBytes:&lengthAsInt length:sizeof(UInt32)];

            if (data) {
                [body appendData:data];
            }
        }
    };
    
    UInt8 version = 1;
    [body appendBytes:&version length:sizeof(UInt8)];
    
    UInt8 sizeOfInt = sizeof(UInt32);
    [body appendBytes:&sizeOfInt length:sizeof(UInt8)];

    for (id key in snapshot) {
        NSData *keyAsData = [key dataUsingEncoding:NSUTF8StringEncoding];
        id      value     = [snapshot objectForKey:key];

        if ([value isKindOfClass:[NSString class]]) {
            value = [value dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        if ([value isKindOfClass:[NSData class]]) {
            encodeData(keyAsData);
            encodeData(value);
        }
    }

    return TelemetryMakeURLRequest([CrashReportSender logsTelemetryName], body);
}


+ (void) sendCrashReportsWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    NSString *telemetryName = EscapePodGetTelemetryName();
    
    if (TelemetryHasContents(telemetryName)) {
        TelemetrySendWithCallback(telemetryName, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(!TelemetryHasContents(telemetryName));
            });
        });
    }
}


+ (void) sendLogsWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    NSURL   *logURL = [NSURL fileURLWithPath:EmbraceLogGetDirectory()];
    NSError *error  = nil;

    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] init];

    [coordinator coordinateReadingItemAtURL:logURL options:NSFileCoordinatorReadingForUploading error:&error byAccessor:^(NSURL *newURL) {
        NSBundle *bundle            = [NSBundle mainBundle];

        NSString *deviceName        = [[NSHost currentHost] localizedName];

        NSString *osName            = TelemetryGetString(TelemetryStringOSNameKey);
        NSString *osVersion         = TelemetryGetString(TelemetryStringOSVersionKey);

        NSString *bundleName        = [bundle objectForInfoDictionaryKey:(id)kCFBundleNameKey];
        NSString *bundleIdentifier  = [bundle objectForInfoDictionaryKey:(id)kCFBundleIdentifierKey];
        NSString *bundleVersion     = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *bundleBuildNumber = [bundle objectForInfoDictionaryKey:(id)kCFBundleVersionKey];

        NSData *fileData = [NSData dataWithContentsOfURL:newURL];
        if (!fileData) return;

        NSURLRequest *request = [self _urlRequestWithSnapshot:@{
            @"uidn":    TelemetryGetUIDNumber(),
            
            @"fn":      @"Logs.zip",
            @"fd":      fileData,

            @"dn":      deviceName        ?: @"",

            @"dsn":     osName            ?: @"",
            @"dsv":     osVersion         ?: @"",

            @"bn":      bundleName        ?: @"",
            @"bi":      bundleIdentifier  ?: @"",
            @"bv":      bundleVersion     ?: @"",
            @"bbn":     bundleBuildNumber ?: @"",
        }];
    
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *result, NSURLResponse *response, NSError *error2) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSHTTPURLResponse *httpResponse = nil;

                if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                    httpResponse = (NSHTTPURLResponse *)response;
                }

                if ([httpResponse statusCode] != 200) {
                    completionHandler(NO);
                } else {
                    completionHandler(YES);
                }
            });
        }];
    
        [task resume];
    }];
}


@end
