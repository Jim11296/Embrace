// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "WaveformView.h"
#import "Track.h"

#import <Accelerate/Accelerate.h>

@interface WaveformView () <NSViewLayerContentScaleDelegate>
@end


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

        _activeWaveformColor   = [NSColor labelColor];
        _inactiveWaveformColor = [NSColor secondaryLabelColor];

        [self setPercentage:FLT_EPSILON];
    }
    
    return self;
}


- (void) dealloc
{
    [_track removeObserver:self forKeyPath:@"overviewData"];
}


- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    
    [self _inheritContentsScaleFromWindow:[self window]];

    [_activeLayer setNeedsDisplay];
    [_inactiveLayer setNeedsDisplay];
}

- (BOOL) allowsVibrancy
{
    return YES;
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
    [self _inheritContentsScaleFromWindow:window];
    return YES;
}


- (void) _inheritContentsScaleFromWindow:(NSWindow *)window
{
    CGFloat contentsScale = [window backingScaleFactor];

    if (contentsScale) {
        [_inactiveLayer setContentsScale:contentsScale];
        [_activeLayer   setContentsScale:contentsScale];

        [_inactiveLayer setNeedsDisplay];
        [_activeLayer   setNeedsDisplay];
    }
}


- (NSData *) _croppedDataForTrack:(Track *)track
{
    NSData *overviewData = [track overviewData];
    if (!overviewData) return nil;

    NSInteger inCount = [overviewData length] / sizeof(UInt8);
    UInt8    *inBytes = (UInt8 *)[overviewData bytes];
    
    NSTimeInterval startTime = [track startTime];
    NSTimeInterval stopTime  = [track stopTime];
   
    NSInteger startOffset = 0;
    NSInteger stopOffset  = inCount;
   
    if (startTime || stopTime) {
        NSTimeInterval duration = [track decodedDuration];
        if (!duration) duration = [track duration];
        if (!duration) return nil;
    
        if (startTime) startOffset = round((startTime / duration) * inCount);
        if (stopTime)  stopOffset  = round((stopTime  / duration) * inCount);
    }
    
    if (startOffset < 0)       startOffset = 0;
    if (startOffset > inCount) startOffset = inCount;

    if (stopOffset < 0)       stopOffset = 0;
    if (stopOffset > inCount) stopOffset = inCount; 
    
    NSInteger length = (stopOffset - startOffset);
    if (length < 0) return nil;
     
    return [NSData dataWithBytes:(inBytes + startOffset) length:length];
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
    vDSP_Length length = [data length];

    if (length == 0) return;

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

//    NSRect middleLineRect = CGRectMake(0, (size.height - 1) / 2, size.width, 1);
//    CGContextSetFillColorWithColor(context, [color CGColor]);
//    CGContextFillRect(context, middleLineRect);

    CGAffineTransform transform = CGAffineTransformMakeScale(size.width / sampleCount, 1);

    transform = CGAffineTransformTranslate(transform, -start, 0);
    transform = CGAffineTransformTranslate(transform, 0, size.height / 2);

    CGContextConcatCTM(context, transform);

    UInt8 *byteSamples  = (UInt8 *)[data bytes];
    float *floatSamples = malloc(length * sizeof(float));
    
    vDSP_vfltu8(byteSamples, 1, floatSamples, 1, length);

    float scalar = size.height / (2 * 256);
    vDSP_vsmul(floatSamples, 1, &scalar, floatSamples, 1, length);

    CGFloat min = 1.0 / scale;

    for (NSInteger i = 0; i < end; i++) {
        CGFloat s = floatSamples[i];
        if (s < min) s = min;
        floatSamples[i] = s;
    }

    if (start < end) {
        CGContextMoveToPoint(context, start, floatSamples[start]);
    }
    
    for (NSInteger i = start + 1; i < end; i++) {
        CGContextAddLineToPoint(context, i, floatSamples[i]);
    }

    for (NSInteger i = end - 1; i >= start; i--) {
        CGContextAddLineToPoint(context, i, -floatSamples[i]);
    }
    
    free(floatSamples);
    
    CGContextClosePath(context);

    PerformWithAppearance([self effectiveAppearance], ^{
        CGContextSetFillColorWithColor(context, [color CGColor]);
    });

    CGContextFillPath(context);
}


- (void) setTrack:(Track *)track
{
    if (_track != track) {
        [_track removeObserver:self forKeyPath:@"overviewData"];
        _track = track;
        [_track addObserver:self forKeyPath:@"overviewData" options:0 context:NULL];

        [self setPercentage:FLT_EPSILON];

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


- (void) setInactiveWaveformColor:(NSColor *)color
{
    if (_inactiveWaveformColor != color) {
        _inactiveWaveformColor = color;
        
        [_activeLayer   setNeedsDisplay];
        [_inactiveLayer setNeedsDisplay];
    }
}


- (void) setActiveWaveformColor:(NSColor *)color
{
    if (_activeWaveformColor != color) {
        _activeWaveformColor = color;
        
        [_activeLayer   setNeedsDisplay];
        [_inactiveLayer setNeedsDisplay];
    }
}


- (void) redisplay
{
    [_activeLayer   setNeedsDisplay];
    [_inactiveLayer setNeedsDisplay];
}


@end
