//
//  Utils.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Utils.h"


static NSArray *sGetTraditionalStringArray()
{
    return @[
        @"",

        @"G#m", @"Ebm", @"Bbm", @"Fm",
        @"Cm",  @"Gm",  @"Dm",  @"Am",
        @"Em",  @"Bm",  @"F#m", @"C#m",

        @"B",   @"F#",  @"Db",  @"Ab",
        @"Eb",  @"Bb",  @"F",   @"C",
        @"G",   @"D",   @"A",   @"E"
    ];
}


static NSArray *sGetEnharmonicStringArray()
{
    return @[
        @"",

        @"Abm", @"D#m", @"A#m", @"E#m",
        @"B#m", @"Gm",  @"Dm",  @"Am",
        @"Fbm", @"Cbm", @"Gbm", @"Dbm",

        @"Cb",  @"Gb",  @"C#",  @"G#",
        @"D#",  @"A#",  @"E#",  @"B#",
        @"G",   @"D",   @"A",   @"Fb"
    ];
}


static NSArray *sGetOpenKeyNotationArray()
{
    return @[
        @"",

        @"6m",  @"7m",  @"8m",  @"9m",
        @"10m", @"11m", @"12m", @"1m",
        @"2m",  @"3m",  @"4m",  @"5m",

        @"6d",  @"7d",  @"8d",  @"9d",
        @"10d", @"11d", @"12d", @"1d",
        @"2d",  @"3d",  @"4d",  @"5d"
    ];
}

#define TEST_TONALITY_PARSERS 0

#if TEST_TONALITY_PARSERS

__attribute__((constructor)) static void TestTonalityParsers()
{
    void (^test)(Tonality, id, id, id, id) = ^(Tonality tonality, id s1, id s2, id inOKS, id inCamelot) {
        if (tonality != GetTonalityForString(s1)       ) NSLog(@"%@", s1);
        if (tonality != GetTonalityForString(inOKS)    ) NSLog(@"%@", inOKS);
        if (tonality != GetTonalityForString(inCamelot)) NSLog(@"%@", inCamelot);

        if (s2 && (tonality != GetTonalityForString(s2))) {
            NSLog(@"%@", s2);
        }
        
        NSString *traditional = GetTraditionalStringForTonality(tonality);
        NSString *oks = GetOpenKeyNotationStringForTonality(tonality);
        
        if (![traditional isEqualToString:s1]) {
            NSLog(@"%@ != %@", traditional, s1);
        }

        if (![oks isEqualToString:inOKS]) {
            NSLog(@"%@ != %@", oks, inOKS);
        }
    };

    test( Tonality_Major__1___8B__C,  @"C", @"B#",  @"1d",  @"8B" );
    test( Tonality_Major__2___9B__G,  @"G",  nil,   @"2d",  @"9B" );
    test( Tonality_Major__3__10B__D,  @"D",  nil,   @"3d",  @"10B" );
    test( Tonality_Major__4__11B__A,  @"A",  nil,   @"4d",  @"11B" );
    test( Tonality_Major__5__12B__E,  @"E",  @"Fb", @"5d",  @"12B" );
    test( Tonality_Major__6___1B__B,  @"B",  @"Cb", @"6d",  @"1B" );
    test( Tonality_Major__7___2B__Fs, @"F#", @"Gb", @"7d",  @"2B" );
    test( Tonality_Major__8___3B__Db, @"Db", @"C#", @"8d",  @"3B" );
    test( Tonality_Major__9___4B__Ab, @"Ab", @"G#", @"9d",  @"4B" );
    test( Tonality_Major_10___5B__Eb, @"Eb", @"D#", @"10d", @"5B" );
    test( Tonality_Major_11___6B__Bb, @"Bb", @"A#", @"11d", @"6B" );
    test( Tonality_Major_12___7B__F,  @"F",  @"E#", @"12d", @"7B" );


    test( Tonality_Minor__1___8A__A,  @"Am",  nil,    @"1m",  @"8A");
    test( Tonality_Minor__2___9A__E,  @"Em",  @"Fbm", @"2m",  @"9A");
    test( Tonality_Minor__3__10A__B,  @"Bm",  @"Cbm", @"3m",  @"10A");
    test( Tonality_Minor__4__11A__Fs, @"F#m", @"Gbm", @"4m",  @"11A");
    test( Tonality_Minor__5__12A__Cs, @"C#m", @"Dbm", @"5m",  @"12A");
    test( Tonality_Minor__6___1A__Ab, @"G#m", @"Abm", @"6m",  @"1A");
    test( Tonality_Minor__7___2A__Eb, @"Ebm", @"D#m", @"7m",  @"2A");
    test( Tonality_Minor__8___3A__Bb, @"Bbm", @"A#m", @"8m",  @"3A");
    test( Tonality_Minor__9___4A__F,  @"Fm",  @"E#m", @"9m",  @"4A");
    test( Tonality_Minor_10___5A__C,  @"Cm",  @"B#m", @"10m", @"5A");
    test( Tonality_Minor_11___6A__G,  @"Gm",  nil,    @"11m", @"6A");
    test( Tonality_Minor_12___7A__D,  @"Dm",  nil,    @"12m", @"7A");
    

}

