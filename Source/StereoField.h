//
//  StereoField.h
//  Embrace
//
//  Created by Ricci Adams on 2014-03-17.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern void ApplyStereoField(UInt32 inNumberFrames, AudioBufferList *ioData, float previousStereoLevel, float newStereoLevel);
