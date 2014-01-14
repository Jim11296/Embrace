//
//  Utils.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Utils.h"

NSColor *GetRGBColor(int rgb, CGFloat alpha)
{
    float r = (((rgb & 0xFF0000) >> 16) / 255.0);
    float g = (((rgb & 0x00FF00) >>  8) / 255.0);
    float b = (((rgb & 0x0000FF) >>  0) / 255.0);

    return [NSColor colorWithSRGBRed:r green:g blue:b alpha:alpha];
}


extern AppDelegate *GetAppDelegate(void)
{
    return (AppDelegate *)[NSApp delegate];
}