#endif


static NSString *sFindOrCreateDirectory(
    NSSearchPathDirectory searchPathDirectory,
    NSSearchPathDomainMask domainMask,
    NSString *appendComponent,
    NSError **outError
) {
    NSArray* paths = NSSearchPathForDirectoriesInDomains(searchPathDirectory, domainMask, YES);
    if (![paths count]) return nil;

    NSString *resolvedPath = [paths firstObject];
    if (appendComponent) {
        resolvedPath = [resolvedPath stringByAppendingPathComponent:appendComponent];
    }

    NSError *error;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:resolvedPath withIntermediateDirectories:YES attributes:nil error:&error];

    if (!success) {
        if (outError) *outError = error;
        return nil;
    }

    if (outError) *outError = nil;

    return resolvedPath;
}


static OSStatus sGroupError = noErr;

BOOL CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) {
        return YES;
	}

    if (sGroupError != noErr) {
        sGroupError = error;
    }

	NSLog(@"Error: %s (%@)\n", operation, GetStringForFourCharCode(error));
    EmbraceLog(@"CheckError", @"Error: %s (%@)", operation, GetStringForFourCharCode(error));

    return NO;
}


BOOL CheckErrorGroup(void (^callback)())
{
    OSStatus previousGroupError = sGroupError;
    callback();

    BOOL result = (sGroupError == noErr);
    
    sGroupError = previousGroupError;
    
    return result;
}


NSArray *GetAvailableAudioFileUTIs()
{
    CFArrayRef *cfArray = NULL;
    UInt32 size;

    OSStatus err = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AllUTIs, 0, NULL, &size);

    if (err == noErr) {
        err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AllUTIs, 0, NULL, &size, &cfArray);
    }
    
    NSArray *result = nil;

    if (err == noErr) {
        result = cfArray ? CFBridgingRelease(cfArray) : nil;
    }

    return result;
}


BOOL IsAudioFileAtURL(NSURL *fileURL)
{
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];

    NSString *type;
    NSError *error;

    if ([fileURL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&error]) {
        for (NSString *availableType in GetAvailableAudioFileUTIs()) {
            if ([workspace type:type conformsToType:availableType]) {
                return YES;
            }
        }
    }

    return NO;
}


BOOL LoadPanelState(NSSavePanel *panel, NSString *name)
{
    NSString *path = [[NSUserDefaults standardUserDefaults] objectForKey:name];
    
    if (path) {
        NSURL *url = [NSURL fileURLWithPath:path];
        
        if (url) {
            [panel setDirectoryURL:url];
            return YES;
        }
    }
    
    return NO;
}


void SavePanelState(NSSavePanel *panel, NSString *name)
{
    NSString *path = [[panel directoryURL] path];
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:name];
}


extern NSString *GetStringForFourCharCode(OSStatus fcc)
{
	char str[20] = {0};

	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(*(UInt32 *)&fcc);

	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
    } else {
        return [NSString stringWithFormat:@"%ld", (long)fcc];
    }
    
    return [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
}


extern NSString *GetStringForFourCharCodeObject(id object)
{
    if ([object isKindOfClass:[NSString class]]) {
        return GetStringForFourCharCode((UInt32)[object longLongValue]);
        
    } else if ([object isKindOfClass:[NSNumber class]]) {
        return GetStringForFourCharCode([object unsignedIntValue]);

    } else {
        return @"????";
    }
}


