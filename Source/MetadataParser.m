//  Copyright (c) 2016-2017 Ricci Adams. All rights reserved.

#import "MetadataParser.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "TrackKeys.h"


#define DUMP_UNKNOWN_TAGS 0

#if DUMP_UNKNOWN_TAGS

static NSString *sGetStringForFourCharCode(OSStatus fcc)
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

static NSString *sGetStringForFourCharCodeObject(id object)
{
    if ([object isKindOfClass:[NSString class]]) {
        return sGetStringForFourCharCode((UInt32)[object longLongValue]);
        
    } else if ([object isKindOfClass:[NSNumber class]]) {
        return sGetStringForFourCharCode([object intValue]);

    } else {
        return @"????";
    }
}

#endif


// This is used to construct a fake MP3 file for AIFF fallback parsing
static const UInt8 sFakeMP3Data[] = {
    0xFF, 0xF3, 0x14, 0xC4, 0x00, 0x00, 0x00, 0x03,
    0x48, 0x01, 0x40, 0x00, 0x00, 0x4C, 0x41, 0x4D,
    0x45, 0x33, 0x2E, 0x39, 0x36, 0x2E, 0x31, 0x55,
    0xFF, 0xF3, 0x14, 0xC4, 0x0B, 0x00, 0x00, 0x03,
    0x48, 0x01, 0x80, 0x00, 0x00, 0x55, 0x55, 0x55,
    0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55
};


static const char *sGenreList[128] = {
    "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop", "Jazz", "Metal",
    "New Age", "Oldies", "Other", "Pop", "R&B", "Rap", "Reggae", "Rock", "Techno", "Industrial",
    "Alternative", "Ska", "Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk",
    "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
    "AlternRock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic",
    "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta",
    "Top 40", "Christian Rap", "Pop/Funk", "Jungle", "Native American", "Cabaret", "New Wave", "Psychadelic", "Rave", "Showtunes",
    "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock",
    "Folk", "Folk/Rock", "National Folk", "Swing", "Fast Fusion", "Bebob", "Latin", "Revival", "Celtic", "Bluegrass",
    "Avantgarde", "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock", "Big Band", "Chorus", "Easy Listening", "Acoustic",
    "Humour", "Speech", "Chanson", "Opera", "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus", "Porn Groove",
    "Satire", "Slow Jam", "Club", "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle",
    "Duet", "Punk Rock", "Drum Solo", "A Capella", "Euro-House", "Dance Hall",
    NULL
};


static NSInteger sGetYear(NSString *yearString)
{
    if (![yearString length]) return 0;

    NSRegularExpression  *re     = [NSRegularExpression regularExpressionWithPattern:@"([0-9]{4})" options:NSRegularExpressionCaseInsensitive error:NULL];
    NSTextCheckingResult *result = [re firstMatchInString:yearString options:0 range:NSMakeRange(0, [yearString length])];

    if ([result numberOfRanges] > 1) {
        NSRange captureRange = [result rangeAtIndex:1];
        return [[yearString substringWithRange:captureRange] integerValue];
    }
    
    return 0;
}


@implementation MetadataParser {
    NSMutableDictionary *_metadata;
}

- (instancetype) initWithURL:(NSURL *)URL fallbackTitle:(NSString *)fallbackTitle
{
    if ((self = [super init])) {
        _URL = URL;
        _fallbackTitle = fallbackTitle;
    }
    
    return self;
}


#pragma mark - System Parsers

