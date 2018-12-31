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
#import "ProtectedBuffer.h"


@interface TrackScheduler ()
@property (atomic) NSInteger      totalFrames;
@property (atomic) BOOL           shouldCancelRead;
@property (atomic) OSStatus       rawError;
@property (atomic) AudioFileError audioFileError;
@end


typedef struct {
    NSInteger frameIndex;
    UInt32    totalFrames;
    AudioBufferList *bufferList;
} TrackSchedulerContext;


static OSStatus sInputCallback(
    void *inRefCon, 
    AudioUnitRenderActionFlags *ioActionFlags, 
    const AudioTimeStamp *inTimeStamp, 
    UInt32 inBusNumber, 
    UInt32 inNumberFrames, 
    AudioBufferList *ioData
) {
    TrackSchedulerContext *context = (TrackSchedulerContext *)inRefCon;

    NSInteger offset = 0;

    // Zero pad if needed
    if (context->frameIndex < 0) {
        NSInteger padCount     = -context->frameIndex;
        NSInteger framesToCopy = MIN(inNumberFrames, padCount);
    
        for (NSInteger b = 0; b < ioData->mNumberBuffers; b++) {
            memset(ioData->mBuffers[b].mData, 0, sizeof(float) * framesToCopy);
        }

        offset = framesToCopy;
        context->frameIndex += framesToCopy;
    }

    // Copy track data
    {
        NSUInteger framesToCopy = MIN(inNumberFrames - offset, context->totalFrames - context->frameIndex);
        
        for (NSInteger b = 0; b < ioData->mNumberBuffers; b++) {
            float *inSamples  = (float *)context->bufferList->mBuffers[b].mData;
            float *outSamples = (float *)ioData->mBuffers[b].mData;
            
            inSamples  += context->frameIndex;
            outSamples += offset;

            memcpy(outSamples, inSamples, sizeof(float) * framesToCopy);
            
            NSInteger remaining = framesToCopy - inNumberFrames;
            if (remaining > 0) {
                memset(&outSamples[remaining], 0, sizeof(float) * remaining);
            }
        }

        context->frameIndex += framesToCopy;
    }

    return noErr;
}


@implementation TrackScheduler {
    AudioFile *_audioFile;
    AudioStreamBasicDescription _clientFormat;

    TrackSchedulerContext *_context;
    NSArray *_protectedBuffers;
}


- (id) initWithTrack:(Track *)track
{
    if ((self = [super init])) {
        _track = track;
    }
    
    return self;
}


- (void) dealloc
{
    [self _cleanupAudioFile];

    if (_context) {
        AudioBufferList *list = _context->bufferList;

        for (NSInteger i = 0; i < list->mNumberBuffers; i++) {
            list->mBuffers[i].mData = NULL;
        }

        free(_context->bufferList);
        free(_context);
    }
}


- (void) _lockBuffers
{
    for (ProtectedBuffer *protectedBuffer in _protectedBuffers) {
        [protectedBuffer lock];
    }
}


- (void) _cleanupAudioFile
{
    _audioFile = nil;
}