extern Tonality GetTonalityForString(NSString *string)
{
    if (![string length]) {
        return Tonality_Unknown;
    }
    
    const size_t MaxBufferSize = 1024;

    char buffer[MaxBufferSize];
    char *bufferPtr = buffer;
    
    if (![string getCString:buffer maxLength:MaxBufferSize encoding:NSUTF8StringEncoding]) {
        return Tonality_Unknown;
    }
    
    NSInteger decimal = 0;
    char alpha = 0;
    char sharpOrFlat = 0;

    char c;
    while ((c = *bufferPtr)) {
        if (isnumber(c)) {
            decimal = strtod(bufferPtr, &bufferPtr);

        } else if (c == '#') {
            sharpOrFlat = '#';
            bufferPtr++;

        } else if (isalpha(c)) {
            if (alpha && (c == 'b')) {
                sharpOrFlat = c;
            } else {
                alpha = c;
            }

            bufferPtr++;

        } else if (c == 0) {
            break;

        } else {
            bufferPtr++;
        }
    }
    
    Tonality result = Tonality_Unknown;

    if (decimal >= 1 && decimal <= 12) {
        // Camelot, Minor
        if (alpha == 'A' || alpha == 'a') {
            Tonality map[13] = {
                Tonality_Unknown,
                Tonality_Minor__6___1A__Ab,
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
                Tonality_Minor__5__12A__Cs
            };

            result = map[decimal];

        // Camelot, Major
        } else if (alpha == 'B' || alpha == 'b') {
            Tonality map[13] = {
                Tonality_Unknown,
                Tonality_Major__6___1B__B,
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

            result = map[decimal];

        // Open Key Notation, Minor
        } else if (alpha == 'M' || alpha == 'm') {
            Tonality map[13] = {
                Tonality_Unknown,
                Tonality_Minor__1___8A__A,
                Tonality_Minor__2___9A__E,
                Tonality_Minor__3__10A__B,
                Tonality_Minor__4__11A__Fs,
                Tonality_Minor__5__12A__Cs,
                Tonality_Minor__6___1A__Ab,
                Tonality_Minor__7___2A__Eb,
                Tonality_Minor__8___3A__Bb,
                Tonality_Minor__9___4A__F,
                Tonality_Minor_10___5A__C,
                Tonality_Minor_11___6A__G,
                Tonality_Minor_12___7A__D
            };

            result = map[decimal];

        // Open Key Notation, Major
        } else if (alpha == 'D' || alpha == 'd') {
            Tonality map[13] = {
                Tonality_Unknown,
                Tonality_Major__1___8B__C,
                Tonality_Major__2___9B__G,
                Tonality_Major__3__10B__D,
                Tonality_Major__4__11B__A,
                Tonality_Major__5__12B__E,
                Tonality_Major__6___1B__B,
                Tonality_Major__7___2B__Fs,
                Tonality_Major__8___3B__Db,
                Tonality_Major__9___4B__Ab,
                Tonality_Major_10___5B__Eb,
                Tonality_Major_11___6B__Bb,
                Tonality_Major_12___7B__F
            };

            result = map[decimal];
        }
    }

    if (result == Tonality_Unknown) {
        NSArray  *array = sGetTraditionalStringArray();
        NSUInteger index = [array indexOfObject:string];

        if (index == NSNotFound) {
            index = [sGetEnharmonicStringArray() indexOfObject:string];
        }

        if (index != NSNotFound && index != 0) {
            result = (Tonality)index;
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


extern NSString *GetOpenKeyNotationStringForTonality(Tonality tonality)
{
    NSArray *array = sGetOpenKeyNotationArray();
    
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


NSColor *GetInactiveHighlightColor() {   return GetRGBColor(0xd2e3f8, 1.0); }
NSColor *GetActiveHighlightColor() { return GetRGBColor(0x0065dc, 1.0); }

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


NSString *GetApplicationSupportDirectory()
{
    NSString *name = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
    return sFindOrCreateDirectory(NSApplicationSupportDirectory, NSUserDomainMask, name, NULL);
}


