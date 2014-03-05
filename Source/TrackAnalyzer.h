//
//  TrackData.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-14.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioFile.h"


@class TrackAnalyzerResult;
typedef void (^TrackAnalyzerCompletionCallback)(TrackAnalyzerResult *result);


@interface TrackAnalyzer : NSObject

- (void) analyzeFileAtURL:(NSURL *)url immediately:(BOOL)immediately completion:(TrackAnalyzerCompletionCallback)completion;
- (void) cancel;

@property (nonatomic, readonly, getter=isAnalyzingImmediately) BOOL analyzingImmediately;

@end


@interface TrackAnalyzerResult : NSObject
@property (nonatomic, readonly) double  loudness;
@property (nonatomic, readonly) double  peak;
@property (nonatomic, readonly) NSData *overviewData;
@property (nonatomic, readonly) double  overviewRate;
@property (nonatomic, readonly) NSTimeInterval zerosAtStart;
@property (nonatomic, readonly) NSTimeInterval zerosAtEnd;
@property (nonatomic, readonly) AudioFileError error;
@end

