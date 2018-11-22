//
//  AudioGraph.m
//  Embrace
//
//  Created by Ricci Adams on 2018-11-21.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "AudioGraph.h"


static BOOL sIsOutputUnitRunning(AudioUnit outputUnit)
{
    if (!outputUnit) return NO;

    Boolean isRunning = false;
    UInt32 size = sizeof(isRunning);
    CheckError(AudioUnitGetProperty( outputUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &isRunning, &size ), "sIsOutputUnitRunning");
    
    return isRunning ? YES : NO;
}


@implementation AudioGraph {
    AudioUnit _outputAudioUnit;
}

@end
