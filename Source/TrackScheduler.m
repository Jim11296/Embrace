//
//  Scheduler.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackScheduler.h"
#import "Track.h"
#import "AudioFile.h"
#import "Player.h"


@interface TrackScheduler ()
@property (atomic) NSInteger totalFrames;
@property (atomic) NSInteger availableFrames;

@property (atomic) OSStatus       rawError;
@property (atomic) AudioFileError audioFileError;
@end


static void sReleaseTrackScheduler(void *userData, ScheduledAudioSlice *bufferList)
{
    TrackScheduler *scheduler = CFBridgingRelease(userData);
    (void)scheduler;
}


@implementation TrackScheduler {
    AudioFile *_audioFile;
    AudioStreamBasicDescription _clientFormat;
    AudioStreamBasicDescription _outputFormat;

    ScheduledAudioSlice *_slice;
}


- (id) initWithTrack:(Track *)track outputFormat:(AudioStreamBasicDescription)outputFormat
{
    if ((self = [super init])) {
        _track = track;
        _outputFormat = outputFormat;
    }
    
    return self;
}


- (void) dealloc
{
    [self _cleanupAudioFile];

    if (_slice) {
        AudioBufferList *list = _slice->mBufferList;

        for (NSInteger i = 0; i < list->mNumberBuffers; i++) {
            free(list->mBuffers[i].mData);
        }

        free(_slice->mBufferList);
        free(_slice);
    }
}


- (void) _cleanupAudioFile
{
    _audioFile = nil;
}


- (BOOL) _setupAudioFile
{
    NSURL *url = [_track fileURL];

    AudioStreamBasicDescription fileFormat = {0};
    SInt64 fileLengthFrames = 0;

    _audioFile = [[AudioFile alloc] initWithFileURL:url];

    if (!CheckError(
        [_audioFile open],
        "[_audioFile open]"
    )) {
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }

    if (!CheckError(
        [_audioFile getFileDataFormat:&fileFormat],
        "[_audioFile getFileDataFormat:]"
    )) {
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }

    _clientFormat = GetPCMStreamBasicDescription(fileFormat.mSampleRate, _outputFormat.mChannelsPerFrame, NO);

    if (!CheckError(
        [_audioFile setClientDataFormat:&_clientFormat],
        "[_audioFile getClientDataFormat:]"
    )) {
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }
    
    if (![_audioFile canRead] &&
        ![_audioFile convert] &&
        ![_audioFile canRead])
    {
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }
    
    
    if (!CheckError(
        [_audioFile getFileLengthFrames:&fileLengthFrames],
        "[_audioFile getFileLengthFrames:]"
    )) {
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }

    // Determine start and stop time in frames
    {
        NSInteger totalFrames = fileLengthFrames;
        
        NSInteger startFrame  = [_track startTime] * _clientFormat.mSampleRate;
        if (startFrame < 0) startFrame = 0;
        if (startFrame > totalFrames) startFrame = totalFrames;

        if ([_track stopTime]) {
            NSInteger stopFrame  = [_track stopTime] * _clientFormat.mSampleRate;
            if (stopFrame < 0) stopFrame = 0;
            if (stopFrame > totalFrames) stopFrame = totalFrames;

            totalFrames = stopFrame;
        }

        if (startFrame) {
            if (!CheckError(
                [_audioFile seekToFrame:startFrame],
                "[_audioFile seekToFrame:]"
            )) {
                [self setAudioFileError:[_audioFile audioFileError]];
            }
        }
        
        fileLengthFrames = totalFrames;
    }
    
    [self setTotalFrames:fileLengthFrames];
    
    return YES;
}


- (void) _setupBuffers
{
    UInt32 bufferCount = _clientFormat.mChannelsPerFrame;

    UInt32 totalFrames = (UInt32)[self totalFrames];
    UInt32 totalBytes  = totalFrames * _clientFormat.mBytesPerFrame;

    AudioBufferList *list = malloc(sizeof(AudioBufferList) * bufferCount);

    list->mNumberBuffers = bufferCount;

    for (NSInteger i = 0; i < bufferCount; i++) {
        list->mBuffers[i].mNumberChannels = 1;
        list->mBuffers[i].mDataByteSize = (UInt32)totalBytes;
        list->mBuffers[i].mData = malloc(totalBytes);
    }

    _slice = calloc(1, sizeof(ScheduledAudioSlice));
    _slice->mNumberFrames = (UInt32)totalFrames;
    _slice->mBufferList = list;
}