- (void) _parseUsingAVAsset:(AVAsset *)asset intoDictionary:(NSMutableDictionary *)intoDictionary
{
    void (^parseMetadataItem)(AVMetadataItem *, NSMutableDictionary *) = ^(AVMetadataItem *item, NSMutableDictionary *dictionary) {
        id commonKey = [item commonKey];
        id key       = [item key];

        FourCharCode key4cc = 0;
        if ([key isKindOfClass:[NSString class]] && [key length] == 4) {
            NSData *keyData = [key dataUsingEncoding:NSASCIIStringEncoding];
            
            if ([keyData length] == 4) {
                key4cc = OSSwapBigToHostInt32(*(UInt32 *)[keyData bytes]);
            }

        } else if ([key isKindOfClass:[NSNumber class]]) {
            key4cc = [key unsignedIntValue];
        }
        
        // iTunes stores normalization info in 'COMM' as well as other metadata.
        //
        if (key4cc == 'COMM') {
            id extraInfo = [[item extraAttributes] objectForKey:@"info"];
            
            if ([extraInfo isKindOfClass:[NSString class]]) {
                if ([extraInfo hasPrefix:@"iTunes_"]) {
                    return;
                
                } else if ([extraInfo isEqual:@"iTunNORM"]) {
                    return;
                
                } else if ([extraInfo isEqual:@"iTunPGAP"]) {
                    return;

                } else if ([extraInfo isEqual:@"iTunSMPB"]) {
                    return;
                }
            }
        }

        NSNumber *numberValue = [item numberValue];
        NSString *stringValue = [item stringValue];
        
        id value = [item value];
        NSDictionary *dictionaryValue = nil;
        if ([value isKindOfClass:[NSDictionary class]]) {
            dictionaryValue = (NSDictionary *)value;
        }

        if (!stringValue) {
            stringValue = [dictionaryValue objectForKey:@"text"];
        }
        
        if (!numberValue) {
            if ([value isKindOfClass:[NSData class]]) {
                NSData *data = (NSData *)value;
                
                if ([data length] == 4) {
                    numberValue = @( OSSwapBigToHostInt32(*(UInt32 *)[data bytes]) );
                } else if ([data length] == 2) {
                    numberValue = @( OSSwapBigToHostInt16(*(UInt16 *)[data bytes]) );
                } else if ([data length] == 1) {
                    numberValue = @(                      *(UInt8  *)[data bytes]  );
                }
            }
        }
        
        if (([commonKey isEqual:@"artist"] || [key isEqual:@"artist"]) && stringValue) {
            [dictionary setObject:[item stringValue] forKey:TrackKeyArtist];

        } else if (([commonKey isEqual:@"title"] || [key isEqual:@"title"]) && stringValue) {
            [dictionary setObject:[item stringValue] forKey:TrackKeyTitle];

        } else if ([commonKey isEqual:@"albumName"] && stringValue) {
            [dictionary setObject:[item stringValue] forKey:TrackKeyAlbum];

        } else if ([key isEqual:@"com.apple.iTunes.initialkey"] && stringValue) {
            [dictionary setObject:[item stringValue] forKey:TrackKeyInitialKey];

        } else if ([key isEqual:@"com.apple.iTunes.energylevel"] && numberValue) {
            [dictionary setObject:numberValue forKey:TrackKeyEnergyLevel];

        } else if ((key4cc == 'COMM')   ||
                   (key4cc == '\00COM') ||
                   (key4cc == '\251cmt'))
        {
            if (dictionaryValue) {
                NSString *identifier = [dictionaryValue objectForKey:@"identifier"];
                NSString *text       = [dictionaryValue objectForKey:@"text"];
                
                if ([identifier isEqualToString:@"iTunNORM"]) {
                    return;
                }

                if (text) {
                    [dictionary setObject:text forKey:TrackKeyComments];
                }

            } else if (stringValue) {
                [dictionary setObject:stringValue forKey:TrackKeyComments];
            }

        } else if ((key4cc == 'aART' || key4cc == 'TPE2' || key4cc == '\00TP2') && stringValue) { // Album Artist, 'soaa'
            [dictionary setObject:stringValue forKey:TrackKeyAlbumArtist];
            
        } else if ((key4cc == 'TKEY') && stringValue) { // Initial key as ID3v2.3 TKEY tag
            [dictionary setObject:stringValue forKey:TrackKeyInitialKey];

        } else if ((key4cc == '\00TKE') && stringValue) { // Initial key as ID3v2.2 TKE tag
            [dictionary setObject:stringValue forKey:TrackKeyInitialKey];

        } else if ((key4cc == 'tmpo') && numberValue) { // Tempo key, 'tmpo'
            [dictionary setObject:numberValue forKey:TrackKeyBPM];

        } else if ((key4cc == 'TBPM') && numberValue) { // Tempo as ID3v2.3 TBPM tag
            [dictionary setObject:numberValue forKey:TrackKeyBPM];

        } else if ((key4cc == '\00TBP') && numberValue) { // Tempo as ID3v2.2 TBP tag
            [dictionary setObject:numberValue forKey:TrackKeyBPM];

        } else if ((key4cc == '\251grp') && stringValue) { // Grouping, '?grp'
            [dictionary setObject:stringValue forKey:TrackKeyGrouping];

        } else if ((key4cc == 'TIT1') && stringValue) { // Grouping as ID3v2.3 TIT1 tag
            [dictionary setObject:stringValue forKey:TrackKeyGrouping];

        } else if ((key4cc == '\00TT1') && stringValue) { // Grouping as ID3v2.2 TT1 tag
            [dictionary setObject:stringValue forKey:TrackKeyGrouping];

        } else if (((key4cc == '\251day') || (key4cc == 'TDRC') || (key4cc == 'TYER') || (key4cc == '\00TYE')) && stringValue) { // Year, M4A '?day', MP3 'TDRC'/'TYER'/'TYE'
            NSInteger year = sGetYear(stringValue);
            if (year) [dictionary setObject:@(year) forKey:TrackKeyYear];

        } else if ((key4cc == '\251wrt') && stringValue) { // Composer, '?wrt'
            [dictionary setObject:stringValue forKey:TrackKeyComposer];

        } else if (key4cc == 'gnre') { // Genre, 'gnre' - Use sGenreList lookup
            NSInteger i = [numberValue integerValue];
            if (i > 0 && i < 127) {
                // 'gnre' uses the ID3v1 map, but increments it by one (1 for Blues instead of 0 for Blues)
                i--;

                const char *genre = sGenreList[i];
                if (genre) [dictionary setObject:@(sGenreList[i]) forKey:TrackKeyGenre];
            }

        } else if ((key4cc == '\251gen') && stringValue) { // Genre, '?gen'
            [dictionary setObject:stringValue forKey:TrackKeyGenre];

        } else if (((key4cc == 'TCON') || (key4cc == '\00TCO')) && numberValue) { // Genre, 'TCON'/'TCO' as ID3v1 known genre
            NSInteger i = [numberValue integerValue];
            
            if (i >= 0 && i < 127) {
                const char *genre = sGenreList[i];
                if (genre) [dictionary setObject:@(sGenreList[i]) forKey:TrackKeyGenre];
            }

        } else if ((key4cc == 'TCON' || key4cc == '\00TCO') && stringValue) { // Genre, 'TCON'/'TCO'
            [dictionary setObject:stringValue forKey:TrackKeyGenre];

        } else if ((key4cc == 'TXXX') || (key4cc == '\00TXX')) { // Read TXXX / TXX
            if ([[dictionaryValue objectForKey:@"identifier"] isEqualToString:@"EnergyLevel"]) {
                [dictionary setObject:@( [stringValue integerValue] ) forKey:TrackKeyEnergyLevel];
            }

        } else {
#if DUMP_UNKNOWN_TAGS
            NSString *debugStringValue = [item stringValue];
            if ([debugStringValue length] > 256) stringValue = @"(data)";

            NSLog(@"common: %@ %@, key: %@ %@, value: %@, stringValue: %@",
                commonKey, sGetStringForFourCharCodeObject(commonKey),
                key, sGetStringForFourCharCodeObject(key),
                [item value],
                stringValue
            );
#endif
        }
    };

    NSArray *commonMetadata = [asset commonMetadata];

    for (AVMetadataItem *item in commonMetadata) {
        parseMetadataItem(item, intoDictionary);
    }

    for (NSString *format in [asset availableMetadataFormats]) {
        NSArray *metadata = [asset metadataForFormat:format];
    
        for (AVMetadataItem *item in metadata) {
            parseMetadataItem(item, intoDictionary);
        }
    }

    [asset cancelLoading];
    asset = nil;
}


