//
//  WaveformView.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const WaveformDidFinishAnalysisNotificationName;

@interface Waveform : NSObject

+ (instancetype) waveformWithFileURL:(NSURL *)url;
- (id) initWithFileURL:(NSURL *)url;

@property (nonatomic, assign) NSArray *mins;
@property (nonatomic, assign) NSArray *maxs;


@end
