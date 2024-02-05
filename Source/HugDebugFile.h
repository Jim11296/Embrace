// (c) 2011-2024 Ricci Adams.  All rights reserved.


#import <AudioToolbox/AudioToolbox.h>

@interface HugDebugFile : NSObject

+ (void) writeWithSampleRate: (UInt32) sampleRate
                 totalFrames: (NSInteger) totalFrames
                  bufferList: (AudioBufferList *) bufferList;

@end