- (void) _parseUsingAVFoundation
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:_URL options:nil];
    if (asset) [self _parseUsingAVAsset:asset intoDictionary:_metadata];

	NSTimeInterval duration = CMTimeGetSeconds([asset duration]);
    [_metadata setObject:@(duration) forKey:TrackKeyDuration];

}

- (void) _parseUsingAudioToolbox
{
    ExtAudioFileRef extAudioFile = NULL;

    AudioFileID audioFileID;
    UInt32 audioFileIDSize = sizeof(audioFileID);

    CFDictionaryRef audioInfo = NULL;
    UInt32 audioInfoSize = sizeof(audioInfo);

    OSStatus err = noErr;
    
    if (err == noErr) err = ExtAudioFileOpenURL((__bridge CFURLRef)_URL, &extAudioFile);
    if (err == noErr) err = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_AudioFile, &audioFileIDSize, &audioFileID);
    if (err == noErr) err = AudioFileGetProperty(audioFileID, kAudioFilePropertyInfoDictionary, &audioInfoSize, &audioInfo);

    void (^transfer)(const char *, NSString *) = ^(const char *afKey, NSString *trackKey) {
        if (!audioInfo) return;
        
        NSString *nsKey = @(afKey);
       
        CFTypeRef cfValue = CFDictionaryGetValue(audioInfo, (__bridge void *)nsKey);
        if (cfValue) {
            id nsValue = (__bridge id)cfValue;
            
            if ([nsValue isKindOfClass:[NSString class]]) {
                if ([trackKey isEqualToString:TrackKeyYear]) {
                    [_metadata setObject:@([nsValue integerValue]) forKey:TrackKeyYear];
                } else {
                    [_metadata setObject:nsValue forKey:trackKey];
                }
            }
        }
    };

    if (err == noErr) {
        transfer( kAFInfoDictionary_Album,        TrackKeyAlbum      );
        transfer( kAFInfoDictionary_Artist,       TrackKeyArtist     );
        transfer( kAFInfoDictionary_Composer,     TrackKeyComposer   );
        transfer( kAFInfoDictionary_Comments,     TrackKeyComments   );
        transfer( kAFInfoDictionary_KeySignature, TrackKeyInitialKey );
        transfer( kAFInfoDictionary_Genre,        TrackKeyGenre      );
        transfer( kAFInfoDictionary_Tempo,        TrackKeyBPM        );
        transfer( kAFInfoDictionary_Title,        TrackKeyTitle      );
        transfer( kAFInfoDictionary_Year,         TrackKeyYear       );
    }

    if (audioInfo) {
        CFRelease(audioInfo);
    }

    if (extAudioFile) ExtAudioFileDispose(extAudioFile);
}


