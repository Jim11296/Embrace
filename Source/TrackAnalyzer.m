//
//  TrackData.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-14.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackAnalyzer.h"
#import "LoudnessMeasurer.h"
#import "AudioFile.h"

@interface TrackAnalyzer ()
@property (atomic) BOOL shouldCancelAnalysis;
@end


@interface TrackAnalyzerResult ()
@property (nonatomic) double  loudness;
@property (nonatomic) double  peak;
@property (nonatomic) NSData *overviewData;
@property (nonatomic) double  overviewRate;
@property (nonatomic) AudioFileError error;
@property (nonatomic) NSTimeInterval zerosAtStart;
@property (nonatomic) NSTimeInterval zerosAtEnd;
@end



static dispatch_queue_t sAnalysisImmediateQueue = nil;
static dispatch_queue_t sAnalysisBackgroundQueue = nil;


@implementation TrackAnalyzerResult
@end


@implementation TrackAnalyzer {
    NSURL *_fileURL;
    BOOL   _analyzingImmediately;
}


+ (void) initialize
{
    sAnalysisImmediateQueue  = dispatch_queue_create("TrackData.analysis.immediate",  DISPATCH_QUEUE_SERIAL);
    sAnalysisBackgroundQueue = dispatch_queue_create("TrackData.analysis.background", DISPATCH_QUEUE_SERIAL);
}


- (id) initWithFileURL:(NSURL *)url
{
    if ((self = [super init])) {
        _fileURL = url;
    }

    return self;
}


- (TrackAnalyzerResult *) _resultForFileAtURL:(NSURL *)url
{
    if ([self shouldCancelAnalysis]) return nil;

    TrackAnalyzerResult *result = [[TrackAnalyzerResult alloc] init];

    AudioFile *audioFile = [[AudioFile alloc] initWithFileURL:url];

    OSStatus err = noErr;

    // Open file
    if (err == noErr) {
        err = [audioFile open];
        if (err) NSLog(@"AudioFile -open: %ld", (long)err);
    }

    double loudness = 0;
    double peak     = 0;
    
    NSData *overviewData = nil;
    double  overviewRate = 0;
    
    AudioStreamBasicDescription fileFormat = {0};
    if (err == noErr) {
        err = [audioFile getFileDataFormat:&fileFormat];
    }


    AudioStreamBasicDescription clientFormat = {0};

    if (err == noErr) {
        UInt32 channels = fileFormat.mChannelsPerFrame;
        
        clientFormat.mSampleRate       = fileFormat.mSampleRate;
        clientFormat.mFormatID         = kAudioFormatLinearPCM;
        clientFormat.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        clientFormat.mBytesPerPacket   = sizeof(float);
        clientFormat.mFramesPerPacket  = 1;
        clientFormat.mBytesPerFrame    = clientFormat.mFramesPerPacket * clientFormat.mBytesPerPacket;
        clientFormat.mChannelsPerFrame = channels;
        clientFormat.mBitsPerChannel   = sizeof(float) * 8;

        err = [audioFile setClientDataFormat:&clientFormat];
    }
    
    if (![audioFile canRead] &&
        ![audioFile convert] &&
        ![audioFile canRead])
    {
        err = 1;
    }
    
    
    SInt64 fileLengthFrames = 0;
    if (err == noErr) {
        err = [audioFile getFileLengthFrames:&fileLengthFrames];
    }
    
    if (err == noErr) {
        NSInteger framesRemaining = fileLengthFrames;
        NSInteger bytesRemaining = framesRemaining * clientFormat.mBytesPerFrame;
        NSInteger bytesRead = 0;

        LoudnessMeasurer *measurer = LoudnessMeasurerCreate(clientFormat.mChannelsPerFrame, clientFormat.mSampleRate, framesRemaining, LoudnessMeasurerAll);

        AudioBufferList *fillBufferList = alloca(sizeof(AudioBufferList) * clientFormat.mChannelsPerFrame);
        fillBufferList->mNumberBuffers = clientFormat.mChannelsPerFrame;
        
        for (NSInteger i = 0; i < clientFormat.mChannelsPerFrame; i++) {
            fillBufferList->mBuffers[i].mNumberChannels = clientFormat.mChannelsPerFrame;
            fillBufferList->mBuffers[i].mDataByteSize = clientFormat.mBytesPerFrame * 4096 * 16;
            fillBufferList->mBuffers[i].mData = malloc(clientFormat.mBytesPerFrame  * 4096 * 16);
        }

        while (1 && (err == noErr)) {
            UInt32 frameCount = (UInt32)framesRemaining;
            err = [audioFile readFrames:&frameCount intoBufferList:fillBufferList];

            if (frameCount) {
                LoudnessMeasurerScanAudioBuffer(measurer, fillBufferList, frameCount);
            } else {
                break;
            }
            
            framesRemaining -= frameCount;
        
            bytesRead       += frameCount * clientFormat.mBytesPerFrame;
            bytesRemaining  -= frameCount * clientFormat.mBytesPerFrame;

            if (framesRemaining == 0) {
                break;
            }
        }

        for (NSInteger i = 0; i < clientFormat.mChannelsPerFrame; i++) {
            free(fillBufferList->mBuffers[i].mData);
        }


        NSUInteger startingZeros = LoudnessMeasurerGetStartingZeroCount(measurer);
        NSUInteger endingZeros   = LoudnessMeasurerGetEndingZeroCount(measurer);
        
        overviewData = LoudnessMeasurerGetOverview(measurer);
        overviewRate = 100;
        loudness     = LoudnessMeasurerGetLoudness(measurer);
        peak         = LoudnessMeasurerGetPeak(measurer);

        // If this file appears to be complete silence, don't strip it.
        if (peak < (10.0 / 32768.0)) {
            startingZeros = 0;
            endingZeros   = 0;
        }

        [result setOverviewData:overviewData];
        [result setOverviewRate:overviewRate];
        [result setZerosAtStart:(startingZeros / clientFormat.mSampleRate)];
        [result setZerosAtEnd:  (endingZeros   / clientFormat.mSampleRate)];
        [result setLoudness:loudness];
        [result setPeak:peak];

        LoudnessMeasurerFree(measurer);
    }

    [result setError:[audioFile audioFileError]];

    return result;
}


- (void) analyzeFileAtURL:(NSURL *)url immediately:(BOOL)immediately completion:(TrackAnalyzerCompletionCallback)completion
{
    _analyzingImmediately = immediately;

    dispatch_queue_t queue = immediately ? sAnalysisImmediateQueue : sAnalysisBackgroundQueue;

    __weak id weakSelf = self;
    dispatch_async(queue, ^{
        TrackAnalyzerResult *result = nil;

        if (weakSelf && ![weakSelf shouldCancelAnalysis]) {
            NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
            (void)startTime;

            result = [weakSelf _resultForFileAtURL:url];
            
//            NSLog(@"Analysis time: %gms", ([NSDate timeIntervalSinceReferenceDate] - startTime) * 1000);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (result && ![weakSelf shouldCancelAnalysis]) {
                completion(result);
            }
        });
    });
}


- (void) cancel
{
    [self setShouldCancelAnalysis:YES];
}


@end
