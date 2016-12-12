//
//  GradientView.m
//  Embrace
//
//  Created by Ricci Adams on 2016-12-10.
//  Copyright © 2016 Ricci Adams. All rights reserved.
//

#import "GradientView.h"

@implementation GradientView

- (void) drawRect:(NSRect)dirtyRect
{
    [_gradient drawInRect:[self bounds] angle:_angle];
}


- (void) setGradient:(NSGradient *)gradient
{
    if (_gradient != gradient) {
        _gradient = gradient;
        [self setNeedsDisplay:YES];
    }
}

- (void) setAngle:(CGFloat)angle
{
    if (_angle != angle) {
        _angle = angle;
        [self setNeedsDisplay:YES];
    }
}

@end
