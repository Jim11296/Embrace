// (c) 2018-2019 Ricci Adams.  All rights reserved.

#include "HugSimpleGraph.h"


@implementation HugSimpleGraph {
    AURenderPullInputBlock _renderBlock;
    NSInteger _errorIndex;
}

- (instancetype) initWithErrorBlock:(HugSimpleGraphErrorBlock)errorBlock
{
    if ((self = [super init])) {
        _errorBlock = errorBlock;
    }

    return self;
}


- (void) addBlock:(AURenderPullInputBlock)inBlock
{
    HugSimpleGraphErrorBlock errorBlock = _errorBlock;
    __block NSInteger errorIndex = _errorIndex++;

    AURenderPullInputBlock previousBlock = _renderBlock;
    
    _renderBlock = [^(
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
        
        OSStatus err = inBlock(actionFlags, timestamp, frameCount, inputBusNumber, inputData);
        if (err) errorBlock(err, errorIndex);

        return err;
    } copy];
}


- (void) addAudioUnit:(AUAudioUnit *)unit
{
    HugSimpleGraphErrorBlock errorBlock = _errorBlock;
    __block NSInteger errorIndex = _errorIndex++;

    AURenderPullInputBlock previousBlock = _renderBlock;

    AURenderBlock unitRenderBlock = [unit renderBlock];

    _renderBlock = [^(
        AudioUnitRenderActionFlags *actionFlags,
        const AudioTimeStamp *timestamp,
        AUAudioFrameCount frameCount,
        NSInteger inputBusNumber,
        AudioBufferList *inputData
    ) {
        OSStatus err = unitRenderBlock(actionFlags, timestamp, frameCount, inputBusNumber, inputData, previousBlock);
        if (err) errorBlock(err, errorIndex);

        return err;
    } copy];
}


@end
