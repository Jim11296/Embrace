//
//  main.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AudioDevice.h"

#if APP_STORE
#include "ReceiptValidation.h"
#endif

int main(int argc, const char * argv[])
{
#if APP_STORE
    CheckReceiptAndRun(argc, argv);
#else
    EmbraceOpenLogFile();
    EmbraceLog(@"Hello", @"Embrace launched at %@", [NSDate date]);
    return NSApplicationMain(argc,  (const char **) argv);
#endif
}
