//
//  HugAudioSource.h
//  Embrace
//
//  Created by Ricci Adams on 2018-12-05.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, HugAudioSourceStatus) {
    HugAudioSourceStatusPreparing,
    HugAudioSourceStatusPlaying,
    HugAudioSourceStatusFinished,
    HugAudioSourceStatusError
};

typedef struct HugAudioSourceInfo {
    HugAudioSourceStatus status;
    NSTimeInterval timeElapsed;
    NSTimeInterval timeRemaining;
} HugAudioSourceInfo;


typedef AUAudioUnitStatus (^HugAudioSourcePullInputBlock)(
    AUAudioFrameCount frameCount,
    AudioBufferList *inputData,
    HugAudioSourceStatus *outInfo
);


@interface HugAudioSource : NSObject

@property (nonatomic, readonly) HugAudioSourcePullInputBlock pullInputBlock;

@end

