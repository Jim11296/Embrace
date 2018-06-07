//
//  Theme.m
//  Embrace
//
//  Created by Ricci Adams on 2018-06-06.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import "Theme.h"

static NSDictionary *sColorMap = nil;



static NSColor *sRGBA(int rgb, CGFloat alpha)
{
#if DEBUG
    return GetRGBColor(0xFFFFFF - rgb, alpha);
#else
    return GetRGBColor(rgb, alpha);
#endif
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
    NSMutableDictionary *colorMap = [NSMutableDictionary dictionary];

    [colorMap addEntriesFromDictionary:@{
        @"SharedMeterPeak":       sRGB(0xFF0000),
        @"SharedMeterDot":        sRGB(0x000000),
        @"SharedMeterActiveMain": sRGB(0x707070),
        @"SharedMeterActive":     sRGB(0xA0A0A0),
        @"SharedMeterInactive":   sRGBA(0x000000, 0.15)
    }];

    [colorMap addEntriesFromDictionary:@{
        @"LabelMenuViewRingBorder":     sRGBA( 0x808080, 1.0 ),
        @"LabelMenuViewRingFill":       sRGBA( 0xff3830, 0.2 ),
        
        @"LabelMenuViewBorderRed":      sRGB( 0xff3830 ),
        @"LabelMenuViewBorderOrange":   sRGB( 0xf89000 ),
        @"LabelMenuViewBorderYellow":   sRGB( 0xfed647 ),
        @"LabelMenuViewBorderGreen":    sRGB( 0x3ec01d ),
        @"LabelMenuViewBorderBlue":     sRGB( 0x20a9f1 ),
        @"LabelMenuViewBorderPurple":   sRGB( 0xc869da ),

        @"LabelMenuViewFillRed":        sRGB( 0xff625c ),
        @"LabelMenuViewFillOrange":     sRGB( 0xffaa47 ),
        @"LabelMenuViewFillYellow":     sRGB( 0xffd64b ),
        @"LabelMenuViewFillGreen":      sRGB( 0x83e163 ),
        @"LabelMenuViewFillBlue":       sRGB( 0x4ebdfa ),
        @"LabelMenuViewFillPurple":     sRGB( 0xd68fe7 )
    }];        


    [colorMap addEntriesFromDictionary:@{
        @"LabelMenuViewRingBorder":     sRGBA( 0x808080, 1.0 ),
        @"LabelMenuViewRingFill":       sRGBA( 0x808080, 0.2 ),
        
        @"LabelMenuViewBorderRed":      sRGB( 0xff3830 ),
        @"LabelMenuViewBorderOrange":   sRGB( 0xf89000 ),
        @"LabelMenuViewBorderYellow":   sRGB( 0xfed647 ),
        @"LabelMenuViewBorderGreen":    sRGB( 0x3ec01d ),
        @"LabelMenuViewBorderBlue":     sRGB( 0x20a9f1 ),
        @"LabelMenuViewBorderPurple":   sRGB( 0xc869da ),

        @"LabelMenuViewFillRed":        sRGB( 0xff625c ),
        @"LabelMenuViewFillOrange":     sRGB( 0xffaa47 ),
        @"LabelMenuViewFillYellow":     sRGB( 0xffd64b ),
        @"LabelMenuViewFillGreen":      sRGB( 0x83e163 ),
        @"LabelMenuViewFillBlue":       sRGB( 0x4ebdfa ),
        @"LabelMenuViewFillPurple":     sRGB( 0xd68fe7 )
    }];

    [colorMap addEntriesFromDictionary:@{
        @"SetlistLabelBorderRed":       sRGB( 0xff4439 ),
        @"SetlistLabelBorderOrange":    sRGB( 0xff9500 ),
        @"SetlistLabelBorderYellow":    sRGB( 0xffcc00 ),
        @"SetlistLabelBorderGreen":     sRGB( 0x63da38 ),
        @"SetlistLabelBorderBlue":      sRGB( 0x1badf8 ),
        @"SetlistLabelBorderPurple":    sRGB( 0xcc73e1 ),

        @"SetlistLabelFillRed":         sRGB( 0xff6259 ),
        @"SetlistLabelFillOrange":      sRGB( 0xffaa33 ),
        @"SetlistLabelFillYellow":      sRGB( 0xffd633 ),
        @"SetlistLabelFillGreen":       sRGB( 0x82e15f ),
        @"SetlistLabelFillBlue":        sRGB( 0x48bdf9 ),
        @"SetlistLabelFillPurple":      sRGB( 0xd68fe7 )
    }];

    [colorMap addEntriesFromDictionary:@{
        @"TopHeaderGradientStart":           sRGB(0xececec),
        @"TopHeaderGradientEnd":             sRGB(0xd3d3d3),
        @"BottomHeaderGradientStart":        sRGB(0xe0e0e0),
        @"BottomHeaderGradientEnd":          sRGB(0xd3d3d3),
        @"HeaderInactiveBackground":         sRGB(0xf6f6f6),
        
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




        @"EQWindowGradientStart": sRGB(0xf0f0f0),
        @"EQWindowGradientEnd":   sRGB(0xd0d0d0),
        @"EQWindowInactive":      sRGB(0xf4f4f4),
        
        @"EQTrack":               sRGBA(0x000000, 0.5),
        @"EQMajorTick":           sRGBA(0x000000, 0.4),
        @"EQMinorTick":           sRGBA(0x000000, 0.2),

        @"EQKnob":                sRGB(0xffffff),
        @"EQKnobSelected":        sRGB(0xcccccc),
    }];

    [colorMap addEntriesFromDictionary:@{
        @"ButtonAlert":       sRGB(0xff0000),
        @"ButtonAlertActive": sRGB(0xc00000),
        @"ButtonNormal":      sRGB(0x737373),
        @"ButtonActive":      sRGB(0x4c4c4c),
        @"ButtonInactive":    sRGB(0xb2b2b2),
        @"ButtonDisabled":    sRGB(0xb2b2b2),
        @"ButtonMainGlow":    sRGB(0x1866e9)
    }];

#if TRIAL
    [colorMap addEntriesFromDictionary:@{
        @"TrialBorder":     sRGBA(0xB3CCFF, 1.0),
        @"TrialBackground": sRGBA(0xF2F7FF, 1.0),
        @"TrialLink"        sRGBA(0x1866E9, 1.0),
        @"TrialText"        sRGBA(0x0, 0.5)
    }];
#endif
        
    sColorMap = colorMap;
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



+ (NSColor *) contrastColor
{
    return sDualRGB(0x000000, 0xFFFFFF);
}


+ (NSColor *) halfwayColor
{
    return sRGB(0x808080);
}


@end
