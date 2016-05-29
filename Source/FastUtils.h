//
//  FastUtils.h
//  Embrace
//
//  Created by Ricci Adams on 2016-05-27.
//  Copyright © 2016 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>


extern void ApplySilenceToAudioBuffer(UInt32 inNumberFrames, AudioBufferList *ioData);


extern void ApplyFadeToAudioBuffer(UInt32 inNumberFrames, AudioBufferList *ioData, float fromValue, float toValue);
