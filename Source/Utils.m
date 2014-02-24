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


BOOL CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return YES;
	
	NSLog(@"Error: %s (%@)\n", operation, GetStringForFourCharCode(error));
    
    return NO;
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


NSString *GetApplicationSupportDirectory()
{
    NSString *name = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
    return sFindOrCreateDirectory(NSApplicationSupportDirectory, NSUserDomainMask, name, NULL);
}



