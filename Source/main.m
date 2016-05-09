//
//  main.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AudioDevice.h"


int main(int argc, const char * argv[])
{
    NSString *logPath = GetApplicationSupportDirectory();
    logPath = [logPath stringByAppendingPathComponent:@"Logs"];

    EmbraceOpenLogFile(logPath);
    EmbraceLog(@"Hello", @"Embrace launched at %@", [NSDate date]);

    return NSApplicationMain(argc,  (const char **) argv);
}