#pragma mark - Custom Parsers

- (void) _parseID3WithBytes:(const UInt8 *)bytes length:(NSUInteger)length
{
    NSMutableData *id3Data = [NSMutableData dataWithBytes:bytes length:length];

    for (NSInteger j = 0; j < 16; j++) {
        [id3Data appendBytes:&sFakeMP3Data length:sizeof(sFakeMP3Data)];
    }

    NSURL *tempURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    tempURL = [tempURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    tempURL = [tempURL URLByAppendingPathExtension:@"mp3"];

    NSError *error = nil;
    
    if ([id3Data writeToURL:tempURL options:NSDataWritingAtomic error:&error]) {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:tempURL options:nil];
        if (asset) [self _parseUsingAVAsset:asset intoDictionary:_metadata];

        [[NSFileManager defaultManager] removeItemAtURL:tempURL error:&error];
    }
}


- (void) _parseAIFFWithBytes:(const UInt8 *)bytes length:(NSUInteger)length
{
    NSInteger i = 0;
    
    while ((i + 8) <= length) {
        OSType chunkID = OSSwapBigToHostInt(*(OSType *)(bytes + i));
        i += 4;
        
        SInt32 chunkSize = OSSwapBigToHostInt(*(SInt32 *)(bytes + i));
        i += 4;

        if (chunkID == 'ID3 ' && ((i + chunkSize) <= length)) {
            [self _parseID3WithBytes:(bytes + i) length:chunkSize];
        }

        i += chunkSize;
    }
}


- (void) _parseUsingCustomParsers
{
    NSData *data = [NSData dataWithContentsOfURL:_URL];
    
    const char *bytes  = [data bytes];
    NSUInteger  length = [data length];

    if (length > 12 &&
        strncmp(bytes + 0, "FORM", 4) == 0 &&
        strncmp(bytes + 8, "AIF",  3) == 0)
    {
        [self _parseAIFFWithBytes:(const UInt8 *)(bytes + 12) length:(length - 12)];
    }
}


#pragma mark - Public Methods

- (NSDictionary *) metadata
{
    if (!_metadata) {
        _metadata = [NSMutableDictionary dictionary];
        if (_fallbackTitle) {
            [_metadata setObject:_fallbackTitle forKey:TrackKeyTitle];
        }

        NSString *type;
        [_URL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:NULL];

        if (type && (
            UTTypeConformsTo((__bridge CFTypeRef)type, CFSTR("public.aifc-audio")) ||
            UTTypeConformsTo((__bridge CFTypeRef)type, CFSTR("public.aiff-audio"))
        )) {
            [self _parseUsingAudioToolbox];
            [self _parseUsingCustomParsers];

        } else {
            [self _parseUsingAVFoundation];
        }
    }
    
    return _metadata;
}


@end
