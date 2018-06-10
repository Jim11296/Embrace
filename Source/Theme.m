//
//  Theme.m
//  Embrace
//
//  Created by Ricci Adams on 2018-06-06.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "Theme.h"

static NSDictionary *sColorMap  = nil;
static NSDictionary *sShadowMap = nil;



static NSColor *sRGBA(int rgb, CGFloat alpha)
{
#if 0
    return GetRGBColor(0xFFFFFF - rgb, alpha);
#else
    return GetRGBColor(rgb, alpha);
#endif
}


static NSShadow *sShadow(CGFloat alpha, CGFloat yOffset, CGFloat blurRadius)
{
    NSShadow *shadow = [[NSShadow alloc] init];
    
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:alpha]];
    [shadow setShadowOffset:NSMakeSize(0, -yOffset)];
    [shadow setShadowBlurRadius:blurRadius];

    return shadow;
}

static NSColor *sRGB(int rgb)
{
    return sRGBA(rgb, 1.0);
}



static NSColor *sDualRGB(int lightRGB, int darkRGB)
{
    return sRGB(lightRGB);
}


@implementation Theme

+ (void) initialize
{
    NSMutableDictionary *colorMap  = [NSMutableDictionary dictionary];
    NSMutableDictionary *shadowMap = [NSMutableDictionary dictionary];

    [colorMap addEntriesFromDictionary:@{
//        @"MeterPeak":       sRGB(0xFF0000),
//        @"MeterDot":        sRGB(0x000000),
//        @"MeterActiveMain": sRGB(0x707070),
//        @"MeterActive":     sRGB(0xA0A0A0),
//        @"MeterInactive":   sRGBA(0x000000, 0.15),

//        @"LabelMenuRingBorder":     sRGBA( 0x808080, 1.0 ),
//        @"LabelMenuRingFill":       sRGBA( 0x808080, 0.2 ),
//        
//        @"LabelMenuRedBorder":      sRGB( 0xff3830 ),
//        @"LabelMenuOrangeBorder":   sRGB( 0xf89000 ),
//        @"LabelMenuYellowBorder":   sRGB( 0xfed647 ),
//        @"LabelMenuGreenBorder":    sRGB( 0x3ec01d ),
//        @"LabelMenuBlueBorder":     sRGB( 0x20a9f1 ),
//        @"LabelMenuPurpleBorder":   sRGB( 0xc869da ),
//
//        @"LabelMenuRedFill":        sRGB( 0xff625c ),
//        @"LabelMenuOrangeFill":     sRGB( 0xffaa47 ),
//        @"LabelMenuYellowFill":     sRGB( 0xffd64b ),
//        @"LabelMenuGreenFill":      sRGB( 0x83e163 ),
//        @"LabelMenuBlueFill":       sRGB( 0x4ebdfa ),
//        @"LabelMenuPurpleFill":     sRGB( 0xd68fe7 ),
//
//        @"SetlistLabelBorderRed":       sRGB( 0xff4439 ),
//        @"SetlistLabelBorderOrange":    sRGB( 0xff9500 ),
//        @"SetlistLabelBorderYellow":    sRGB( 0xffcc00 ),
//        @"SetlistLabelBorderGreen":     sRGB( 0x63da38 ),
//        @"SetlistLabelBorderBlue":      sRGB( 0x1badf8 ),
//        @"SetlistLabelBorderPurple":    sRGB( 0xcc73e1 ),
//
//        @"SetlistLabelFillRed":         sRGB( 0xff6259 ),
//        @"SetlistLabelFillOrange":      sRGB( 0xffaa33 ),
//        @"SetlistLabelFillYellow":      sRGB( 0xffd633 ),
//        @"SetlistLabelFillGreen":       sRGB( 0x82e15f ),
//        @"SetlistLabelFillBlue":        sRGB( 0x48bdf9 ),
//        @"SetlistLabelFillPurple":      sRGB( 0xd68fe7 ),

        @"SetlistSeparator":                 sRGBA(0x000000, 0.1),
        @"SetlistStopAfterPlayingStripe1":   sRGB(0xffd0d0),
        @"SetlistStopAfterPlayingStripe2":   sRGB(0xff0000),
        @"SetlistIgnoreAutoGapStripe":       sRGB(0x00cc00),

        @"SetlistTopTextSelectedMain":       sRGBA(0xffffff, 1.0),
        @"SetlistTopTextPlayingSelected":    sRGBA(0x000000, 1.0),
        @"SetlistTopTextPlaying":            sRGBA(0x1866e9, 1.0),
        @"SetlistTopTextPlayed":             sRGBA(0x000000, 0.5),
        @"SetlistTopText":                   sRGBA(0x000000, 1.0),

        @"SetlistBottomTextSelectedMain":    sRGBA(0xffffff, 0.66),
        @"SetlistBottomTextPlayingSelected": sRGBA(0x000000, 0.8),
        @"SetlistBottomTextPlaying":         sRGBA(0x1866e9, 0.4),
        @"SetlistBottomTextPlayed":          sRGBA(0x000000, 0.4),
        @"SetlistBottomText":                sRGBA(0x000000, 0.66),
        
        @"SetlistInactiveHighlight":         sRGB(0xdcdcdc),
        @"SetlistActiveHighlight":           sRGB(0x0065dc),

        @"EQTrack":               sRGBA(0x000000, 0.5),
        @"EQMajorTick":           sRGBA(0x000000, 0.4),
        @"EQMinorTick":           sRGBA(0x000000, 0.2)
    }];

    [colorMap addEntriesFromDictionary:@{
        @"ButtonAlert":       sRGB(0xff0000),
        @"ButtonAlertActive": sRGB(0xc00000),
        @"ButtonNormal":      sRGB(0x737373),
        @"ButtonActive":      sRGB(0x4c4c4c),
        @"ButtonInactive":    sRGBA(0x000000, 0.25),
        @"ButtonDisabled":    sRGBA(0x000000, 0.25),
        @"ButtonMainGlow":    sRGB(0x1866e9),
//        
//        @"KnobMainStart":     sRGB(0xffffff),
//        @"KnobMainEnd":       sRGB(0xf0f0f0),
//        @"KnobHighStart":     sRGB(0xf0f0f0),
//        @"KnobHighEnd":       sRGB(0xe0e0e0),
//        @"KnobStart":         sRGB(0xf6f6f6),
//        @"KnobEnd":           sRGB(0xf0f0f0)
    }];

#if TRIAL
    [colorMap addEntriesFromDictionary:@{
        @"TrialBorder":     sRGBA(0xB3CCFF, 1.0),
        @"TrialBackground": sRGBA(0xF2F7FF, 1.0),
        @"TrialLink"        sRGBA(0x1866E9, 1.0),
        @"TrialText"        sRGBA(0x0, 0.5)
    }];
#endif

    
    [shadowMap addEntriesFromDictionary:@{
        @"KnobMain1": sShadow( 0.4,  1, 2 ),
        @"KnobMain2": sShadow( 0.6,  0, 1 ),
        @"Knob":      sShadow( 0.45, 0, 1 )


    }];
        
    sColorMap  = colorMap;
    sShadowMap = shadowMap;
}

+ (NSColor *) colorNamed:(NSString *)colorName
{
    if (colorName) {
        NSColor *result = [sColorMap objectForKey:colorName];
        NSAssert(result, @"Unknown color name: %@", colorName);
        return result;
    }

    return nil;
}


+ (NSShadow *) shadowNamed:(NSString *)shadowName
{
    if (shadowName) {
        NSShadow *result = [sShadowMap objectForKey:shadowName];
        NSAssert(result, @"Unknown shadow name: %@", shadowName);
        return result;
    }

    return nil;
}


@end
