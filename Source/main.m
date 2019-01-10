// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>


static void sLogHello()
{
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *localizedInfoDictionary = [mainBundle localizedInfoDictionary];
    NSDictionary *infoDictionary = [mainBundle infoDictionary];
  
    NSString *buildString = [localizedInfoDictionary objectForKey:@"CFBundleVersion"];
    if (!buildString) buildString = [infoDictionary objectForKey:@"CFBundleVersion"];

    NSString *versionString = [localizedInfoDictionary objectForKey:@"CFBundleShortVersionString"];
    if (!versionString) versionString = [infoDictionary objectForKey:@"CFBundleShortVersionString"];

    EmbraceLog(@"Hello", @"Embrace %@ (%@) launched at %@", versionString, buildString, [NSDate date]);
    EmbraceLog(@"Hello", @"Running on macOS %@", [[NSProcessInfo processInfo] operatingSystemVersionString]);
}


int main(int argc, const char * argv[])
{
    NSString *logPath = GetApplicationSupportDirectory();
    logPath = [logPath stringByAppendingPathComponent:@"Logs"];

    EmbraceLogSetDirectory(logPath);
    sLogHello();
    
    return NSApplicationMain(argc,  (const char **) argv);
}
