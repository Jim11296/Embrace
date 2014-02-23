/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "CrashReportSender.h"

#import "BITCrashReportTextFormatter.h"

#import <CrashReporter/CrashReporter.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>


@implementation CrashReportSender {
    NSString *_crashesDir;
}


#pragma mark - Init

- (id) initWithAppIdentifier:(NSString *)appIdentifier
{
    if ((self = [super init])) {
        _appIdentifier = appIdentifier;
        _crashesDir = [self _crashesDirectory];
    }
    
    return self;
}


#pragma mark - Functions

+ (NSString *) installString
{
    NSString *key = @"CrashReportSenderUUID";
    NSString *installString = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    
    if (!installString) {
        installString = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setObject:installString forKey:key];
    }
    
    return installString;
}


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
    NSArray *uuidArray = [BITCrashReportTextFormatter arrayOfAppUUIDsForCrashReport:report];
  
    for (NSDictionary *element in uuidArray) {
        if ([element objectForKey:kBITBinaryImageKeyUUID] && [element objectForKey:kBITBinaryImageKeyArch] && [element objectForKey:kBITBinaryImageKeyUUID]) {
            [uuidString appendFormat:@"<uuid type=\"%@\" arch=\"%@\">%@</uuid>",
                [element objectForKey:kBITBinaryImageKeyType],
                [element objectForKey:kBITBinaryImageKeyArch],
                [element objectForKey:kBITBinaryImageKeyUUID]
            ];
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
        
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"statusCode: %ld, data: %@", statusCode, str);
        
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
 
    NSString *installString = [[self class] installString];
    NSString *deviceModel   = [[self class] deviceModel];
  
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

            NSString *crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:installString];
      
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
    return [[self _crashFiles] count] > 0;
}


@end
