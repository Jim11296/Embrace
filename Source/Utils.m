//
//  Utils.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Utils.h"

static NSArray *sGetCamelotStringArray()
{
    return @[
        @"",

        @"1A", @"2A",  @"3A",  @"4A",
        @"5A", @"6A",  @"7A",  @"8A",
        @"9A", @"10A", @"11A", @"12A",

        @"1B", @"2B",  @"3B",  @"4B",
        @"5B", @"6B",  @"7B",  @"8B",
        @"9B", @"10B", @"11B", @"12B"
    ];
}


static NSArray *sGetTraditionalStringArray()
{
    return @[
        @"",

        @"Abm", @"Ebm", @"Bbm", @"Fm",
        @"Cm",  @"Gm",  @"Dm",  @"Am",
        @"Em",  @"Bm",  @"F#m", @"Dbm",

        @"B",   @"F#",  @"Db",  @"Ab",
        @"Eb",  @"Bb",  @"F",   @"C",
        @"G",   @"D",   @"A",   @"E"
    ];
}


extern Tonality GetTonalityForString(NSString *string)
{
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    Tonality result = Tonality_Unknown;

    if (result == Tonality_Unknown) {
        NSArray  *array = sGetTraditionalStringArray();
        NSInteger index = [array indexOfObject:string];

        if (index != NSNotFound && index != 0) {
            result = index;
        }
    }

    if (result == Tonality_Unknown) {
        NSArray  *array = sGetCamelotStringArray();
        NSInteger index = [array indexOfObject:string];

        if (index != NSNotFound && index != 0) {
            result = index;
        }
    }
    
    return result;
}


extern NSString *GetTraditionalStringForTonality(Tonality tonality)
{
    NSArray *array = sGetTraditionalStringArray();
    
    if (tonality > 0 && tonality < [array count]) {
        return [array objectAtIndex:tonality];
    }
    
    return nil;
}


extern NSString *GetCamelotStringForTonality(Tonality tonality)
{
    NSArray *array = sGetCamelotStringArray();

    if (tonality > 0 && tonality < [array count]) {
        return [array objectAtIndex:tonality];
    }
    
    return nil;
}


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



NSString *GetStringForTime(NSTimeInterval time)
{
    BOOL minus = NO;

    if (time < 0) {
        time = -time;
        minus = YES;
    }

    double seconds = floor(fmod(time, 60.0));
    double minutes = floor(time / 60.0);

    return [NSString stringWithFormat:@"%s%g:%02g", minus ? "-" : "", minutes, seconds];
}

