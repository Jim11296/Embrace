//
//  HugAudioSource.h
//  Embrace
//
//  Created by Ricci Adams on 2018-12-05.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, HugPlaybackStatus) {
    HugPlaybackStatusPreparing = 0,
    HugPlaybackStatusWaiting,
    HugPlaybackStatusPlaying,
    HugPlaybackStatusFinished
};

typedef struct HugPlaybackInfo {
    HugPlaybackStatus status;
    NSTimeInterval timeElapsed;
    NSTimeInterval timeRemaining;
} HugPlaybackInfo;


typedef void (^HugAudioSourceInputBlock)(
    AUAudioFrameCount frameCount,
    AudioBufferList *inputData,
    HugPlaybackInfo *outInfo
);


@interface HugAudioSource : NSObject

- (instancetype) initWithAudioFile: (HugAudioFile *) file
                          settings: (NSDictionary *) settings;

- (BOOL) prepareWithStartTime: (NSTimeInterval) startTime
                     stopTime: (NSTimeInterval) stopTime
                      padding: (NSTimeInterval) padding;

@property (nonatomic, readonly) HugAudioFile *audioFile;
@property (nonatomic, readonly) NSDictionary *settings;

@property (nonatomic, readonly) NSError *error;

@property (nonatomic, readonly) HugAudioSourceInputBlock inputBlock;

@end

