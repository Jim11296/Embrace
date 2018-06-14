//
//  SimpleProgressDot.m
//  Embrace
//
//  Created by Ricci Adams on 2017-06-25.
//  Copyright (c) 2017 Ricci Adams. All rights reserved.
//

#import "SimpleProgressDot.h"


@implementation SimpleProgressDot


- (BOOL) allowsVibrancy
{
    return YES;
}


- (void) drawRect:(NSRect)dirtyRect
{
    NSColor *fillColor = _inactiveColor;
    
    if (_activeColor) {
        fillColor = [fillColor blendedColorWithFraction:_percentage ofColor:_activeColor];
    }

    if (_tintColor) {
        fillColor = [fillColor blendedColorWithFraction:_tintLevel ofColor:_tintColor];
    }
    
    NSBezierPath *path = _path ? _path : [NSBezierPath bezierPathWithOvalInRect:[self bounds]];

    [fillColor set];
    [path fill];
    
}


- (void) setPath:(NSBezierPath *)path
{
    if (_path != path) {
        _path = path;
        [self setNeedsDisplay:YES];
    }
}


- (void) setInactiveColor:(NSColor *)inactiveColor
{
    if (_inactiveColor != inactiveColor) {
        _inactiveColor = inactiveColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setActiveColor:(NSColor *)activeColor
{
    if (_activeColor != activeColor) {
        _activeColor = activeColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setTintColor:(NSColor *)tintColor
{
    if (_tintColor != tintColor) {
        _tintColor = tintColor;
        [self setNeedsDisplay:YES];
    }
}



- (void) setPercentage:(CGFloat)percentage
{
    if (_percentage != percentage) {
        _percentage = percentage;
        [self setNeedsDisplay:YES];
    }
}


- (void) setTintLevel:(CGFloat)tintLevel
{
    if (_tintLevel != tintLevel) {
        _tintLevel = tintLevel;
        [self setNeedsDisplay:YES];
    }
}


@end
