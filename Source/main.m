// (c) 2014-2020 Ricci Adams.  All rights reserved.

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

#warning Future Ricci - if you are reading this, you are trying to build a copy of 3.x from the
#warning public GitHub repository. None of our work on open-sourcing Embrace was ported to 3.x.
#warning Your best bet is to grab the 3.x branch from the internal source server.
#warning Additionally, since we always forget: you should be using Xcode 11.3.1 on the Mojave laptop.

    EmbraceLogSetDirectory(logPath);
    sLogHello();
    
    return NSApplicationMain(argc, (const char **) argv);
}
