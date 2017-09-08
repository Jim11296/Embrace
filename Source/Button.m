//
//  MainButton.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Button.h"
#import "NoDropImageView.h"

static CGFloat sBorderLayerPadding = 2;


@interface ButtonBorderView : NSView <CALayerDelegate> 
- (void) performAnimate:(BOOL)orderIn;
@end


@interface ButtonIconView : NSView <CALayerDelegate> 

- (void) _performOpenAnimationWithImage:(NSImage *)image tintColor:(NSColor *)tintColor;
- (void) _performPopAnimationWithImage:(NSImage *)image tintColor:(NSColor *)tintColor isPopIn:(BOOL)isPopIn;

@property (nonatomic, strong) NSColor *tintColor;
@property (nonatomic, strong) NSImage *image;

@end



@implementation Button {
    BOOL              _highlighted;
    ButtonIconView   *_iconView;
    ButtonBorderView *_borderView;
    NSImageView      *_backgroundView;
}


- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    [self _setupButton];
    return self;
}


- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [self _setupButton];
    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) _setupButton
{
    _alertColor       = GetRGBColor(0xff0000, 1.0);
    _alertActiveColor = GetRGBColor(0xc00000, 1.0);
    _normalColor      = GetRGBColor(0x737373, 1.0);
    _activeColor      = GetRGBColor(0x4c4c4c, 1.0);
    _inactiveColor    = GetRGBColor(0xb2b2b2, 1.0);
    _disabledColor    = GetRGBColor(0xb2b2b2, 1.0);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSWindowDidBecomeMainNotification        object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:NSApplicationDidResignActiveNotification object:nil];

    _backgroundView = [[NoDropImageView alloc] initWithFrame:[self bounds]];
    [self addSubview:_backgroundView];
    
    [_backgroundView setImage:[NSImage imageNamed:@"ButtonNormal"]];
    [_backgroundView setImageScaling:NSImageScaleNone];
    
    CGRect bounds = [self bounds];
    
    _iconView = [[ButtonIconView alloc] initWithFrame:bounds];
    [self addSubview:_iconView];

    [self setWantsLayer:YES];
    [[self layer] setMasksToBounds:NO];
    
    [self setButtonType:NSMomentaryChangeButton];
    
    [self _update:nil];
}


- (void) layout
{
    [super layout];
    [_iconView setFrame:[self bounds]];
}


- (void) mouseDown:(NSEvent *)theEvent
{
    _highlighted = YES;
    [self _update:nil];

    [super mouseDown:theEvent];

    _highlighted = NO;
    [self _update:nil];
}


- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self _update:nil];
}


- (void) windowDidUpdateMain:(NSWindow *)window
{
    [self _update:nil];
}


- (void) _update:(NSNotification *)note
{
    NSColor *color = _normalColor;

    BOOL isInactive = ![[self window] isMainWindow] || ![NSApp isActive];
    
    if (![self isEnabled]) {
        color = _disabledColor;

    } else if (isInactive) {
        color = _inactiveColor;

    } else if ([self isAlert]) {
        color = _highlighted ? _alertActiveColor : _alertColor;

    } else if (_highlighted) {
        color = _activeColor;
    }

    [_iconView setImage:[self image]];
    [_iconView setTintColor:color];
    
    if (isInactive) {
        [_backgroundView setImage:[NSImage imageNamed:@"ButtonInactive"]];
    } else if (_highlighted) {
        [_backgroundView setImage:[NSImage imageNamed:@"ButtonPressed"]];
    } else {
        [_backgroundView setImage:[NSImage imageNamed:@"ButtonNormal"]];
    }

    [_backgroundView setHidden:_iconOnly];
}


- (void) setEnabled:(BOOL)flag
{
    [super setEnabled:flag];
    [self _update:nil];
}


- (void) drawRect:(NSRect)dirtyRect
{ }


- (void) setAlert:(BOOL)alert
{
    if (_alert != alert) {
        _alert = alert;
        [self _update:nil];
    }
}


- (void) setAlertColor:(NSColor *)alertColor
{
    if (_alertColor != alertColor) {
        _alertColor = alertColor;
        [self _update:nil];
    }
}


- (void) setIconOnly:(BOOL)iconOnly
{
    if (_iconOnly != iconOnly) {
        _iconOnly = iconOnly;
        [self _update:nil];
    }
}


- (void) performOpenAnimationToImage:(NSImage *)image enabled:(BOOL)enabled
{
    [_iconView _performOpenAnimationWithImage:image tintColor:(enabled ? _normalColor : _inactiveColor)];
}


- (void) performPopAnimation:(BOOL)isPopIn toImage:(NSImage *)image alert:(BOOL)alert
{
    [_iconView _performPopAnimationWithImage:image tintColor:(alert ? _alertColor : _normalColor) isPopIn:isPopIn];
}


- (void) setOutlined:(BOOL)outlined
{
    if (outlined != _outlined) {
        if (outlined && !_borderView) {
            _borderView = [[ButtonBorderView alloc] initWithFrame:[self bounds]];
            [self addSubview:_borderView];
        }
    
        _outlined = outlined;
        [_borderView performAnimate:outlined];
    }
}

