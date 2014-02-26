//
//  AudioFile.h
//  Embrace
//
//  Created by Ricci Adams on 2014-02-19.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AudioFileError) {
    AudioFileErrorNone             = 0,
    AudioFileErrorProtectedContent = 101,
    AudioFileErrorConversionFailed = 102,
    AudioFileErrorOpenFailed       = 103,
    AudioFileErrorReadFailed       = 104,
    AudioFileErrorReadTooSlow      = 105
};

@interface AudioFile : NSObject

- (id) initWithFileURL:(NSURL *)url;

- (OSStatus) open;

- (BOOL) canRead;
- (BOOL) convert;

- (OSStatus) readFrames:(inout UInt32 *)ioNumberFrames intoBufferList:(inout AudioBufferList *)bufferList;
- (OSStatus) seekToFrame:(SInt64)startFrame;

- (OSStatus) getFileDataFormat:(AudioStreamBasicDescription *)fileDataFormat;
- (OSStatus) getFileLengthFrames:(SInt64 *)fileLengthFrames;

- (OSStatus) setClientDataFormat:(AudioStreamBasicDescription *)clientDataFormat;
- (OSStatus) getClientDataFormat:(AudioStreamBasicDescription *)clientDataFormat;

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) AudioFileError audioFileError;

@end
