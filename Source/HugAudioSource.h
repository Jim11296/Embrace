//
//  HugAudioSource.h
//  Embrace
//
//  Created by Ricci Adams on 2018-12-05.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HugAudioSource;

typedef NS_ENUM(NSInteger, HugPlaybackStatus) {
    HugPlaybackStatusStopped = 0,
    HugPlaybackStatusPreparing,
    HugPlaybackStatusWaiting,
    HugPlaybackStatusPlaying,
    HugPlaybackStatusFinished
};

typedef struct HugPlaybackInfo {
    HugPlaybackStatus status;
    NSTimeInterval timeElapsed;
    NSTimeInterval timeRemaining;
} HugPlaybackInfo;

typedef OSStatus (^HugAudioSourceInputBlock)(
    AUAudioFrameCount frameCount,
    AudioBufferList *inputData,
    HugPlaybackInfo *outInfo
);


typedef void (^HugAudioSourceCompletionHandler)(HugAudioSource *source);

@interface HugAudioSource : NSObject

- (instancetype) initWithAudioFile: (HugAudioFile *) file
                          settings: (NSDictionary *) settings;

// Primes the audio buffer. If this returns YES, completionHandler will be invoked
// after the buffer is completely prepared
//
- (BOOL) prepareWithStartTime: (NSTimeInterval) startTime
                     stopTime: (NSTimeInterval) stopTime
                      padding: (NSTimeInterval) padding
            completionHandler: (HugAudioSourceCompletionHandler) completionHandler;

@property (nonatomic, readonly) HugAudioFile *audioFile;
@property (nonatomic, readonly) NSDictionary *settings;

@property (nonatomic, readonly) NSError *error;

@property (nonatomic, readonly) HugAudioSourceInputBlock inputBlock;

@end

