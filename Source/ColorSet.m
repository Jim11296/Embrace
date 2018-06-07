//
//  Color.m
//  Embrace
//
//  Created by Ricci Adams on 2018-06-06.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "ColorSet.h"

@implementation ColorSet {
    NSMutableDictionary *_colorMap;
}


- (instancetype) init
{
    if ((self = [super init])) {
        _colorMap = [NSMutableDictionary dictionary];
    }
    
    return self;
}


- (void) addColor:(NSColor *)color forAppearanceName:(NSAppearanceName)appearanceName
{
    if (!appearanceName) return;
    [_colorMap setObject:color forKey:appearanceName];
}


- (NSColor *) _currentColor
{
    NSAppearance *appearance = [NSAppearance currentAppearance];
    
    if (@available(macOS 10.14, *)) {
        NSAppearanceName bestMatch = [appearance bestMatchFromAppearancesWithNames:[_colorMap allKeys]];
        return [_colorMap objectForKey:bestMatch];
        
    } else {
        return [_colorMap objectForKey:NSAppearanceNameAqua];
    }
}


#pragma mark - Proxy

- (NSColorSpace *) colorSpace         { return [[self _currentColor] colorSpace];          }
- (NSColorType) type                  { return [[self _currentColor] type];                }
- (NSInteger) numberOfComponents      { return [[self _currentColor] numberOfComponents];  }

- (CGFloat) redComponent              { return [[self _currentColor] redComponent];        }
- (CGFloat) greenComponent            { return [[self _currentColor] greenComponent];      }
- (CGFloat) blueComponent             { return [[self _currentColor] blueComponent];       }

- (CGFloat) hueComponent              { return [[self _currentColor] hueComponent];        }
- (CGFloat) saturationComponent       { return [[self _currentColor] saturationComponent]; }
- (CGFloat) brightnessComponent       { return [[self _currentColor] blueComponent];       }

- (CGFloat) whiteComponent            { return [[self _currentColor] whiteComponent];      }

- (CGFloat) alphaComponent            { return [[self _currentColor] alphaComponent];      }

- (void) set       { [[self _currentColor] set];       }
- (void) setFill   { [[self _currentColor] setFill];   }
- (void) setStroke { [[self _currentColor] setStroke]; }


- (void) getComponents:(CGFloat *)components
{
    [[self _currentColor] getComponents:components];
}


- (NSColor *) colorUsingType:(NSColorType)type
{
    return [[self _currentColor] colorUsingType:type];
}


- (NSColor *) colorUsingColorSpace:(NSColorSpace *)space
{
    return [[self _currentColor] colorUsingColorSpace:space];
}


- (NSColor *) colorUsingColorSpaceName:(NSColorSpaceName)name device:(NSDictionary<NSDeviceDescriptionKey, id> *)deviceDescription
{
    return [[self _currentColor] colorUsingColorSpaceName:name device:deviceDescription];
}


- (NSColor *) colorUsingColorSpaceName:(NSColorSpaceName)name
{
    return [[self _currentColor] colorUsingColorSpaceName:name];
}


- (void) getRed:(CGFloat *)r green:(CGFloat *)g blue:(CGFloat *)b alpha:(CGFloat *)a
{
    [[self _currentColor] getRed:r green:g blue:b alpha:a];
}


- (void) getHue:(CGFloat *)h saturation:(CGFloat *)s brightness:(CGFloat *)b alpha:(CGFloat *)a
{
    [[self _currentColor] getHue:h saturation:s brightness:b alpha:a];
}


- (void) getWhite:(nullable CGFloat *)w alpha:(nullable CGFloat *)a
{
    [[self _currentColor] getWhite:w alpha:a];
}


- (NSColor *) colorWithAlphaComponent:(CGFloat)alpha
{
    return [[self _currentColor] colorWithAlphaComponent:alpha];
}


@end
