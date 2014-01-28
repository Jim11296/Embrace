//
//  WaveformView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WaveformView.h"
#import "TrackData.h"
#import "Track.h"

#import <Accelerate/Accelerate.h>


@implementation WaveformView {
    TrackData *_trackData;
    NSData    *_shrunkedData;

    CALayer   *_inactiveLayer;
    CALayer   *_activeLayer;
}

- (id) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self setWantsLayer:YES];
        [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
        
        _inactiveLayer = [CALayer layer];
        [_inactiveLayer setDelegate:self];
        [_inactiveLayer setFrame:[self bounds]];
        [_inactiveLayer setContentsGravity:kCAGravityRight];

        _activeLayer = [CALayer layer];
        [_activeLayer setDelegate:self];
        [_activeLayer setFrame:[self bounds]];
        [_activeLayer setContentsGravity:kCAGravityLeft];

        [[self layer] addSublayer:_inactiveLayer];
        [[self layer] addSublayer:_activeLayer];

        _activeWaveformColor = [NSColor blackColor];
        _inactiveWaveformColor = [NSColor grayColor];
    }
    
    return self;
}

- (BOOL) wantsUpdateLayer { return YES; }
- (void) updateLayer { }


- (void) layout
{
    [super layout];
    
    [_inactiveLayer setFrame:[self bounds]];
    [_activeLayer   setFrame:[self bounds]];

    [_activeLayer   setNeedsDisplay];
    [_inactiveLayer setNeedsDisplay];
}

- (BOOL) layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
    [_inactiveLayer setContentsScale:newScale];
    [_activeLayer   setContentsScale:newScale];

    return YES;
}


- (NSData *) _reduceData:(NSData *)data toCount:(NSUInteger)outCount
{
    if (!_shrunkedData) return nil;

    NSInteger inCount = [_shrunkedData length] / sizeof(float);
    float *inFloats = (float *)[_shrunkedData bytes];

    float *outFloats = malloc(outCount * sizeof(float));
    
    double stride = inCount / (double)outCount;

    dispatch_apply(outCount, dispatch_get_global_queue(0, 0), ^(size_t o) {
        NSInteger i = llrintf(o * stride);

        NSInteger length = (NSInteger)stride;
        
        // Be paranoid, I saw a crash in vDSP_maxv() during development
        if (i + length > inCount) {
            length = (inCount - i);
        }

        float max;
        vDSP_maxv(&inFloats[i], 1, &max, length);
        
        outFloats[o] = max;
    });

    return [NSData dataWithBytesNoCopy:outFloats length:outCount * sizeof(float) freeWhenDone:YES];
}


- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    if (!_shrunkedData) return;

    CGSize size = [self bounds].size;
    CGFloat scale = [[self window] backingScaleFactor];

    NSData *data = [self _reduceData:_shrunkedData toCount:size.width * scale];

    CGContextSetInterpolationQuality(context, kCGInterpolationLow);

    NSInteger sampleCount = [data length] / sizeof(float);
    NSInteger start = 0;
    NSInteger end = sampleCount;

    CGAffineTransform transform = CGAffineTransformMakeScale(size.width / sampleCount, 1);

    transform = CGAffineTransformTranslate(transform, -start, 0);

    transform = CGAffineTransformTranslate(transform, 0, size.height / 2);
    transform = CGAffineTransformScale(transform, 1, size.height / 2);

    CGContextConcatCTM(context, transform);

    float *floats = (float *)[data bytes];

    if (start < end) {
        CGContextMoveToPoint(context, start, floats[start]);
    }

    for (NSInteger i = start + 1; i < end; i++) {
        CGContextAddLineToPoint(context, i, floats[i]);
    }

    for (NSInteger i = end - 1; i >= start; i--) {
        CGContextAddLineToPoint(context, i, -floats[i]);
    }
    
    CGContextClosePath(context);

    NSColor *color = NULL;
    if (layer == _activeLayer) {
        color = _activeWaveformColor;
    } else {
        color = _inactiveWaveformColor;
    }

    CGContextSetFillColorWithColor(context, [color CGColor]);

    CGContextFillPath(context);
}


- (void) _worker_shrinkData:(TrackData *)trackData
{
    NSData   *inData = [trackData data];
    float    *input   = (float *)[inData bytes];
    NSInteger inCount = [inData length] / sizeof(float);

    NSInteger outCount = 32768;

    double stride = inCount / (double)outCount;
    
    float *output = malloc(outCount * sizeof(float));

    dispatch_apply(outCount, dispatch_get_global_queue(0, 0), ^(size_t o) {
        NSInteger i = llrintf(o * stride);

        // Just floor stride, this results in a skipped sample on occasion
        NSInteger length = (NSInteger)stride;
        
        // Be paranoid, I saw a crash in vDSP_maxv() during development
        if (i + length > inCount) {
            length = (inCount - i);
        }

        float max;
        vDSP_maxv(&input[i], 1, &max, length);
        
        output[o] = max;
    });
    
    
    NSData *data = [NSData dataWithBytesNoCopy:output length:(outCount * sizeof(float)) freeWhenDone:YES];

    __weak id weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf _didShrinkData:data];
    });
}


- (void) _didShrinkData:(NSData *)data
{
    _shrunkedData = data;
    
    [_activeLayer setNeedsDisplay];
    [_inactiveLayer setNeedsDisplay];
}


- (void) setTrack:(Track *)track
{
    if (_track != track) {
        _track = track;
        
        _trackData = [track trackData];

        __weak TrackData *weakTrackData = _trackData;
        __weak id weakSelf = self;

        [_trackData addReadyCallback:^(TrackData *track) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                [weakSelf _worker_shrinkData:weakTrackData];
            });
        }];
    }
}


- (void) setPercentage:(float)percentage
{
    if (_percentage != percentage) {
        _percentage = percentage;

        [_inactiveLayer setContentsRect:CGRectMake(_percentage, 0, 1.0 - _percentage, 1)];
        [_activeLayer   setContentsRect:CGRectMake(0, 0, _percentage, 1)];
    }
}

@end
