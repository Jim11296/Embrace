//
//  WaveformView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WaveformView.h"
#import "TrackAnalyzer.h"
#import "Track.h"

#import <Accelerate/Accelerate.h>


@implementation WaveformView {
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

        _activeWaveformColor = GetRGBColor(0x202020, 1.0);
        _inactiveWaveformColor = GetRGBColor(0xababab, 1.0);
    }
    
    return self;
}


- (void) dealloc
{
    [_track removeObserver:self forKeyPath:@"overviewData"];
}


- (BOOL) wantsUpdateLayer { return YES; }
- (void) updateLayer { }


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _track) {
        if ([keyPath isEqualToString:@"overviewData"]) {
            [_activeLayer   setNeedsDisplay];
            [_inactiveLayer setNeedsDisplay];
        }
    }
}


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


- (NSData *) _croppedDataForTrack:(Track *)track
{
    NSData *overviewData = [track overviewData];
    if (!overviewData) return nil;

    NSInteger inCount = [overviewData length] / sizeof(UInt8);
    UInt8    *inBytes = (UInt8 *)[overviewData bytes];
    
    NSTimeInterval startTime = [track startTime];
    NSTimeInterval stopTime  = [track stopTime];
    NSTimeInterval duration  = [track duration];
    
    NSInteger startOffset = 0;
    NSInteger stopOffset  = inCount;
    
    if (startTime) startOffset = round((startTime / duration) * inCount);
    if (stopTime)  stopOffset  = round((stopTime  / duration) * inCount);
    
    return [NSData dataWithBytes:(inBytes + startOffset) length:(stopOffset - startOffset)];
}


- (NSData *) _reduceOverviewDataForTrack:(Track *)track toCount:(NSUInteger)outCount
{
    NSData *data = [self _croppedDataForTrack:track];
    if (!data) return nil;

    NSInteger inCount = [data length] / sizeof(UInt8);
    UInt8 *inBytes = (UInt8 *)[data bytes];

    if (inCount < outCount) return data;

    UInt8 *outBytes = malloc(outCount * sizeof(UInt8));
    
    double stride = inCount / (double)outCount;

    dispatch_apply(outCount, dispatch_get_global_queue(0, 0), ^(size_t o) {
        NSInteger i = llrintf(o * stride);

        NSInteger length = (NSInteger)stride;
        
        // Be paranoid, I saw a crash in vDSP_maxv() during development
        if (i + length > inCount) {
            length = (inCount - i);
        }

        UInt8 max = 0;
        for (NSInteger j = 0; j < length; j++) {
            UInt8 m = inBytes[i + j];
            if (m > max) max = m;
        }
        
        outBytes[o] = max;
    });

    return [NSData dataWithBytesNoCopy:outBytes length:outCount * sizeof(UInt8) freeWhenDone:YES];
}


- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    if (![_track overviewData]) return;

    CGSize size = [self bounds].size;
    CGFloat scale = [[self window] backingScaleFactor];

    NSData *data = [self _reduceOverviewDataForTrack:_track toCount:size.width * scale];

    CGContextSetInterpolationQuality(context, kCGInterpolationLow);

    NSInteger sampleCount = [data length];
    NSInteger start = 0;
    NSInteger end = sampleCount;

    NSColor *color = NULL;
    if (layer == _activeLayer) {
        color = _activeWaveformColor;
    } else {
        color = _inactiveWaveformColor;
    }

    NSRect middleLineRect = CGRectMake(0, (size.height - 1) / 2, size.width, 1);
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, middleLineRect);

    CGAffineTransform transform = CGAffineTransformMakeScale(size.width / sampleCount, 1);

    transform = CGAffineTransformTranslate(transform, -start, 0);

    transform = CGAffineTransformTranslate(transform, 0, size.height / 2);
    transform = CGAffineTransformScale(transform, 1, size.height / (2 * 256));

    CGContextConcatCTM(context, transform);

    UInt8 *samples = (UInt8 *)[data bytes];

    if (start < end) {
        CGContextMoveToPoint(context, start, samples[start]);
    }

    for (NSInteger i = start + 1; i < end; i++) {
        CGContextAddLineToPoint(context, i, samples[i]);
    }

    for (NSInteger i = end - 1; i >= start; i--) {
        CGContextAddLineToPoint(context, i, -samples[i]);
    }
    
    CGContextClosePath(context);

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillPath(context);
}


- (void) setTrack:(Track *)track
{
    if (_track != track) {
        [_track removeObserver:self forKeyPath:@"overviewData"];
        _track = track;
        [_track addObserver:self forKeyPath:@"overviewData" options:0 context:NULL];

        [_activeLayer   setNeedsDisplay];
        [_inactiveLayer setNeedsDisplay];
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


- (void) setShowsDebugInformation:(BOOL)showsDebugInformation
{
    if (_showsDebugInformation != showsDebugInformation) {
        _showsDebugInformation = showsDebugInformation;
        [self setNeedsLayout:YES];
    }
}


@end
