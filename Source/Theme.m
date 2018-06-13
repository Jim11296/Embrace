//
//  Theme.m
//  Embrace
//
//  Created by Ricci Adams on 2018-06-06.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "Theme.h"
#import "ColorCompatibility.h"


static NSDictionary *sShadowMap = nil;


static NSShadow *sShadow(CGFloat alpha, CGFloat yOffset, CGFloat blurRadius)
{
    NSShadow *shadow = [[NSShadow alloc] init];
    
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:alpha]];
    [shadow setShadowOffset:NSMakeSize(0, -yOffset)];
    [shadow setShadowBlurRadius:blurRadius];

    return shadow;
}


@implementation Theme

+ (void) initialize
{
    NSMutableDictionary *shadowMap = [NSMutableDictionary dictionary];
    
    [shadowMap addEntriesFromDictionary:@{
        @"KnobMain1": sShadow( 0.4,  1, 2 ),
        @"KnobMain2": sShadow( 0.6,  0, 1 ),
        @"Knob":      sShadow( 0.45, 0, 1 )
    }];
        
    sShadowMap = shadowMap;
}


+ (NSColor *) colorNamed:(NSString *)colorName
{
    NSColor *color = nil;

    if (colorName) {
        if (@available(macOS 10.14, *)) {
            color = [NSColor colorNamed:colorName];
        } else {
            color = GetCompatibilityColorNamed(colorName);
        }

        NSAssert(color, @"Unknown color name: %@", colorName);
    }

    return color;
}


+ (NSShadow *) shadowNamed:(NSString *)shadowName
{
    NSShadow *shadow = nil;

    if (shadowName) {
        shadow = [sShadowMap objectForKey:shadowName];
        NSAssert(shadow, @"Unknown shadow name: %@", shadowName);
    }

    return shadow;
}


@end
