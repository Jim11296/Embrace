//
//  Scheduler.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackScheduler.h"
#import "Track.h"

@interface TrackScheduler ()
@property (atomic) NSInteger totalFrames;
@property (atomic) NSInteger availableFrames;
@end

@implementation TrackScheduler {
    UInt8    **_buffers;
    NSUInteger _channelCount;

    ScheduledAudioSlice *_slice;
}


- (id) initWithTrack:(Track *)track streamDescription:(AudioStreamBasicDescription)streamDescription
{
    if ((self = [super init])) {
        _track = track;
        _streamDescription = streamDescription;
    }
    
    return self;
}


- (void) _readDataForTrack:(Track *)track streamDescription:(AudioStreamBasicDescription)streamDescription
{
    NSURL *url = [track fileURL];

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

    UInt32 channels = streamDescription.mChannelsPerFrame;

    if (err == noErr) {
        err = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(streamDescription), &streamDescription);
    }
    
    SInt64 fileLengthFrames = 0;
    UInt32 fileLengthFramesSize = sizeof(fileLengthFrames);
   
    if (err == noErr) {
        err = ExtAudioFileGetProperty(audioFile, kExtAudioFileProperty_FileLengthFrames, &fileLengthFramesSize, &fileLengthFrames);
    }

    NSInteger framesRemaining = fileLengthFrames;
    NSInteger bytesRemaining = framesRemaining * streamDescription.mBytesPerFrame;
    
    // Allocate buffers
    {
        _channelCount = channels;
        _buffers = malloc(sizeof(float *) * channels);

        _slice = calloc(1, sizeof(ScheduledAudioSlice));
        _slice->mBufferList = malloc(sizeof(AudioBufferList) * channels);
        _slice->mNumberFrames = (UInt32)framesRemaining;
        
        for (NSInteger i = 0; i < channels; i++) {
            _buffers[i] = malloc(bytesRemaining);

            AudioBuffer *b = &_slice->mBufferList->mBuffers[i];
            b->mNumberChannels = 1;
            b->mDataByteSize = (UInt32)bytesRemaining;
            b->mData = _buffers[i];
        }
        
        [self setTotalFrames:fileLengthFrames];
    }
    
    if (err == noErr) {
        NSInteger bytesRead = 0;
        NSInteger framesAvailable = 0;

        AudioBufferList *fillBufferList = alloca(sizeof(AudioBufferList) * channels);
        fillBufferList->mNumberBuffers = channels;
        
        while (1 && (err == noErr)) {
            UInt32 maxFrames  = 32768;
            UInt32 frameCount = (UInt32)framesRemaining;
            if (frameCount > maxFrames) frameCount = maxFrames;

            for (NSInteger i = 0; i < channels; i++) {
                fillBufferList->mBuffers[i].mNumberChannels = 1;
                fillBufferList->mBuffers[i].mDataByteSize = (UInt32)bytesRemaining;
                fillBufferList->mBuffers[i].mData = _buffers[i] + bytesRead;
            }

            err = ExtAudioFileRead(audioFile, &frameCount, fillBufferList);

            framesAvailable += frameCount;
            [self setAvailableFrames:framesAvailable];
            
            framesRemaining -= frameCount;
        
            bytesRead       += frameCount * streamDescription.mBytesPerFrame;
            bytesRemaining  -= frameCount * streamDescription.mBytesPerFrame;
            
            if (framesRemaining == 0) {
                break;
            }
        }
    }
    
    if (audioFile) {
        ExtAudioFileDispose(audioFile);
    }

    [url stopAccessingSecurityScopedResource];
}


- (void) startSchedulingWithAudioUnit:(AudioUnit)audioUnit timeStamp:(AudioTimeStamp)timeStamp
{
    Track *track = _track;
    AudioStreamBasicDescription streamDescription = _streamDescription;

    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self _readDataForTrack:track streamDescription:streamDescription];
    });

    while (![self totalFrames]) {
        usleep(1);
    }

//    while ([self totalFrames] != [self availableFrames]) {
//        usleep(1);
//    }

    NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
    
    
    _slice->mTimeStamp = timeStamp;
    
    OSStatus err = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduleAudioSlice, kAudioUnitScope_Global, 0, _slice, sizeof(ScheduledAudioSlice));

    NSLog(@"Elapsed: %gms %ld", (end - start) * 1000, (long)err);
};


- (void) stopScheduling:(AudioUnit)audioUnit
{
    AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0);
}


@end
