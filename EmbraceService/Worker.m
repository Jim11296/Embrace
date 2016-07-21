//
//  EmbraceService.m
//  EmbraceService
//
//  Created by Ricci Adams on 2016-05-07.
//  Copyright © 2016 Ricci Adams. All rights reserved.
//

#import "Worker.h"

#import "AudioFile.h"
#import "TrackKeys.h"
#import "LoudnessMeasurer.h"


static dispatch_queue_t sMetadataQueue          = nil;
static dispatch_queue_t sLoudnessImmediateQueue = nil;
static dispatch_queue_t sLoudnessBackgroundQueue = nil;

static NSMutableSet *sCancelledUUIDs = nil;
static NSMutableSet *sLoudnessUUIDs  = nil;


static const char *sGenreList[128] = {
    NULL,
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


@interface Worker : NSObject <WorkerProtocol>

@end


@implementation Worker

+ (void) initialize
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sMetadataQueue           = dispatch_queue_create("metadata",            DISPATCH_QUEUE_SERIAL);
        sLoudnessImmediateQueue  = dispatch_queue_create("loudness-immediate",  DISPATCH_QUEUE_SERIAL);
        sLoudnessBackgroundQueue = dispatch_queue_create("loudness-background", DISPATCH_QUEUE_SERIAL);

        sCancelledUUIDs = [NSMutableSet set];
        sLoudnessUUIDs  = [NSMutableSet set];
    });
}


// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.


static NSDictionary *sReadMetadata(NSURL *internalURL, NSURL *externalURL)
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

        } else if ([commonKey isEqual:@"creationDate"] && stringValue) {
            NSInteger year = [stringValue integerValue];

            if (year) {
                [dictionary setObject:@(year) forKey:TrackKeyYear];
            }

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

        } else if ((key4cc == '\251day') && numberValue) { // Grouping, '?grp'
            [dictionary setObject:numberValue forKey:TrackKeyYear];

        } else if ((key4cc == '\251wrt') && stringValue) { // Composer, '?wrt'
            [dictionary setObject:stringValue forKey:TrackKeyComposer];

        } else if (key4cc == 'gnre') { // Genre, 'gnre' - Use sGenreList lookup
            NSInteger i = [numberValue integerValue];
            if (i > 0 && i < 127) {
                const char *genre = sGenreList[i];
                if (genre) [dictionary setObject:@(sGenreList[i]) forKey:TrackKeyGenre];
            }

        } else if ((key4cc == '\251gen') && stringValue) { // Genre, '?gen'
            [dictionary setObject:stringValue forKey:TrackKeyGenre];

        } else if ((key4cc == 'TCON') && stringValue) { // Genre, 'TCON'
            [dictionary setObject:stringValue forKey:TrackKeyGenre];

        } else if ((key4cc == '\00TCO') && stringValue) { // Genre, 'TCO'
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
                commonKey, GetStringForFourCharCodeObject(commonKey),
                key, GetStringForFourCharCodeObject(key),
                [item value],
                stringValue
            );
#endif
        }
    };

    NSString *fallbackTitle = [[externalURL lastPathComponent] stringByDeletingPathExtension];

    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:internalURL options:nil];

    NSArray *commonMetadata = [asset commonMetadata];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    for (AVMetadataItem *item in commonMetadata) {
        parseMetadataItem(item, dictionary);
    }

    if (![dictionary objectForKey:TrackKeyTitle]) {
        [dictionary setObject:fallbackTitle forKey:TrackKeyTitle];
    }

    for (NSString *format in [asset availableMetadataFormats]) {
        NSArray *metadata = [asset metadataForFormat:format];
    
        for (AVMetadataItem *item in metadata) {
            parseMetadataItem(item, dictionary);
        }
    }

    NSTimeInterval duration = CMTimeGetSeconds([asset duration]);
    [dictionary setObject:@(duration) forKey:TrackKeyDuration];

    [asset cancelLoading];
    asset = nil;

    return dictionary;
}


