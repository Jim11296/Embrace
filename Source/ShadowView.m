//
//  ShadowView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-01.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "ShadowView.h"

@implementation ShadowView {
    BOOL _flipped;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
    NSShadow *shadow = [[NSShadow alloc] init];
    
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.15]];
    [shadow setShadowBlurRadius:1];

    NSRect rect = [self bounds];
    
    if (_flipped) {
        [shadow setShadowOffset:NSMakeSize(0, 1)];
        rect.origin.y = rect.size.height;

    } else {
        [shadow setShadowOffset:NSMakeSize(0, -1)];
        rect.origin.y += rect.size.height;
    }

    NSGradient *gradient = [[NSGradient alloc] initWithColors:@[
        [NSColor clearColor],
        [NSColor blackColor],
        [NSColor clearColor]
    ]];

    [shadow set];
    
    NSRectFill(rect);
    
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
    
    [gradient drawInRect:[self bounds] angle:0];
}


- (void) setFlipped:(BOOL)flipped
{
    if (_flipped != flipped) {
        _flipped = flipped;
        [self setNeedsDisplay:YES];
    }
}


- (BOOL) isFlipped
{
    return _flipped;
}


@end
