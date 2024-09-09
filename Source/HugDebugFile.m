// (c) 2011-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "HugDebugFile.h"


typedef struct {
    char    c[4];                // Always 'RIFF'
    UInt32  packageLength;      
    char    f[4];                // Always 'WAVE'

    char    a[4];                // Always 'fmt '
    UInt32  formatChunkLength;   // Always 0x10
    UInt16  audioFormat;         // Always 0x01
    UInt16  numberOfChannels;
    UInt32  sampleRate;
    UInt32  byteRate;
    UInt16  blockAlign;
    UInt16  bitsPerSample;

    char    b[4];               // Always 'data'
    UInt32  dataChunkLength;
} WAVHeader;


@implementation HugDebugFile


+ (void) writeWithSampleRate: (UInt32) sampleRate
                 totalFrames: (NSInteger) totalFrames
                  bufferList: (AudioBufferList *) bufferList
{
    NSURL *tempURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    tempURL = [tempURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    tempURL = [tempURL URLByAppendingPathExtension:@"wav"];

    NSMutableData *data = [NSMutableData data];

    WAVHeader h;
    h.c[0] = 'R'; h.c[1] = 'I'; h.c[2] = 'F'; h.c[3] = 'F';
    h.f[0] = 'W'; h.f[1] = 'A'; h.f[2] = 'V'; h.f[3] = 'E';
    h.a[0] = 'f'; h.a[1] = 'm'; h.a[2] = 't'; h.a[3] = ' ';
    h.b[0] = 'd'; h.b[1] = 'a'; h.b[2] = 't'; h.b[3] = 'a';

    h.formatChunkLength = 0x10;
    h.audioFormat       = 0x03;
    h.numberOfChannels  = bufferList->mNumberBuffers;
    h.sampleRate        = sampleRate;
    h.bitsPerSample     = 32;
    h.byteRate          = (h.sampleRate * h.numberOfChannels * (h.bitsPerSample / 8));
    h.blockAlign        = (h.bitsPerSample / 8) * h.numberOfChannels;
    h.dataChunkLength   = ((UInt32)totalFrames * h.numberOfChannels * (h.bitsPerSample / 8));
    h.packageLength     = h.dataChunkLength + 36;

    [data appendBytes:&h length:sizeof(WAVHeader)];
    
    for (NSInteger i = 0; i < totalFrames; i++) {
        for (NSInteger j = 0; j < bufferList->mNumberBuffers; j++) {
            AudioBuffer *buffer = &bufferList->mBuffers[j];
            float *floatArray = (float *)buffer->mData;
            [data appendBytes:&floatArray[i] length:sizeof(float)];
        }
    }

    [data writeToURL:tempURL atomically:YES];
    
    NSLog(@"%@", [tempURL absoluteString]);
}

@end
