// (c) 2018 Ricci Adams.  All rights reserved.

#import "Theme.h"
#import "ColorCompatibility.h"


@implementation Theme

+ (NSColor *) colorNamed:(NSString *)colorName
{
    NSColor *color = nil;

    if (colorName) {
        if (@available(macOS 10.13, *)) {
            color = [NSColor colorNamed:colorName];
        } else {
            color = GetCompatibilityColorNamed(colorName);
        }

        NSAssert(color, @"Unknown color name: %@", colorName);
    }

    return color;
}


@end
