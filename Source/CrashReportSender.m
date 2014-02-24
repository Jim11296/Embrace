//
//  CrashReportSender
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//


#import "CrashReportSender.h"

#import <CrashReporter.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>


@implementation CrashReportSender {
    NSString *_crashesDir;
    BOOL _canHaveCrashReports;
}


#pragma mark - Init

- (id) initWithAppIdentifier:(NSString *)appIdentifier
{
    if ((self = [super init])) {
        _appIdentifier = appIdentifier;
        _crashesDir = [self _crashesDirectory];
        _canHaveCrashReports = [[self _crashFiles] count] > 0;
    }
    
    return self;
}


#pragma mark - Functions

+ (NSString *) deviceModel
{
    NSString *model = nil;
  
    int error = 0;
    size_t length;
    
    error = sysctlbyname("hw.model", NULL, &length, NULL, 0);
    if (error) return nil;

    char *cpuModel = (char *)malloc(sizeof(char) * length);
    error = sysctlbyname("hw.model", cpuModel, &length, NULL, 0);

    if (error == 0) {
        model = [NSString stringWithUTF8String:cpuModel];
    }
            
    free(cpuModel);
  
    return model;
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


#pragma mark - Private Methods

- (NSString *) _crashesDirectory
{
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [paths firstObject];

    NSString *result = [[cacheDir stringByAppendingPathComponent:bundleIdentifier] stringByAppendingPathComponent:@"CrashReportSender"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:result]) {
        NSDictionary *attributes = @{
            NSFilePosixPermissions: @0755
        };
        
        NSError *error = NULL;
        [[NSFileManager defaultManager] createDirectoryAtPath:result withIntermediateDirectories:YES attributes:attributes error:&error];
    }

    return result;
}


- (NSArray *) _crashFiles
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableArray *result = [NSMutableArray array];

    if ([manager fileExistsAtPath:_crashesDir]) {
        NSString *file = nil;
        NSError *error = NULL;
    
        NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath:_crashesDir];
    
        while ((file = [enumerator nextObject])) {
            NSDictionary *fileAttributes = [manager attributesOfItemAtPath:[_crashesDir stringByAppendingPathComponent:file] error:&error];
      
            if ([[fileAttributes objectForKey:NSFileSize] intValue] > 0 &&
                ![file hasSuffix:@".DS_Store"] &&
                ![file hasSuffix:@".analyzer"] &&
                ![file hasSuffix:@".meta"] &&
                ![file hasSuffix:@".plist"])
            {
                [result addObject:[_crashesDir stringByAppendingPathComponent: file]];
            }
        }
    }

    return result;
}


- (void) _cleanCrashReports
{
    NSError *error = NULL;
  
    for (NSString *file in [self _crashFiles]) {
        [[NSFileManager defaultManager] removeItemAtPath:file error:&error];
    }
}


- (NSString *) _extractAppUUIDs:(PLCrashReport *)report
{
    NSMutableString *uuidString = [NSMutableString string];

    NSArray *imageInfos = [[report images] sortedArrayUsingComparator:^(id obj1, id obj2) {
        uint64_t addr1 = [obj1 imageBaseAddress];
        uint64_t addr2 = [obj2 imageBaseAddress];
    
        if (addr1 < addr2) {
            return NSOrderedAscending;
        } else if (addr1 > addr2) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    NSString *(^getArchName)(PLCrashReportBinaryImageInfo *) = ^(PLCrashReportBinaryImageInfo *imageInfo) {
        PLCrashReportProcessorInfo *codeType = [imageInfo codeType];

        if ([codeType typeEncoding] == PLCrashReportProcessorTypeEncodingMach) {
            uint64_t type    = [codeType type];
            uint64_t subtype = [codeType subtype];
        
            if (type == CPU_TYPE_ARM) {
                if (subtype == CPU_SUBTYPE_ARM_V6) {
                    return @"armv6";
                
                } else if (subtype == CPU_SUBTYPE_ARM_V7) {
                    return @"armv7";

                } else if (subtype == CPU_SUBTYPE_ARM_V7S) {
                    return @"armv7s";

                } else {
                    return @"arm-unknown";
                }
                
            } else if (type == (CPU_TYPE_ARM | CPU_ARCH_ABI64)) {
                return @"arm64";
           
            } else if (type == CPU_TYPE_X86) {
                return @"i386";

            } else if (type == CPU_TYPE_X86_64) {
                return @"x86_64";

            } else if (type == CPU_TYPE_POWERPC) {
                return @"powerpc";
            }
        }
        
        return @"???";
    };
    
    for (PLCrashReportBinaryImageInfo *imageInfo in imageInfos) {
        NSString *uuid = [imageInfo hasImageUUID] ? [imageInfo imageUUID] : @"???";
        
        NSString *archName = getArchName(imageInfo);
        
        /* Determine if this is the app executable or app specific framework */
        NSString *imagePath = [[imageInfo imageName] stringByStandardizingPath];
        
        NSString *appBundleContentsPath = [[report processInfo] processPath];
        appBundleContentsPath = [appBundleContentsPath stringByDeletingLastPathComponent];
        appBundleContentsPath = [appBundleContentsPath stringByDeletingLastPathComponent];

        NSString *imageType = @"";
        
        if ([[imageInfo imageName] isEqual:[[report processInfo] processPath]]) {
            imageType = @"app";
        } else {
            imageType = @"framework";
        }
        
        if ([imagePath isEqual: report.processInfo.processPath] || [imagePath hasPrefix:appBundleContentsPath]) {
            if (uuid && archName && imageType) {
                [uuidString appendFormat:@"<uuid type=\"%@\" arch=\"%@\">%@</uuid>", imageType, archName, uuid];
            }
        }
    }
    
    return uuidString;
}


- (void) _postXMLString:(NSString *)xml
{
    NSMutableURLRequest *request = nil;
    NSString *boundary = @"----FOO";
  
    NSString *urlFormat = @"https://sdk.hockeyapp.net/api/2/apps/%@/crashes?sdk=HockeySDK&sdk_version=2.1.0&feedbackEnabled=no";
    NSString *appIdentifier = [_appIdentifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *url = [NSString stringWithFormat:urlFormat, appIdentifier];
  
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
  
    [request setValue:@"HockeySDK" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setTimeoutInterval: 15];
    [request setHTTPMethod:@"POST"];

    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-type"];
  
    NSMutableData *postBody = [NSMutableData data];

    [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    [postBody appendData:[@"Content-Disposition: form-data; name=\"xml\"; filename=\"crash.xml\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithFormat:@"Content-Type: text/xml\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];

    [postBody appendData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    [request setHTTPBody:postBody];
  
    id weakSelf = self;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

        NSInteger statusCode = 200;

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            statusCode = [(NSHTTPURLResponse *)response statusCode];
        }
        
        BOOL shouldClean = NO;
      
        if (statusCode >= 200 && statusCode < 400 && ([data length] > 0)) {
            shouldClean = YES;
        } else if (statusCode == 400) {
            shouldClean = YES;
        }

        if (shouldClean) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf _cleanCrashReports];
            });
        }
    });
}