- (BOOL) _setupAudioFile
{
    NSURL *url = [_track internalURL];

    AudioStreamBasicDescription fileFormat = {0};
    SInt64 fileLengthFrames = 0;

    _audioFile = [[AudioFile alloc] initWithFileURL:url];

    if (!CheckError(
        [_audioFile open],
        "[_audioFile open]"
    )) {
        EmbraceLog(@"TrackScheduler", @"%@, Could not open AudioFile", _track);
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }

    if (!CheckError(
        [_audioFile getFileDataFormat:&fileFormat],
        "[_audioFile getFileDataFormat:]"
    )) {
        EmbraceLog(@"TrackScheduler", @"%@, Could not get data format for AudioFile", _track);
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }

    _clientFormat = GetPCMStreamBasicDescription(fileFormat.mSampleRate, fileFormat.mChannelsPerFrame, NO);

    if (!CheckError(
        [_audioFile setClientDataFormat:&_clientFormat],
        "[_audioFile getClientDataFormat:]"
    )) {
        EmbraceLog(@"TrackScheduler", @"%@, Could not set client format for AudioFile", _track);
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }
    
    if (![_audioFile canRead] &&
        ![_audioFile convert] &&
        ![_audioFile canRead])
    {
        EmbraceLog(@"TrackScheduler", @"%@, read/convert/read error: %ld", _track, (long)[_audioFile audioFileError]);
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }
    
    
    if (!CheckError(
        [_audioFile getFileLengthFrames:&fileLengthFrames],
        "[_audioFile getFileLengthFrames:]"
    )) {
        EmbraceLog(@"TrackScheduler", @"%@, could not get file length frames for AudioFile", _track);
        [self setAudioFileError:[_audioFile audioFileError]];
        return NO;
    }

    // Determine start and stop time in frames
    {
        NSInteger totalFrames = fileLengthFrames;
        
        NSInteger startFrame  = [_track startTime] * _clientFormat.mSampleRate;
        NSInteger stopFrame   = 0;

        if (startFrame < 0) startFrame = 0;
        if (startFrame > totalFrames) startFrame = totalFrames;

        if ([_track stopTime]) {
            stopFrame  = [_track stopTime] * _clientFormat.mSampleRate;
            if (stopFrame < 0) stopFrame = 0;
            if (stopFrame > totalFrames) stopFrame = totalFrames;

            totalFrames = (stopFrame - startFrame);
        } else {
            totalFrames -= startFrame;
        }

        EmbraceLog(@"TrackScheduler", @"%@ fileLengthFrames: %ld, totalFrames: %ld, startFrame: %ld, stopFrame: %ld", _track, (long)fileLengthFrames, (long)totalFrames, (long)startFrame, (long)stopFrame);

        if (startFrame) {
            if (!CheckError(
                [_audioFile seekToFrame:startFrame],
                "[_audioFile seekToFrame:]"
            )) {
                EmbraceLog(@"TrackScheduler", @"%@ seekToFrame failed for AudioFile", _track);
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
    EmbraceLog(@"TrackScheduler", @"%@ setting up buffers", _track);
    
    UInt32 bufferCount = _clientFormat.mChannelsPerFrame;

    UInt32 totalFrames = (UInt32)[self totalFrames];
    UInt32 totalBytes  = totalFrames * _clientFormat.mBytesPerFrame;

    AudioBufferList *list = malloc(sizeof(AudioBufferList) * MAX(bufferCount, 2));

    list->mNumberBuffers = bufferCount;

    NSMutableArray *protectedBuffers = [NSMutableArray array];

    for (NSInteger i = 0; i < bufferCount; i++) {
        ProtectedBuffer *protectedBuffer = [[ProtectedBuffer alloc] initWithCapacity:totalBytes];
    
        list->mBuffers[i].mNumberChannels = 1;
        list->mBuffers[i].mDataByteSize = (UInt32)totalBytes;
        list->mBuffers[i].mData = (void *)[protectedBuffer bytes];

        [protectedBuffers addObject:protectedBuffer];
    }

    _context = calloc(1, sizeof(TrackSchedulerContext));
    _context->totalFrames = (UInt32)totalFrames;
    _context->bufferList = list;

    _protectedBuffers = protectedBuffers;
}


- (void) _readDataInBackgroundIntoContext: (TrackSchedulerContext *) context
                              primeAmount: (NSInteger) primeAmount
                           primeSemaphore: (dispatch_semaphore_t) primeSemaphore
{
    PlayerShouldUseCrashPad = 0;

    NSInteger framesRemaining = [self totalFrames];
    NSInteger bytesRemaining = framesRemaining * _clientFormat.mBytesPerFrame;

    NSInteger bytesRead = 0;
    NSInteger framesAvailable = 0;

    UInt32 bufferCount = context->bufferList->mNumberBuffers;
    
    AudioBufferList *fillBufferList = alloca(sizeof(AudioBufferList) * bufferCount);
    fillBufferList->mNumberBuffers = (UInt32)bufferCount;
    
    OSStatus err = noErr;
    BOOL needsSignal = YES;
    
    while (err == noErr) {
        BOOL shouldCancel = [self shouldCancelRead];
        if (shouldCancel) break;
    
        UInt32 maxFrames  = 32768;
        UInt32 frameCount = (UInt32)framesRemaining;
        if (frameCount > maxFrames) frameCount = maxFrames;

        for (NSInteger i = 0; i < bufferCount; i++) {
            fillBufferList->mBuffers[i].mNumberChannels = 1;
            fillBufferList->mBuffers[i].mDataByteSize = (UInt32)bytesRemaining;
            
            UInt8 *data = (UInt8 *)context->bufferList->mBuffers[i].mData;
            data += bytesRead;
            fillBufferList->mBuffers[i].mData = data;
        }

        if (frameCount > 0) {
            err = [_audioFile readFrames:&frameCount intoBufferList:fillBufferList];
        }

        // ExtAudioFileRead() is documented to return 0 when the end of the file is reached.
        //
        if ((frameCount == 0) || (framesRemaining == 0)) {
            break;
        }

        if (err) {
            [self setAudioFileError:[_audioFile audioFileError]];
            [self setRawError:err];
        }
   
        framesAvailable += frameCount;
        
        if ((framesAvailable >= primeAmount) && needsSignal) {
            dispatch_semaphore_signal(primeSemaphore);
            needsSignal = NO;
        }

        framesRemaining -= frameCount;
    
        bytesRead       += frameCount * _clientFormat.mBytesPerFrame;
        bytesRemaining  -= frameCount * _clientFormat.mBytesPerFrame;
    }

    PlayerShouldUseCrashPad = 1;

    if (needsSignal) {
        dispatch_semaphore_signal(primeSemaphore);
    }
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

- (NSTimeInterval) timeElapsed;
{   
    NSInteger samplesPlayed = [self samplesPlayed];

    if (_clientFormat.mSampleRate) {
        return samplesPlayed / _clientFormat.mSampleRate;
    } else {
        return 0;
    }
}


- (NSInteger) samplesPlayed
{
    if (_context) {
        return _context->frameIndex;
    }
    
    return 0;
}


- (BOOL) isDone
{
    if (_context) {
        NSInteger frameIndex = _context->frameIndex;
        
        if (frameIndex < 0) {
            return NO;
        } else {
            return ([self totalFrames] - frameIndex) <= 0;
        }
    }
    
    return 0;
}


- (BOOL) startSchedulingWithAudioUnit:(AudioUnit)audioUnit paddingInSeconds:(NSTimeInterval)paddingInSeconds
{
    if ([self rawError] || [self audioFileError]) {
        return NO;
    }

    EmbraceLog(@"TrackScheduler", @"%@ startScheduling called", _track);
    
    TrackSchedulerContext *context = _context;
    context->frameIndex = _clientFormat.mSampleRate * -paddingInSeconds;

    NSInteger totalFrames = [self totalFrames];
    NSInteger primeAmount = (_clientFormat.mSampleRate * 10);
    if (totalFrames < primeAmount) primeAmount = totalFrames;

    dispatch_semaphore_t primeSemaphore = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self _readDataInBackgroundIntoContext:context primeAmount:primeAmount primeSemaphore:primeSemaphore];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _lockBuffers];
            [self _cleanupAudioFile];
        });
    });

    // Wait for the prime semaphore, this should be very fast.  If we can't decode at least 10 seconds
    // of audio in 5 seconds, something is wrong, and flip the error to "read too slow"
    //
    int64_t fiveSecondsInNs = 5l * 1000 * 1000 * 1000;
    if (dispatch_semaphore_wait(primeSemaphore, dispatch_time(0, fiveSecondsInNs))) {
        EmbraceLog(@"TrackScheduler", @"dispatch_semaphore_wait() timed out for %@", _track);
        [self setAudioFileError:AudioFileErrorReadTooSlow];
    }

    EmbraceLog(@"TrackScheduler", @"%@ primed!", _track);
    
    if ([self rawError] || [self audioFileError]) {
        [self setShouldCancelRead:YES];
        return NO;
    }

    AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0);

    AURenderCallbackStruct callback = { sInputCallback, _context };

    return CheckError(
        AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback)),
        "AudioUnitSetProperty[ SetRenderCallback ]"
    );
}


- (void) stopScheduling:(AudioUnit)audioUnit
{
    EmbraceLog(@"TrackScheduler", @"%@ stopScheduling called", _track);

    AURenderCallbackStruct callback  = { NULL, NULL };

    CheckError(
        AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback)),
        "AudioUnitSetProperty[ SetRenderCallback ]"
    );
}


@end
