//
//  TrackData.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-14.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackData.h"

@interface TrackData ()
@property (nonatomic) double sampleRate;
@property (nonatomic) AudioStreamBasicDescription streamDescription;
@end

@implementation TrackData {
    NSURL *_fileURL;
    NSMutableArray *_readyCallbacks;
    BOOL   _ready;
}


- (id) initWithFileURL:(NSURL *)url mixdown:(BOOL)mixdown
{
    if ((self = [super init])) {
        _fileURL = url;

        __weak id weakSelf = self;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [weakSelf _readFileAtURL:url mixdown:mixdown];
        });
    }

    return self;
}


- (void) _finishedWithData:(NSData *)data streamDescription:(AudioStreamBasicDescription)asbd
{
    _data = data;
    _streamDescription = asbd;
    _ready = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        for (TrackDataReadyCallback cb in _readyCallbacks) {
            cb(self);
        }
        
        _readyCallbacks = nil;
    });
}


- (void) _readFileAtURL:(NSURL *)url mixdown:(BOOL)mixdown
{
    [url startAccessingSecurityScopedResource];

    ExtAudioFileRef audioFile = NULL;
    OSStatus err = noErr;

    // Open file
    if (err == noErr) {
        err = ExtAudioFileOpenURL((__bridge CFURLRef)url, &audioFile);
        if (err) NSLog(@"ExtAudioFileOpenURL: %ld", (long)err);
    }


    AudioStreamBasicDescription fileFormat = {0};
    UInt32 fileFormatSize = sizeof(fileFormat);

    if (err == noErr) {
        err = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileDataFormat, &fileFormatSize, &fileFormat);
    }


    AudioStreamBasicDescription clientFormat = {0};

    if (err == noErr) {
        UInt32 channels = mixdown ? 1 : fileFormat.mChannelsPerFrame;
        
        clientFormat.mSampleRate       = fileFormat.mSampleRate;
        clientFormat.mFormatID         = kAudioFormatLinearPCM;
        clientFormat.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        clientFormat.mBytesPerPacket   = sizeof(float) * channels;
        clientFormat.mFramesPerPacket  = 1;
        clientFormat.mBytesPerFrame    = clientFormat.mFramesPerPacket * clientFormat.mBytesPerPacket;
        clientFormat.mChannelsPerFrame = channels;
        clientFormat.mBitsPerChannel   = sizeof(float) * 8;

        err = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(clientFormat), &clientFormat);
    }
    
    SInt64 fileLengthFrames = 0;
    UInt32 fileLengthFramesSize = sizeof(fileLengthFrames);
   
    if (err == noErr) {
        err = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileLengthFrames, &fileLengthFramesSize, &fileLengthFrames);
    }
    
    UInt8 *bytes = NULL;
    NSInteger bytesTotal = 0;

    if (err == noErr) {
        NSInteger framesRemaining = fileLengthFrames;
        NSInteger bytesRemaining = framesRemaining * clientFormat.mBytesPerFrame;
        NSInteger bytesRead = 0;

        bytesTotal = bytesRemaining;
        bytes = malloc(bytesTotal);

        while (1 && (err == noErr)) {
            AudioBufferList fillBufferList;
            fillBufferList.mNumberBuffers = 1;
            fillBufferList.mBuffers[0].mNumberChannels = clientFormat.mChannelsPerFrame;
            fillBufferList.mBuffers[0].mDataByteSize = (UInt32)bytesRemaining;
            fillBufferList.mBuffers[0].mData = &bytes[bytesRead];
        
            UInt32 frameCount = (UInt32)framesRemaining;
            err = ExtAudioFileRead(audioFile, &frameCount, &fillBufferList);

            if (frameCount == 0) {
                break;
            }
            
            framesRemaining -= frameCount;
        
            bytesRead       += frameCount * clientFormat.mBytesPerFrame;
            bytesRemaining  -= frameCount * clientFormat.mBytesPerFrame;

            if (framesRemaining == 0) {
                break;
            }
        }
    }
    
    NSData *data = nil;
    if (err == noErr) {
        data = [NSData dataWithBytesNoCopy:bytes length:bytesTotal freeWhenDone:YES];
    } else {
        free(bytes);
    }
    
    __weak id weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf _finishedWithData:data streamDescription:clientFormat];
    });

    if (audioFile) {
        ExtAudioFileDispose(audioFile);
    }

    [url stopAccessingSecurityScopedResource];
}


- (void) addReadyCallback:(TrackDataReadyCallback)callback
{
    TrackDataReadyCallback cb = [callback copy];

    if (_ready) {
        dispatch_async(dispatch_get_main_queue(), ^{
            cb(self);
        });

    } else {
        if (!_readyCallbacks) _readyCallbacks = [NSMutableArray array];
        [_readyCallbacks addObject:cb];
    }
}

@end
