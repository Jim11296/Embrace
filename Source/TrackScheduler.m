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

static void sCleanupSlice(void *userData, ScheduledAudioSlice *slice)
{
    AudioBufferList *list = slice->mBufferList;

    for (NSInteger i = 0; i < list->mNumberBuffers; i++) {
        free(list->mBuffers[i].mData);
    }

    free(slice->mBufferList);
    free(slice);
}


@implementation TrackScheduler {
    ExtAudioFileRef _audioFile;
    AudioStreamBasicDescription _clientFormat;
    AudioStreamBasicDescription _outputFormat;

    ScheduledAudioSlice *_slice;
}


- (id) initWithTrack:(Track *)track outputFormat:(AudioStreamBasicDescription)outputFormat
{
    if ((self = [super init])) {
        _track = track;
        _outputFormat = outputFormat;
        
        if (![self _setupAudioFile]) {
            self = nil;
            return nil;
        }
        
        [self _setupBuffers];
    }
    
    return self;
}


- (void) dealloc
{
    [self _cleanupAudioFile];

    if (_slice) {
        sCleanupSlice(_slice, _slice);
        _slice = NULL;
    }
}


- (void) _cleanupAudioFile
{
    if (_audioFile) {
        ExtAudioFileDispose(_audioFile);
    }

    [[_track fileURL] stopAccessingSecurityScopedResource];
}


- (BOOL) _setupAudioFile
{
    NSURL *url = [_track fileURL];

    AudioStreamBasicDescription fileFormat = {0};
    UInt32 fileFormatSize = sizeof(fileFormat);

    SInt64 fileLengthFrames = 0;
    UInt32 fileLengthFramesSize = sizeof(fileLengthFrames);

    [url startAccessingSecurityScopedResource];

    if (!CheckError(
        ExtAudioFileOpenURL((__bridge CFURLRef)url, &_audioFile),
        "ExtAudioFileOpenURL"
    )) {
        return NO;
    }

    if (!CheckError(
        ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileDataFormat, &fileFormatSize, &fileFormat),
        "ExtAudioFileGetProperty[ FileDataFormat ]"
    )) {
        return NO;
    }

    _clientFormat = GetPCMStreamBasicDescription(fileFormat.mSampleRate, _outputFormat.mChannelsPerFrame, NO);

    if (!CheckError(
        ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(_clientFormat), &_clientFormat),
        "ExtAudioFileSetProperty[ ClientDataFormat ]"
    )) {
        return NO;
    }
    
    if (!CheckError(
        ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileLengthFrames, &fileLengthFramesSize, &fileLengthFrames),
        "ExtAudioFileGetProperty[ FileLengthFrames ]"
    )) {
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
            ExtAudioFileSeek(_audioFile, startFrame);
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

        err = ExtAudioFileRead(_audioFile, &frameCount, fillBufferList);
        
        if (err) {
            NSLog(@"Error during ExtAudioFileRead(): %ld", (long)err);
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
}


#pragma mark - Public Methods

- (void) startSchedulingWithAudioUnit:(AudioUnit)audioUnit timeStamp:(AudioTimeStamp)timeStamp
{
    ScheduledAudioSlice *slice = _slice;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self _readDataInBackgroundIntoSlice:slice];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _cleanupAudioFile];
        });
    });

    while (![self totalFrames]) {
        usleep(1);
    }
    
    NSInteger primeAmount = (_clientFormat.mSampleRate * 10);
    NSInteger totalFrames = [self totalFrames];
    
    if (totalFrames < primeAmount) primeAmount = totalFrames;

    while ([self availableFrames] < primeAmount) {
        usleep(1);
    }

    _slice->mTimeStamp = timeStamp;
    _slice->mCompletionProc = sCleanupSlice;
    _slice->mCompletionProcUserData = _slice;

    AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0);
    CheckError(
        AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ScheduleAudioSlice, kAudioUnitScope_Global, 0, _slice, sizeof(ScheduledAudioSlice)),
        "AudioUnitSetProperty[ ScheduleAudioSlice ]"
    );
    
    _slice = NULL;
};


- (void) stopScheduling:(AudioUnit)audioUnit
{
    AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0);
}


@end
