//
//  HugSimpleGraph.c
//  Embrace
//
//  Created by Ricci Adams on 2018-12-04.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#include "HugSimpleGraph.h"


@implementation HugSimpleGraph {
    AURenderPullInputBlock _renderBlock;
}


- (void) addBlock:(AURenderPullInputBlock)inBlock
{
    AURenderPullInputBlock previousBlock = _renderBlock;
    
    AURenderPullInputBlock newBlock = ^(
        AudioUnitRenderActionFlags *actionFlags,
        const AudioTimeStamp *timestamp,
        AUAudioFrameCount frameCount,
        NSInteger inputBusNumber,
        AudioBufferList *inputData
    ) {
        if (previousBlock) {
            AUAudioUnitStatus status = previousBlock(actionFlags, timestamp, frameCount, inputBusNumber, inputData);
            if (status != noErr) return status;
        }
        
        return inBlock(actionFlags, timestamp, frameCount, inputBusNumber, inputData);
    };
    
    _renderBlock = [newBlock copy];
}


- (void) addAudioUnit:(AUAudioUnit *)unit
{
    AURenderPullInputBlock previousBlock = _renderBlock;

    AURenderBlock unitRenderBlock = [unit renderBlock];

    AURenderPullInputBlock newBlock = [^(
        AudioUnitRenderActionFlags *actionFlags,
        const AudioTimeStamp *timestamp,
        AUAudioFrameCount frameCount,
        NSInteger inputBusNumber,
        AudioBufferList *inputData
    ) {
        return unitRenderBlock(actionFlags, timestamp, frameCount, inputBusNumber, inputData, previousBlock);
    } copy];

    _renderBlock = [newBlock copy];
}


@end