- (void) setImage:(NSImage *)image
{
    [super setImage:image];
    [self _update:nil];
}


@end


@implementation ButtonBorderView {
    CALayer *_mainLayer;
}


- (id) initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _mainLayer = [CALayer layer];
        
        [_mainLayer setMasksToBounds:NO];
        [_mainLayer setDelegate:self];

        [self setWantsLayer:YES];
        [self setLayer:[CALayer layer]];
        [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawNever];

        CALayer *selfLayer = [self layer];

        [selfLayer setMasksToBounds:NO];
        [selfLayer addSublayer:_mainLayer];
    }

    return self;
}


- (void) layout
{
    [super layout];
    [_mainLayer setFrame:CGRectInset([self bounds], -sBorderLayerPadding, -sBorderLayerPadding)];
}


- (BOOL) wantsUpdateLayer
{
    return YES;
}


- (void) performAnimate:(BOOL)orderIn
{
    CABasicAnimation *frameAnimation   = [CABasicAnimation animationWithKeyPath:@"bounds"];
    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];

    CGRect bounds = [self bounds];
    CGRect outRect = CGRectInset(bounds, -8, -8);
    CGRect inRect  = CGRectInset(bounds, -sBorderLayerPadding, -sBorderLayerPadding);

    CGFloat duration = 0.2;

    [opacityAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];

    if (orderIn) {
        [opacityAnimation setFromValue:@0.0];
        [opacityAnimation setToValue:@1.0];

        [frameAnimation setFromValue:[NSValue valueWithRect:outRect]];
        [frameAnimation setToValue:  [NSValue valueWithRect:inRect]];

        [frameAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

        [frameAnimation setDuration:duration];
        [opacityAnimation setDuration:duration];

        [_mainLayer setOpacity:1];

    } else {
        CALayer *presentationLayer = [_mainLayer presentationLayer];

        CGFloat currentOpacity = [presentationLayer opacity];
        CGRect  currentBounds  = [presentationLayer bounds];
        
        duration = duration - ((1.0 - currentOpacity) * duration);

        [opacityAnimation setFromValue:@(currentOpacity)];
        [opacityAnimation setToValue:@0.0];

        [frameAnimation setFromValue:[NSValue valueWithRect:currentBounds]];
        [frameAnimation setToValue:[NSValue valueWithRect:outRect]];
        [frameAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];

        [frameAnimation   setDuration:duration];
        [opacityAnimation setDuration:duration];
        
        [_mainLayer setOpacity:0];
    }
    
    [_mainLayer addAnimation:frameAnimation   forKey:@"frame"];
    [_mainLayer addAnimation:opacityAnimation forKey:@"opacity"];
}



- (void) updateLayer { }


- (void) _updateMainLayerContentsWithScale:(CGFloat)scale
{
    CGSize imageSize = CGSizeMake(32, 32);

    CGImageRef mainImage = CreateImage(imageSize, NO, scale, ^(CGContextRef context) {
        NSRect bounds = CGRectMake(0, 0, 32, 32);
        bounds = CGRectInset(bounds, sBorderLayerPadding + 1, sBorderLayerPadding + 1);
        
        [GetRGBColor(0x1866e9, 1.0) set];
        
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:3.5 yRadius:3.5];
        [path setLineWidth:2];
        [path stroke];
    });

    [_mainLayer setContents:(__bridge id)mainImage];
    [_mainLayer setContentsCenter:CGRectMake(0.5, 0.5, 0, 0)];
    [_mainLayer setContentsScale:scale];

    CGImageRelease(mainImage);

}


- (void) viewDidMoveToWindow
{
    [self _updateMainLayerContentsWithScale:[[self window] backingScaleFactor]];
}


- (BOOL) layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
    if (layer == _mainLayer) {
        [self _updateMainLayerContentsWithScale:newScale];
    }

    return NO;
}


@end



@implementation ButtonIconView {
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
        [_auxLayer  setMasksToBounds:NO];

        [_mainLayer setDelegate:self];
        [_auxLayer  setDelegate:self];
        
        [_mainLayer setContentsGravity:kCAGravityLeft];
        [_auxLayer  setContentsGravity:kCAGravityLeft];
        
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


- (void) _inheritContentsScaleFromWindow:(NSWindow *)window
{
    CGFloat scale = [window backingScaleFactor];
    
    if (scale) {
        [_mainLayer setContentsScale:scale];
        [_auxLayer  setContentsScale:scale];
    }
}


- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
    if (layer == _mainLayer) {
        [self _drawLayer:layer image:_image color:_tintColor inContext:ctx];
    
    } else if (layer == _auxLayer) {
        [self _drawLayer:layer image:_auxImage color:_auxColor inContext:ctx];
    }
}


- (void) viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self _inheritContentsScaleFromWindow:[self window]];
}


- (BOOL) layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
    [self _inheritContentsScaleFromWindow:window];
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


- (void) _performPopAnimationWithImage:(NSImage *)image tintColor:(NSColor *)tintColor isPopIn:(BOOL)isPopIn
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
