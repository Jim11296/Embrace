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
    
    Tonality_Minor__6___1A__Ab = 1,
    Tonality_Minor__7___2A__Eb,
    Tonality_Minor__8___3A__Bb,
    Tonality_Minor__9___4A__F,
    Tonality_Minor_10___5A__C,
    Tonality_Minor_11___6A__G,
    Tonality_Minor_12___7A__D,
    Tonality_Minor__1___8A__A,
    Tonality_Minor__2___9A__E,
    Tonality_Minor__3__10A__B,
    Tonality_Minor__4__11A__Fs,
    Tonality_Minor__5__12A__Cs,

    Tonality_Major__6___1B__B = 13,
    Tonality_Major__7___2B__Fs,
    Tonality_Major__8___3B__Db,
    Tonality_Major__9___4B__Ab,
    Tonality_Major_10___5B__Eb,
    Tonality_Major_11___6B__Bb,
    Tonality_Major_12___7B__F,
    Tonality_Major__1___8B__C,
    Tonality_Major__2___9B__G,
    Tonality_Major__3__10B__D,
    Tonality_Major__4__11B__A,
    Tonality_Major__5__12B__E
};

extern BOOL CheckError(OSStatus error, const char *operation);

extern NSArray *GetAvailableAudioFileUTIs(void);
extern BOOL IsAudioFileAtURL(NSURL *fileURL);

extern BOOL LoadPanelState(NSSavePanel *panel, NSString *name);
extern void SavePanelState(NSSavePanel *panel, NSString *name);

extern NSString *GetStringForFourCharCode(OSStatus fcc);
extern NSString *GetStringForFourCharCodeObject(id object);

extern Tonality GetTonalityForString(NSString *string);
extern NSString *GetTraditionalStringForTonality(Tonality tonality);
extern NSString *GetOpenKeyNotationStringForTonality(Tonality tonality);

extern NSColor *GetRGBColor(int rgb, CGFloat alpha);

extern AppDelegate *GetAppDelegate(void);

extern NSString *GetStringForTime(NSTimeInterval time);

extern NSString *GetApplicationSupportDirectory();


extern void EmbraceRotateLogs(void);
extern void EmbraceLog(NSString *category, NSString *format, ...) NS_FORMAT_FUNCTION(2,3);