#pragma mark - Public Methods

- (void) extractPendingReportFromReporter:(PLCrashReporter *)reporter
{
    if (![reporter hasPendingCrashReport]) {
        return;
    }

    NSError *error;

    NSData *data = [reporter loadPendingCrashReportDataAndReturnError:&error];
    NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];

    if (data) {
        [data writeToFile:[_crashesDir stringByAppendingPathComponent:cacheFilename] atomically:YES];
    }
  
    _canHaveCrashReports = YES;
  
    [reporter purgePendingCrashReport];
}


- (void) sendCrashReports
{
    NSError *error = NULL;
		
    NSMutableString *crashes = [NSMutableString string];
    NSArray *crashFiles = [self _crashFiles];
    
    NSString *applicationName    = nil;
    NSString *applicationVersion = nil;
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *localizedInfoDictionary = [mainBundle localizedInfoDictionary];
    NSDictionary *infoDictionary = [mainBundle infoDictionary];
  
    applicationName = [localizedInfoDictionary objectForKey:@"CFBundleExecutable"];
    if (!applicationName) {
        applicationName = [infoDictionary objectForKey:@"CFBundleExecutable"];
    }

    applicationVersion = [localizedInfoDictionary objectForKey:@"CFBundleVersion"];
    if (!applicationVersion) {
        applicationVersion = [infoDictionary objectForKey:@"CFBundleVersion"];
    }

    NSString *installString = [[NSUserDefaults standardUserDefaults] objectForKey:@"CrashReportSenderUUID"];
    
    if (!installString) {
        installString = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setObject:installString forKey:@"CrashReportSenderUUID"];
    }
 
    NSString *deviceModel = [[self class] deviceModel];
  
    for (NSString *crashFile in crashFiles) {
        NSData *crashData = [NSData dataWithContentsOfFile:crashFile];
		
        if ([crashData length] > 0) {
            PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
			
            if (report == nil) {
                [[NSFileManager defaultManager] removeItemAtPath:crashFile error:&error];
                continue;
            }
      
            NSString *crashUUID = @"";
            if (report.uuidRef) {
                crashUUID = (NSString *)CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
            }

            NSString *crashLogString = [PLCrashReportTextFormatter stringValueForCrashReport:report withTextFormat:PLCrashReportTextFormatiOS];

            NSString *crashReporterKey = [NSString stringWithFormat:@"CrashReporter Key:   %@", installString];
            crashLogString = [crashLogString stringByReplacingOccurrencesOfString:@"CrashReporter Key:   TODO" withString:crashReporterKey];

            crashLogString = [crashLogString stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,crashLogString.length)];
      
            [crashes appendFormat:@"<crash><applicationname>%s</applicationname><uuids>%@</uuids><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><senderversion>%@</senderversion><version>%@</version><uuid>%@</uuid><platform>%@</platform><log><![CDATA[%@]]></log><userid></userid><username></username><contact></contact><description></description></crash>",
                [applicationName UTF8String],
                [self _extractAppUUIDs:report],
                report.applicationInfo.applicationIdentifier,
                report.systemInfo.operatingSystemVersion,
                applicationVersion,
                report.applicationInfo.applicationVersion,
                crashUUID,
                deviceModel,
                crashLogString
            ];
        } else {
            // we cannot do anything with this report, so delete it
            [[NSFileManager defaultManager] removeItemAtPath:crashFile error:&error];
        }
    }
	
  
    if ([crashes length]) {
        [self _postXMLString:[NSString stringWithFormat:@"<crashes>%@</crashes>", crashes]];
    }
}


- (BOOL) hasCrashReports
{
    if (!_canHaveCrashReports) return NO;
    return [[self _crashFiles] count] > 0;
}


@end
