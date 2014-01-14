//
//  main.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AudioDevice.h"

int main(int argc, const char * argv[])
{
    for (AudioDevice *d in [AudioDevice outputAudioDevices]) {
        NSLog(@"%@ %ld-%ld", [d name], (long)[d minimumIOBufferSize], (long)[d maximumIOBufferSize]);
    }

    return NSApplicationMain(argc, argv);
}
