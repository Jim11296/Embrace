// (c) 2011-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <AudioToolbox/AudioToolbox.h>

@interface HugDebugFile : NSObject

+ (void) writeWithSampleRate: (UInt32) sampleRate
                 totalFrames: (NSInteger) totalFrames
                  bufferList: (AudioBufferList *) bufferList;

@end
