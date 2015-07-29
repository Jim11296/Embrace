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
        
        [_mainLayer    setMasksToBounds:NO];
        [_auxLayer     setMasksToBounds:NO];

        [_mainLayer    setDelegate:self];
        [_auxLayer     setDelegate:self];
        
        [_mainLayer    setContentsGravity:kCAGravityLeft];
        [_auxLayer     setContentsGravity:kCAGravityLeft];
        
        [_mainLayer setNeedsDisplayOnBoundsChange:YES];
        [_auxLayer  setNeedsDisplayOnBoundsChange:YES];
        
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
    
    NSRect mainFrame = bounds;
    NSRect auxFrame  = bounds;
    
    mainFrame.size = _image ? [_image size] : NSZeroSize;
    mainFrame.origin.x = round((bounds.size.width  - mainFrame.size.width)  / 2);
    mainFrame.origin.y = round((bounds.size.height - mainFrame.size.height) / 2);
    
    [_mainLayer setFrame:mainFrame];

    auxFrame.size = _auxImage ? [_auxImage size] : NSZeroSize;
    auxFrame.origin.x = round((bounds.size.width  - auxFrame.size.width)  / 2);
    auxFrame.origin.y = round((bounds.size.height - auxFrame.size.height) / 2);

    [_auxLayer setFrame:auxFrame];
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
    NSRectFillUsingOperation(bounds, NSCompositeSourceIn);
    
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


- (NSImage *) _imageWithImage:(NSImage *)image tintColor:(NSColor *)tintColor
{
    NSSize size = [image size];
    NSImage *result = [[NSImage alloc] initWithSize:size];
    
    [result lockFocus];

    NSRect rect = NSZeroRect;
    rect.size = size;

    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1 respectFlipped:YES hints:nil];
    
    [tintColor set];
    NSRectFillUsingOperation(rect, NSCompositeSourceIn);
    
    [result unlockFocus];
    
    return result;
}


- (void) _performSubtlePopAnimationWithImage:(NSImage *)image tintColor:(NSColor *)tintColor isPopIn:(BOOL)isPopIn
{
    CABasicAnimation    *contentsAnimation  = [CABasicAnimation    animationWithKeyPath:@"contents"];
    CAKeyframeAnimation *transformAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];

    CABasicAnimation    *mainHiddenAnimation = [CABasicAnimation animationWithKeyPath:@"hidden"];
    CABasicAnimation    *auxHiddenAnimation  = [CABasicAnimation animationWithKeyPath:@"hidden"];
    
    [mainHiddenAnimation setFromValue:@YES];
    [mainHiddenAnimation setToValue:@YES];

    [auxHiddenAnimation setFromValue:@NO];
    [auxHiddenAnimation setToValue:@NO];

    [contentsAnimation setFromValue:[self _imageWithImage:[self image] tintColor:[self tintColor]]];
    [contentsAnimation setToValue:  [self _imageWithImage:image        tintColor:tintColor]];

    CATransform3D popTransform = CATransform3DIdentity;
    
    if (isPopIn) {
        NSPoint globalPoint = [NSEvent mouseLocation];
    
        NSRect  globalRect  = NSMakeRect(globalPoint.x, globalPoint.y, 0, 0);
        
        NSRect  windowRect = [[self window] convertRectFromScreen:globalRect];
        NSPoint windowPoint = windowRect.origin;

        NSPoint locationInSelf = [self convertPoint:windowPoint fromView:nil];
        CGFloat jumpY = ceil(locationInSelf.y);

        if (jumpY <  0) jumpY = 0;
        if (jumpY > 14) jumpY = 14;

        if (!NSPointInRect(locationInSelf, [self bounds])) {
            jumpY = 0;
        }
        
        CGFloat scale  = isPopIn ? 1.5  : 1;
        popTransform = CATransform3DRotate(popTransform, 0.01 * M_PI, 0, 0, 1);
        popTransform = CATransform3DScale(popTransform, scale, scale, 1);
        popTransform = CATransform3DTranslate(popTransform, 0, jumpY + 2, 1);
    }

    [transformAnimation setValues:@[
        [NSValue valueWithCATransform3D:CATransform3DMakeScale(1, 1, 1)],
        [NSValue valueWithCATransform3D:popTransform],
        [NSValue valueWithCATransform3D:CATransform3DMakeScale(1, 1, 1)],
    ]];
    
    [transformAnimation setTimingFunctions:@[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
    ]];

    [transformAnimation setKeyTimes:@[ @0, @0.5, @1.0 ] ];
    [contentsAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];

    _auxImage = [self image];
    [[self layer] addSublayer:_auxLayer];
    
    [_auxLayer addAnimation:transformAnimation forKey:@"transform"];
    [_auxLayer addAnimation:contentsAnimation  forKey:@"contents"];
    
    [_mainLayer addAnimation:mainHiddenAnimation forKey:@"hidden"];
    [_auxLayer  addAnimation:auxHiddenAnimation  forKey:@"hidden"];
}


- (void) _performOpenAnimationWithImage:(NSImage *)image tintColor:(NSColor *)tintColor
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


- (void) performAnimation:(MainIconAnimation)animation image:(NSImage *)image tintColor:(NSColor *)tintColor
{
    if (animation == MainIconAnimationTypeOpen) {
        [self _performOpenAnimationWithImage:image tintColor:tintColor];
    } else {
        [self _performSubtlePopAnimationWithImage:image tintColor:tintColor isPopIn:(animation == MainIconAnimationTypeSubtlePopIn)];
    }
}


- (void) doEnableAnimationFromTintColor:(NSColor *)fromColor toColor:(NSColor *)toColor
{
    _auxImage = [self image];
    _auxColor = fromColor;
    [_auxLayer setNeedsDisplay];

    [self setTintColor:toColor];

    [[self layer] addSublayer:_auxLayer];
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


- (void) setWiggling:(BOOL)wiggling
{
    if (_wiggling != wiggling) {
        _wiggling = wiggling;

        if (!wiggling) {
            [_mainLayer removeAnimationForKey:@"wiggling"];
        } else {
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
            
            CGAffineTransform from = CGAffineTransformMakeScale(1,   1);
            CGAffineTransform to   = CGAffineTransformMakeScale(0.9, 0.95);
            
           
            
            [animation setFromValue:[NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(from)]];
            [animation setToValue:[NSValue valueWithCATransform3D:CATransform3DMakeAffineTransform(to)]];
            
            [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [animation setRepeatCount:INFINITY];
            [animation setAutoreverses:YES];
            [animation setDuration:0.1];
            
            [_mainLayer addAnimation:animation forKey:@"wiggling"];
        }
    }
}


@end