- (void) _readDataInBackgroundIntoSlice:(ScheduledAudioSlice *)slice
{
    PlayerShouldUseCrashPad = 0;

    NSInteger framesRemaining = [self totalFrames];
    NSInteger bytesRemaining = framesRemaining * _clientFormat.mBytesPerFrame;

    NSInteger bytesRead = 0;
    NSInteger framesAvailable = 0;

    UInt32 bufferCount = slice->mBufferList->mNumberBuffers;

    AudioBufferList *fillBufferList = alloca(sizeof(AudioBufferList) * bufferCount);
    fillBufferList->mNumberBuffers = (UInt32)bufferCount;
    
    OSStatus err = noErr;
    
    while (1 && (err == noErr)) {
        UInt32 maxFrames  = 32768;
        UInt32 frameCount = (UInt32)framesRemaining;
        if (frameCount > maxFrames) frameCount = maxFrames;

        for (NSInteger i = 0; i < bufferCount; i++) {
            fillBufferList->mBuffers[i].mNumberChannels = 1;
            fillBufferList->mBuffers[i].mDataByteSize = (UInt32)bytesRemaining;
            
            UInt8 *data = (UInt8 *)slice->mBufferList->mBuffers[i].mData;
            data += bytesRead;
            fillBufferList->mBuffers[i].mData = data;
        }

        err = [_audioFile readFrames:&frameCount intoBufferList:fillBufferList];
        
        if (err) {
            [self setAudioFileError:[_audioFile audioFileError]];
            [self setRawError:err];
        }

        framesAvailable += frameCount;
        [self setAvailableFrames:framesAvailable];
        
        framesRemaining -= frameCount;
    
        bytesRead       += frameCount * _clientFormat.mBytesPerFrame;
        bytesRemaining  -= frameCount * _clientFormat.mBytesPerFrame;
        
        if (framesRemaining == 0) {
            break;
        }
    }
    
    PlayerShouldUseCrashPad = 1;
}


#pragma mark - Public Methods

- (BOOL) setup
{
    if (![self _setupAudioFile]) {
        return NO;
    }
    
    [self _setupBuffers];
    
    return YES;
}


- (BOOL) startSchedulingWithAudioUnit:(AudioUnit)audioUnit timeStamp:(AudioTimeStamp)timeStamp
{
    if ([self rawError] || [self audioFileError]) {
        return NO;
    }

    ScheduledAudioSlice *slice = _slice;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self _readDataInBackgroundIntoSlice:slice];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _cleanupAudioFile];
        });
    });

    while (![self totalFrames] && ![self rawError]) {
        usleep(1);
    }
    
    if ([self rawError] || [self audioFileError]) {
        return NO;
    }
    
    NSInteger primeAmount = (_clientFormat.mSampleRate * 10);
    NSInteger totalFrames = [self totalFrames];
    
    if (totalFrames < primeAmount) primeAmount = totalFrames;

    while ([self availableFrames] < primeAmount && ![self rawError] && ![self audioFileError]) {
        usleep(1);
    }
    
    if ([self rawError] || [self audioFileError]) {
        return NO;
    }

    _slice->mTimeStamp = timeStamp;
    _slice->mCompletionProc = sReleaseTrackScheduler;
    _slice->mCompletionProcUserData = (void *)CFBridgingRetain(self);

    AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0);

    return CheckError(
        AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduleAudioSlice, kAudioUnitScope_Global, 0, _slice, sizeof(ScheduledAudioSlice)),
        "AudioUnitSetProperty[ ScheduleAudioSlice ]"
    );
};


- (void) stopScheduling:(AudioUnit)audioUnit
{
    AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0);
}


@end
