//
//  GradientView.m
//  Embrace
//
//  Created by Ricci Adams on 2016-12-10.
//  (c) 2016-2017 Ricci Adams. All rights reserved.
//

#import "MaskView.h"

@interface MaskColorView : NSView
@property (nonatomic, weak) MaskView *parentView;
@end


static void sDrawGradient(NSRect rect, NSColor *color, NSLayoutAttribute attribute, CGFloat length)
{
    if (!color) return;

    CGRect gradientRect = rect;
    CGRect solidRect    = rect;

    gradientRect.size.width = length;
    solidRect.size.width = rect.size.width - length;

    CGFloat angle = 0;

    if (attribute == NSLayoutAttributeRight) {
        gradientRect.origin.x += solidRect.size.width;
        angle = 180;

    } else {
        solidRect.origin.x += gradientRect.size.width;
        angle = 0;
    }

    [[[NSGradient alloc] initWithColors:@[
        [color colorWithAlphaComponent:0],
        color
    ]] drawInRect:gradientRect angle:angle];

    [color set];
    NSRectFill(solidRect);
}


@implementation MaskView {
    NSVisualEffectView *_effectView;
    MaskColorView *_colorView;
    NSImage *_maskImage;
}


- (instancetype) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self _commonContentBackgroundViewInit];
    }

    return self;
}


- (instancetype) initWithCoder:(NSCoder *)decoder
{
    if ((self = [super initWithCoder:decoder])) {
        [self _commonContentBackgroundViewInit];
    }

    return self;
}


- (void) _commonContentBackgroundViewInit
{
    _colorView = [[MaskColorView alloc] initWithFrame:[self bounds]];
    [_colorView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [_colorView setParentView:self];

    [self addSubview:_colorView];
}


- (void) _update
{
    if (_material) {
        if (!_effectView) {
            _effectView = [[NSVisualEffectView alloc] initWithFrame:[self bounds]];
            [_effectView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
            [self addSubview:_effectView positioned:NSWindowBelow relativeTo:_colorView];
        }
        
        if (!_maskImage) {
            if (_gradientLength) {
                NSLayoutAttribute attribute = _gradientLayoutAttribute;
                CGFloat           length    = _gradientLength;
                
                CGRect rect = CGRectMake(0, 0, length + 2, 8);

                CGImageRef cgImage = CreateImage(rect.size, NO, 1, ^(CGContextRef context) {
                    sDrawGradient(rect, [NSColor blackColor], attribute, length);
                });

                NSImage *maskImage = [[NSImage alloc] initWithCGImage:cgImage size:rect.size];
                
                if (attribute == NSLayoutAttributeLeft) {
                    [maskImage setCapInsets:NSEdgeInsetsMake(1, length, 1, 1)];
                } else {
                    [maskImage setCapInsets:NSEdgeInsetsMake(0, 1, 0, length)];
                }

                CGImageRelease(cgImage);

                [_effectView setMaskImage:maskImage];
                _maskImage = maskImage;

            } else {
                [_effectView setMaskImage:nil];
            }
        }

        [_effectView setHidden:NO];
        [_colorView setHidden:YES];

    } else {
        [_effectView setHidden:YES];
        [_colorView setHidden:NO];
        [_colorView setNeedsDisplay:YES];
    }
}


- (void) setMaterial:(NSVisualEffectMaterial)material
{
    if (_material != material) {
        _material = material;
        [self _update];
    }
}


- (void) setColor:(NSColor *)color
{
    if (_color != color) {
        _color = color;
        [self _update];
    }
}


- (void) setGradientLength:(CGFloat)gradientLength
{
    if (_gradientLength != gradientLength) {
        _gradientLength = gradientLength;
        _maskImage = nil;
        [self _update];
    }
}


- (void) setGradientLayoutAttribute:(NSLayoutAttribute)gradientLayoutAttribute
{
    if (_gradientLayoutAttribute != gradientLayoutAttribute) {
        _gradientLayoutAttribute = gradientLayoutAttribute;
        _maskImage = nil;
        [self _update];
    }
}


@end



@implementation MaskColorView

- (void) drawRect:(NSRect)dirtyRect
{
    MaskView *parentView = [self parentView];

    sDrawGradient(
        [self bounds],
        [parentView color],
        [parentView gradientLayoutAttribute],
        [parentView gradientLength]
    );
}

@end

