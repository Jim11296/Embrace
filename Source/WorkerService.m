//  Copyright (c) 2016-2017 Ricci Adams. All rights reserved.


#import "WorkerService.h"

#import "AudioFile.h"
#import "TrackKeys.h"
#import "LoudnessMeasurer.h"
#import "MetadataParser.h"

#import <iTunesLibrary/iTunesLibrary.h>

static dispatch_queue_t sMetadataQueue           = nil;
static dispatch_queue_t sLibraryQueue            = nil;
static dispatch_queue_t sLoudnessImmediateQueue  = nil;
static dispatch_queue_t sLoudnessBackgroundQueue = nil;

static NSMutableSet *sCancelledUUIDs = nil;
static NSMutableSet *sLoudnessUUIDs  = nil;


@interface Worker : NSObject <WorkerProtocol>

@end


@implementation Worker {
    ITLibrary *_library;
}

+ (void) initialize
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sMetadataQueue           = dispatch_queue_create("metadata",            DISPATCH_QUEUE_SERIAL);
        sLibraryQueue            = dispatch_queue_create("library",             DISPATCH_QUEUE_SERIAL);
        sLoudnessImmediateQueue  = dispatch_queue_create("loudness-immediate",  DISPATCH_QUEUE_SERIAL);
        sLoudnessBackgroundQueue = dispatch_queue_create("loudness-background", DISPATCH_QUEUE_SERIAL);

        sCancelledUUIDs = [NSMutableSet set];
        sLoudnessUUIDs  = [NSMutableSet set];
    });
}


static NSDictionary *sReadMetadata(NSURL *internalURL, NSString *originalFilename)
{
    NSString *fallbackTitle = [originalFilename stringByDeletingPathExtension];

    MetadataParser *parser = [[MetadataParser alloc] initWithURL:internalURL fallbackTitle:fallbackTitle];
    
    return [parser metadata];
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
        
        NSTimeInterval decodedDuration = fileLengthFrames / fileFormat.mSampleRate;
        
        [result setObject:@(decodedDuration)                       forKey:TrackKeyDecodedDuration];
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
                bookmarkData: (NSData *) bookmarkData
            originalFilename: (NSString *) originalFilename
                       reply: (void (^)(NSDictionary *))reply
{
    NSError *error = nil;
    NSURL *internalURL = [NSURL URLByResolvingBookmarkData: bookmarkData
                                                   options: NSURLBookmarkResolutionWithoutUI
                                             relativeToURL: nil
                                       bookmarkDataIsStale: NULL
                                                     error: &error];

    if (error) NSLog(@"%@", error);

    if (command == WorkerTrackCommandReadMetadata) {
        dispatch_async(sMetadataQueue, ^{ @autoreleasepool {
            [internalURL startAccessingSecurityScopedResource];
        
            if (![sCancelledUUIDs containsObject:UUID]) {
                reply(sReadMetadata(internalURL, originalFilename));
            }

            [internalURL stopAccessingSecurityScopedResource];
        } });

    } else if (command == WorkerTrackCommandReadLoudness || command == WorkerTrackCommandReadLoudnessImmediate) {
        BOOL             isImmediate = (command == WorkerTrackCommandReadLoudnessImmediate);
        dispatch_queue_t queue       = isImmediate ? sLoudnessImmediateQueue : sLoudnessBackgroundQueue;

        dispatch_async(queue, ^{ @autoreleasepool {
            [internalURL startAccessingSecurityScopedResource];

            if (![sCancelledUUIDs containsObject:UUID] && ![sLoudnessUUIDs containsObject:UUID]) {
                [sLoudnessUUIDs addObject:UUID];

                NSDictionary *dictionary = sReadLoudness(internalURL);

                dispatch_async(dispatch_get_main_queue(), ^{
                    reply(dictionary);
                });
            }

            [internalURL stopAccessingSecurityScopedResource];
        } });
    }
}


- (void) performLibraryParseWithReply:(void (^)(NSDictionary *))reply
{
    dispatch_async(sLibraryQueue, ^{
        if (!_library) {
            NSError *error = nil;
            _library = [ITLibrary libraryWithAPIVersion:@"1.0" error:&error];
            NSLog(@"%@", error);
        } else {
            [_library reloadData];
        }
        
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        
        for (ITLibMediaItem *mediaItem in [_library allMediaItems]) {
            NSUInteger startTime = [mediaItem startTime];
            NSUInteger stopTime  = [mediaItem stopTime];

            if (startTime || stopTime) {
                NSMutableDictionary *trackData = [NSMutableDictionary dictionaryWithCapacity:2];
                
                if (startTime) [trackData setObject:@(startTime / 1000.0) forKey:TrackKeyStartTime];
                if (stopTime)  [trackData setObject:@(stopTime  / 1000.0) forKey:TrackKeyStopTime];
                
                NSString *location = [[mediaItem location] path];
                if (location) [result setObject:trackData forKey:location];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            reply(result);
        });
    });
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


static WorkerDelegate *sWorkerDelegate = nil;

int main(int argc, const char *argv[])
{
    sWorkerDelegate = [[WorkerDelegate alloc] init];
    
    NSXPCListener *listener = [NSXPCListener serviceListener];
    [listener setDelegate:sWorkerDelegate];
    
    [listener resume];

    return 0;
}
