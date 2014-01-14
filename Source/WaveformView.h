//
//  WaveformView.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Waveform;

@interface WaveformView : NSView

@property (nonatomic, strong) Waveform *waveform;
@end
