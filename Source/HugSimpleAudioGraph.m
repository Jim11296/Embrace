//
//  HugCallbackHelper.m
//  Embrace
//
//  Created by Ricci Adams on 2018-11-29.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "HugSimpleAudioGraph.h"


@interface HugSimpleAudioGraphNode : NSObject
@property (nonatomic, copy) AURenderPullInputBlock block;
@property (nonatomic) AudioUnit audioUnit;
@property (nonatomic) AUAudioUnit *AUAudioUnit;
@end


@implementation HugSimpleAudioGraphNode
@end


static OSStatus sCallRenderBlock(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData
) {
    AURenderPullInputBlock block = (__bridge AURenderPullInputBlock)inRefCon;
    return block(ioActionFlags, inTimeStamp, inNumberFrames, 0, ioData);
}


@implementation HugSimpleAudioGraph {
    NSMutableArray *_nodes;
    NSMutableArray *_blocks;
}


- (void) _addNode:(HugSimpleAudioGraphNode *)node
{
    if (!_nodes) _nodes = [NSMutableArray array];
    [_nodes addObject:node];
}


- (void) _connect
{
    AURenderPullInputBlock previousFromBlock = nil;

    if (!_blocks) _blocks = [NSMutableArray array];

    for (HugSimpleAudioGraphNode *node in _nodes) {
        AURenderPullInputBlock nodeBlock = [node block];
        AudioUnit nodeAudioUnit = [node audioUnit]; 
        AUAudioUnit *nodeAUAudioUnit = [node AUAudioUnit]; 
        
        // Figure out how to pull audio from this node
        
        AURenderPullInputBlock fromBlock;

        if (nodeBlock) {
            fromBlock = ^(
                AudioUnitRenderActionFlags *actionFlags,
                const AudioTimeStamp *timestamp,
                AUAudioFrameCount frameCount,
                NSInteger inputBusNumber,
                AudioBufferList *inputData
            ) {
                if (previousFromBlock) {
                    AUAudioUnitStatus status = previousFromBlock(actionFlags, timestamp, frameCount, inputBusNumber, inputData);
                    if (status != noErr) return status;
                }

                return nodeBlock(actionFlags, timestamp, frameCount, inputBusNumber, inputData);
            };
            
        } else if (nodeAudioUnit) {
            fromBlock = ^(
                AudioUnitRenderActionFlags *actionFlags,
                const AudioTimeStamp *timestamp,
                AUAudioFrameCount frameCount,
                NSInteger inputBusNumber,
                AudioBufferList *inputData
            ) {
                return AudioUnitRender(nodeAudioUnit, actionFlags, timestamp, 0, frameCount, inputData);
            };

            if (previousFromBlock) {
                AURenderCallbackStruct callbackStruct = { &sCallRenderBlock, (__bridge void *)previousFromBlock };
                UInt32 callbackSize = sizeof(callbackStruct);

                OSStatus err = AudioUnitSetProperty(nodeAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, callbackSize);
                // Check error here
                if (err) NSLog(@"%ld", (long)err);
            }

        } else if (nodeAUAudioUnit) {
            fromBlock = ^(
                AudioUnitRenderActionFlags *actionFlags,
                const AudioTimeStamp *timestamp,
                AUAudioFrameCount frameCount,
                NSInteger inputBusNumber,
                AudioBufferList *inputData
            ) {
                AURenderBlock renderBlock = [nodeAUAudioUnit renderBlock];
                
                return renderBlock(actionFlags, timestamp, frameCount, 0, inputData, previousFromBlock);
            };
        }

        previousFromBlock = [fromBlock copy];
        [_blocks addObject:previousFromBlock];
    }
    
    _masterBlock = [previousFromBlock copy];
}


#pragma mark - Public Methods

- (void) clear
{
    for (HugSimpleAudioGraphNode *node in _nodes) {
        AudioUnit audioUnit = [node audioUnit]; 

        if (audioUnit) {
            OSStatus err = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, NULL, 0);
            if (err) NSLog(@"%ld", (long)err);
        }
    }

    _masterBlock = nil;
    
    [_blocks removeAllObjects];
    _blocks = nil;

    [_nodes removeAllObjects];
    _nodes = nil;
}


- (void) addBlock:(AURenderPullInputBlock)pullBlock
{
    HugSimpleAudioGraphNode *node = [[HugSimpleAudioGraphNode alloc] init];
    [node setBlock:pullBlock];
    [self _addNode:node];
}


- (void) addAudioUnit:(AudioUnit)unit
{
    HugSimpleAudioGraphNode *node = [[HugSimpleAudioGraphNode alloc] init];
    [node setAudioUnit:unit];
    [_nodes addObject:node];
}


- (void) addAUAudioUnit:(AUAudioUnit *)unit
{
    HugSimpleAudioGraphNode *node = [[HugSimpleAudioGraphNode alloc] init];
    [node setAUAudioUnit:unit];
    [_nodes addObject:node];
}


#pragma mark - Accessors

- (AURenderPullInputBlock) masterBlock
{
    if (!_masterBlock) {
        [self _connect];
    }
    
    return _masterBlock;
}


@end



