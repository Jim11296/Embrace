// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class HugProtectedBuffer;

@interface HugAudioFile : NSObject

- (id) initWithFileURL:(NSURL *)url;

- (BOOL) open;
- (void) close;

- (BOOL) readFrames:(inout UInt32 *)ioNumberFrames intoBufferList:(inout AudioBufferList *)bufferList;
- (BOOL) seekToFrame:(SInt64)startFrame;

@property (nonatomic, readonly) SInt64 fileLengthFrames;
@property (nonatomic, readonly) AudioStreamBasicDescription format;
@property (nonatomic, readonly) double sampleRate;
@property (nonatomic, readonly) NSInteger channelCount;

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) NSError *error;

@end
