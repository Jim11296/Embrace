//
//  MainButton.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "MainIconView.h"

@implementation MainIconView {
    BOOL _highlighted;
    
    CALayer *_mainLayer;

    CALayer *_auxLayer;
    NSImage *_auxImage;
    NSColor *_auxColor;
}

- (id) initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _mainLayer = [CALayer layer];
        _auxLayer  = [CALayer layer];
        
        [_mainLayer setMasksToBounds:NO];
        [_auxLayer setMasksToBounds:NO];

        [_mainLayer setDelegate:self];
        [_auxLayer  setDelegate:self];
        
        [_mainLayer setContentsGravity:kCAGravityLeft];
        [_auxLayer  setContentsGravity:kCAGravityLeft];
        
        [_auxLayer setDoubleSided:NO];
        [_mainLayer setDoubleSided:NO];
        
        [_auxLayer setHidden:YES];

        [self setWantsLayer:YES];
        [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];
        
        [[self layer] addSublayer:_mainLayer];
        [[self layer] setMasksToBounds:NO];
    }

    return self;
}


- (BOOL) wantsUpdateLayer
{
    return YES;
}


- (void) updateLayer { }


- (void) layout
{
    [super layout];
    
    NSRect bounds = [self bounds];
    
    bounds.size = _image ? [_image size] : NSZeroSize;
    [_mainLayer setFrame:bounds];

    bounds.size = _auxImage ? [_auxImage size] : NSZeroSize;
    [_auxLayer setFrame:bounds];
}


- (void) _drawLayer:(CALayer *)layer image:(NSImage *)image color:(NSColor *)color inContext:(CGContextRef)context
{
    NSGraphicsContext *oldContext = [NSGraphicsContext currentContext];
    
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO]];

    NSRect bounds = [layer bounds];
    
    NSRect rect = NSZeroRect;
    rect.size = [image size];
    rect.origin.x = 0;
    rect.origin.y = round((bounds.size.height - rect.size.height) / 2);
    
    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:YES hints:nil];
    
    [color set];
    NSRectFillUsingOperation([self bounds], NSCompositeSourceIn);
    
    [NSGraphicsContext setCurrentContext:oldContext];
}


- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    if (layer == _mainLayer) {
        [self _drawLayer:layer image:_image color:_tintColor inContext:ctx];
    
    } else if (layer == _auxLayer) {
        [self _drawLayer:layer image:_auxImage color:_auxColor inContext:ctx];
    }
}


- (BOOL) layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
    [_mainLayer setContentsScale:newScale];
    [_auxLayer  setContentsScale:newScale];

    return YES;
}



- (void) flipToImage:(NSImage *)image tintColor:(NSColor *)tintColor
{
    _auxImage = [self image];
    _auxColor = [self tintColor];
    [_auxLayer setNeedsDisplay];
    
    [self setImage:image];
    [self setTintColor:tintColor];

    [[self layer] addSublayer:_auxLayer];
    
    
    CABasicAnimation *auxTransformAnimation  = [CABasicAnimation animationWithKeyPath:@"transform"];
    CABasicAnimation *mainTransformAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];

    CABasicAnimation *auxOpacityAnimation  = [CABasicAnimation animationWithKeyPath:@"opacity"];
    CABasicAnimation *mainOpacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];

    CABasicAnimation *auxHiddenAnimation = [CABasicAnimation animationWithKeyPath:@"hidden"];

    [auxTransformAnimation  setFromValue:[NSValue valueWithCATransform3D:CATransform3DMakeScale(1,  1,  1)]];
    [auxTransformAnimation  setToValue:  [NSValue valueWithCATransform3D:CATransform3DMakeScale(3,  3,  1)]];
    [auxTransformAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];

    [mainTransformAnimation setFromValue:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.01,  0.01,  1)]];
    [mainTransformAnimation setToValue:  [NSValue valueWithCATransform3D:CATransform3DMakeScale(1,  1,  1)]];
    [mainTransformAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];

    [auxOpacityAnimation  setFromValue:@(1)];
    [auxOpacityAnimation  setToValue:  @(0)];
    
    [mainOpacityAnimation setFromValue:@(0)];
    [mainOpacityAnimation setToValue:  @(1)];
    
    [auxHiddenAnimation setFromValue:@NO];
    [auxHiddenAnimation setToValue:@NO];
    
    [_mainLayer addAnimation:mainTransformAnimation forKey:@"transform"];
    [_auxLayer  addAnimation:auxTransformAnimation  forKey:@"transform"];

    [_mainLayer addAnimation:mainOpacityAnimation forKey:@"opacity"];
    [_auxLayer  addAnimation:auxOpacityAnimation  forKey:@"opacity"];

    [_auxLayer  addAnimation:auxHiddenAnimation  forKey:@"hidden"];
}


- (void) setImage:(NSImage *)image
{
    if (_image != image) {
        _image = image;
        [self setNeedsLayout:YES];
        [_mainLayer setNeedsDisplay];
    }
}


- (void) setTintColor:(NSColor *)tintColor
{
    if (_tintColor != tintColor) {
        _tintColor = tintColor;
        [self setNeedsLayout:YES];
        [_mainLayer setNeedsDisplay];
    }
}

@end
