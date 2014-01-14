//
//  WaveformView.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Waveform.h"

NSString * const WaveformDidFinishAnalysisNotificationName = @"WaveformDidFinishAnalysisNotification";


@implementation Waveform {
    ExtAudioFileRef _audioFile;
    NSURL *_url;
}

+ (instancetype) waveformWithFileURL:(NSURL *)url
{
    return [[self alloc] initWithFileURL:url];
}


- (id) initWithFileURL:(NSURL *)url
{
    if ((self = [super init])) {
        _url = url;
        [self _startAnalysisInBackground];
    }

    return self;
}


- (void) dealloc
{
    [self _cleanupAudioFile];
}

- (void) _startAnalysisInBackground
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self _analyzeFileAtURL:_url];
    });
}


- (void) _analyzeFileAtURL:(NSURL *)url
{
    ExtAudioFileRef audioFile = NULL;
    OSStatus err = noErr;

    // Open file
    if (err == noErr) {
        err = ExtAudioFileOpenURL((__bridge CFURLRef)url, &audioFile);
        if (err) NSLog(@"ExtAudioFileOpenURL: %ld", (long)err);
    }

    AudioStreamBasicDescription format = {0};

    if (err == noErr) {
        NSInteger channelCount = 1;

        format.mSampleRate       = 44100;
        format.mFormatID         = kAudioFormatLinearPCM;
        format.mFormatFlags      = kAudioFormatFlagIsFloat;
        format.mBytesPerPacket   = sizeof(float);
        format.mFramesPerPacket  = 1;
        format.mBytesPerFrame    = sizeof(float) * channelCount;
        format.mChannelsPerFrame = channelCount;
        format.mBitsPerChannel   = sizeof(float) * 8;

        err = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(format), &format);
    }

    NSInteger sourceBufferSize = (4 * 1024 * sizeof(float));
    float *source = malloc(sourceBufferSize);
    
    NSMutableArray *mins = [NSMutableArray array];
    NSMutableArray *maxs = [NSMutableArray array];
    
    
	// do the read and write - the conversion is done on and by the write call
	while (1) {
		AudioBufferList fillBufferList;
		fillBufferList.mNumberBuffers = 1;
		fillBufferList.mBuffers[0].mNumberChannels = format.mChannelsPerFrame;
		fillBufferList.mBuffers[0].mDataByteSize = sourceBufferSize;
		fillBufferList.mBuffers[0].mData = source;
			
		// client format is always linear PCM - so here we determine how many frames of lpcm
		// we can read/write given our buffer size
		UInt32 frameCount = (sourceBufferSize / format.mBytesPerFrame);
		
		// printf("test %d\n", numFrames);

		err = ExtAudioFileRead (audioFile, &frameCount, &fillBufferList);
        if (err) NSLog(@"ExtAudioFileRead: %d", (long)err);

		if (!frameCount) {
			break;
		}
        
        if (err == noErr) {
            float min = INFINITY;
            float max = -INFINITY;

            for (NSInteger i = 0; i < frameCount; i++) {
                float sample = source[i];
                if (sample < min) min = sample;
                if (sample > max) max = sample;
            }
            
            [mins addObject:@( min )];
            [maxs addObject:@( max )];
        }
    }

    NSLog(@"done");

    ExtAudioFileDispose(audioFile);

    dispatch_async(dispatch_get_main_queue(), ^{
        _mins = mins;
        _maxs = maxs;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:WaveformDidFinishAnalysisNotificationName object:nil];
    });

}


- (void) _cleanupAudioFile
{
    if (_audioFile) {
        _audioFile = NULL;
    }
}



@end
