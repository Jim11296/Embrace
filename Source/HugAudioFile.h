// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, HugAudioFileError) {
    HugAudioFileErrorNone             = 0,
    HugAudioFileErrorProtectedContent = 101,
    HugAudioFileErrorConversionFailed = 102,
    HugAudioFileErrorOpenFailed       = 103,
    HugAudioFileErrorReadFailed       = 104,
    HugAudioFileErrorReadTooSlow      = 105
};


@interface HugAudioFile : NSObject

- (id) initWithFileURL:(NSURL *)url;

- (BOOL) prepare;

- (OSStatus) readFrames:(inout UInt32 *)ioNumberFrames intoBufferList:(inout AudioBufferList *)bufferList;
- (OSStatus) seekToFrame:(SInt64)startFrame;

@property (nonatomic, readonly) SInt64 fileLengthFrames;
@property (nonatomic, readonly) AudioStreamBasicDescription format;
@property (nonatomic, readonly) double sampleRate;
@property (nonatomic, readonly) NSInteger channelCount;

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) HugAudioFileError audioFileError;

@end
