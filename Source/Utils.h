//
//  Utils.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppDelegate;

typedef NS_ENUM(NSInteger, Tonality) {
    Tonality_Unknown,
    
    Tonality_1A_AbMinor = 1,
    Tonality_2A_EbMinor,
    Tonality_3A_BbMinor,
    Tonality_4A_FMinor,
    Tonality_5A_CMinor,
    Tonality_6A_GMinor,
    Tonality_7A_DMinor,
    Tonality_8A_AMinor,
    Tonality_9A_EMinor,
    Tonality_10A_BMinor,
    Tonality_11A_FsMinor,
    Tonality_12A_DbMinor,

    Tonality_1B_BMajor = 13,
    Tonality_2B_FsMajor,
    Tonality_3B_DbMajor,
    Tonality_4B_AbMajor,
    Tonality_5B_EbMajor,
    Tonality_6B_BbMajor,
    Tonality_7B_FMajor,
    Tonality_8B_CMajor,
    Tonality_9B_GMajor,
    Tonality_10B_DMajor,
    Tonality_11B_AMajor,
    Tonality_12B_EMajor
};

extern Tonality GetTonalityForString(NSString *string);
extern NSString *GetTraditionalStringForTonality(Tonality tonality);
extern NSString *GetCamelotStringForTonality(Tonality tonality);

extern NSColor *GetRGBColor(int rgb, CGFloat alpha);

extern AppDelegate *GetAppDelegate(void);

extern NSString *GetStringForTime(NSTimeInterval time);