static NSDictionary *sReadLoudness(NSURL *internalURL)
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    AudioFile *audioFile = [[AudioFile alloc] initWithFileURL:internalURL];

    OSStatus err = noErr;

    // Open file
    if (err == noErr) {
        err = [audioFile open];
        if (err) NSLog(@"AudioFile -open: %ld", (long)err);
    }

    AudioStreamBasicDescription fileFormat = {0};
    if (err == noErr) {
        err = [audioFile getFileDataFormat:&fileFormat];
    }


    AudioStreamBasicDescription clientFormat = {0};

    if (err == noErr) {
        UInt32 channels = fileFormat.mChannelsPerFrame;
        
        clientFormat.mSampleRate       = fileFormat.mSampleRate;
        clientFormat.mFormatID         = kAudioFormatLinearPCM;
        clientFormat.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        clientFormat.mBytesPerPacket   = sizeof(float);
        clientFormat.mFramesPerPacket  = 1;
        clientFormat.mBytesPerFrame    = clientFormat.mFramesPerPacket * clientFormat.mBytesPerPacket;
        clientFormat.mChannelsPerFrame = channels;
        clientFormat.mBitsPerChannel   = sizeof(float) * 8;

        err = [audioFile setClientDataFormat:&clientFormat];
    }
    
    if (![audioFile canRead] &&
        ![audioFile convert] &&
        ![audioFile canRead])
    {
        err = 1;
    }
    
    
    SInt64 fileLengthFrames = 0;
    if (err == noErr) {
        err = [audioFile getFileLengthFrames:&fileLengthFrames];
    }
    
    if (err == noErr) {
        NSInteger framesRemaining = fileLengthFrames;
        NSInteger bytesRemaining = framesRemaining * clientFormat.mBytesPerFrame;
        NSInteger bytesRead = 0;

        LoudnessMeasurer *measurer = LoudnessMeasurerCreate(clientFormat.mChannelsPerFrame, clientFormat.mSampleRate, framesRemaining);

        AudioBufferList *fillBufferList = alloca(sizeof(AudioBufferList) * clientFormat.mChannelsPerFrame);
        fillBufferList->mNumberBuffers = clientFormat.mChannelsPerFrame;
        
        for (NSInteger i = 0; i < clientFormat.mChannelsPerFrame; i++) {
            fillBufferList->mBuffers[i].mNumberChannels = clientFormat.mChannelsPerFrame;
            fillBufferList->mBuffers[i].mDataByteSize = clientFormat.mBytesPerFrame * 4096 * 16;
            fillBufferList->mBuffers[i].mData = malloc(clientFormat.mBytesPerFrame  * 4096 * 16);
        }

        while (1 && (err == noErr)) {
            UInt32 frameCount = (UInt32)framesRemaining;
            err = [audioFile readFrames:&frameCount intoBufferList:fillBufferList];

            if (frameCount) {
                LoudnessMeasurerScanAudioBuffer(measurer, fillBufferList, frameCount);
            } else {
                break;
            }
            
            framesRemaining -= frameCount;
        
            bytesRead       += frameCount * clientFormat.mBytesPerFrame;
            bytesRemaining  -= frameCount * clientFormat.mBytesPerFrame;

            if (framesRemaining == 0) {
                break;
            }
        }

        for (NSInteger i = 0; i < clientFormat.mChannelsPerFrame; i++) {
            free(fillBufferList->mBuffers[i].mData);
        }
        
        [result setObject:LoudnessMeasurerGetOverview(measurer)    forKey:TrackKeyOverviewData];
        [result setObject:@(100)                                   forKey:TrackKeyOverviewRate];
        [result setObject:@(LoudnessMeasurerGetLoudness(measurer)) forKey:TrackKeyTrackLoudness];
        [result setObject:@(LoudnessMeasurerGetPeak(measurer))     forKey:TrackKeyTrackPeak];

        LoudnessMeasurerFree(measurer);

    } else {
        [result setObject:@([audioFile audioFileError]) forKey:TrackKeyError];
    }

    return result;
}


- (void) cancelUUID:(NSUUID *)UUID
{
    [sCancelledUUIDs addObject:UUID];
}


- (void) performTrackCommand: (WorkerTrackCommand) command
                        UUID: (NSUUID *) UUID
                 internalURL: (NSURL *) internalURL
                 externalURL: (NSURL *) externalURL
                       reply: (void (^)(NSDictionary *))reply
{
    if (command == WorkerTrackCommandReadMetadata) {
        dispatch_async(sMetadataQueue, ^{ @autoreleasepool {
            if (![sCancelledUUIDs containsObject:UUID]) {
                reply(sReadMetadata(internalURL, externalURL));
            }
        } });

    } else if (command == WorkerTrackCommandReadLoudness || command == WorkerTrackCommandReadLoudnessImmediate) {
        BOOL             isImmediate = (command == WorkerTrackCommandReadLoudnessImmediate);
        dispatch_queue_t queue       = isImmediate ? sLoudnessImmediateQueue : sLoudnessBackgroundQueue;

        dispatch_async(queue, ^{ @autoreleasepool {
            if (![sCancelledUUIDs containsObject:UUID] && ![sLoudnessUUIDs containsObject:UUID]) {
                [sLoudnessUUIDs addObject:UUID];

                NSDictionary *dictionary = sReadLoudness(internalURL);

                dispatch_async(dispatch_get_main_queue(), ^{
                    reply(dictionary);
                });
            }
        } });
    }
}


@end


#pragma mark - WorkerDelegate

@interface WorkerDelegate : NSObject <NSXPCListenerDelegate>
@end


@implementation WorkerDelegate

- (BOOL) listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)connection
{
    NSXPCInterface *exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(WorkerProtocol)];
    [connection setExportedInterface:exportedInterface];
    
    Worker *exportedObject = [[Worker alloc] init];
    [connection setExportedObject:exportedObject];
    
    [connection resume];
    
    return YES;
}

@end


int main(int argc, const char *argv[])
{
    WorkerDelegate *delegate = [[WorkerDelegate alloc] init];
    
    NSXPCListener *listener = [NSXPCListener serviceListener];
    [listener setDelegate:delegate];
    
    [listener resume];

    return 0;
}
