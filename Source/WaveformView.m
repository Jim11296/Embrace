//
//  WaveformView.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "WaveformView.h"
#import "Waveform.h"


@implementation WaveformView {
    Waveform *_waveform;
    CGPathRef _topPath;
    CGPathRef _bottomPath;
    NSInteger _count;
}



- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) drawRect:(CGRect)rect
{
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];

    CGRect bounds = [self bounds];


    [GetRGBColor(0x0, 0.15) set];
    
    CGAffineTransform transform = CGAffineTransformMakeScale(bounds.size.width / (double)_count, 1);
    transform = CGAffineTransformTranslate(transform, 0, bounds.size.height / 2);
    transform = CGAffineTransformScale(transform, 1, bounds.size.height / 2);
    
    CGPathRef scaledTopPath    = CGPathCreateCopyByTransformingPath(_topPath,    &transform);
    CGPathRef scaledBottomPath = CGPathCreateCopyByTransformingPath(_bottomPath, &transform);
    
    if (scaledTopPath) {
        CGContextAddPath(context, scaledTopPath);
        CGPathRelease(scaledTopPath);
    }

    if (scaledBottomPath) {
        CGContextAddPath(context, scaledBottomPath);
        CGPathRelease(scaledBottomPath);
    }

    CGContextFillPath(context);
}

- (void) _update:(id)sender
{
    if (![_waveform mins]) {
        return;
    }

    CGMutablePathRef topPath    = CGPathCreateMutable();
    CGMutablePathRef bottomPath = CGPathCreateMutable();
    
    CGPathMoveToPoint(topPath, &CGAffineTransformIdentity, 0, 0);
    CGPathMoveToPoint(bottomPath, &CGAffineTransformIdentity, 0, 0);
    
    NSEnumerator *mins = [[_waveform mins] objectEnumerator];
    NSEnumerator *maxs = [[_waveform maxs] objectEnumerator];
    
    _count = [[_waveform mins] count];

    for (NSInteger i = 0; i < _count; i++) {
        CGFloat min = [[mins nextObject] doubleValue];
        CGFloat max = [[maxs nextObject] doubleValue];

        CGPathAddLineToPoint(topPath,    &CGAffineTransformIdentity, i, min);
        CGPathAddLineToPoint(bottomPath, &CGAffineTransformIdentity, i, max);
    
    }
    
    CGPathRelease(_topPath);
    CGPathRelease(_bottomPath);

    CGPathCloseSubpath(topPath);
    CGPathCloseSubpath(bottomPath);

    _topPath = topPath;
    _bottomPath = bottomPath;
    
    CGPathRetain(_topPath);
    CGPathRetain(_bottomPath);
    
    [self setNeedsDisplay:YES];
}


- (void) setWaveform:(Waveform *)waveform
{
    if (_waveform != waveform) {
        _waveform = waveform;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:WaveformDidFinishAnalysisNotificationName object:nil];
        [self _update:nil];
    }
}


@end
