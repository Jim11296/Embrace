// (c) 2016-2019 Ricci Adams.  All rights reserved.

#import "WorkerService.h"

#import "HugAudioFile.h"
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

    HugAudioFile *audioFile = [[HugAudioFile alloc] initWithFileURL:internalURL];
  
    if ([audioFile open]) {
        NSInteger fileLengthFrames = [audioFile fileLengthFrames];
        AudioStreamBasicDescription format = [audioFile format];

        NSInteger framesRemaining = fileLengthFrames;
        NSInteger bytesRemaining  = framesRemaining * format.mBytesPerFrame;
        NSInteger bytesRead = 0;

        LoudnessMeasurer *measurer = LoudnessMeasurerCreate(format.mChannelsPerFrame, format.mSampleRate, framesRemaining);

        AudioBufferList *fillBufferList = alloca(sizeof(AudioBufferList) * format.mChannelsPerFrame);
        fillBufferList->mNumberBuffers = format.mChannelsPerFrame;
        
        for (NSInteger i = 0; i < format.mChannelsPerFrame; i++) {
            fillBufferList->mBuffers[i].mNumberChannels = format.mChannelsPerFrame;
            fillBufferList->mBuffers[i].mDataByteSize = format.mBytesPerFrame * 4096 * 16;
            fillBufferList->mBuffers[i].mData = malloc(format.mBytesPerFrame  * 4096 * 16);
        }

        BOOL ok = YES;
        while (ok) {
            UInt32 frameCount = (UInt32)framesRemaining;
            ok = [audioFile readFrames:&frameCount intoBufferList:fillBufferList];

            if (frameCount) {
                LoudnessMeasurerScanAudioBuffer(measurer, fillBufferList, frameCount);
            } else {
                break;
            }
            
            framesRemaining -= frameCount;
        
            bytesRead      += frameCount * format.mBytesPerFrame;
            bytesRemaining -= frameCount * format.mBytesPerFrame;

            if (framesRemaining == 0) {
                break;
            }
        }

        for (NSInteger i = 0; i < format.mChannelsPerFrame; i++) {
            free(fillBufferList->mBuffers[i].mData);
        }
        
        NSTimeInterval decodedDuration = fileLengthFrames / format.mSampleRate;
        
        [result setObject:@(decodedDuration)                       forKey:TrackKeyDecodedDuration];
        [result setObject:LoudnessMeasurerGetOverview(measurer)    forKey:TrackKeyOverviewData];
        [result setObject:@(100)                                   forKey:TrackKeyOverviewRate];
        [result setObject:@(LoudnessMeasurerGetLoudness(measurer)) forKey:TrackKeyTrackLoudness];
        [result setObject:@(LoudnessMeasurerGetPeak(measurer))     forKey:TrackKeyTrackPeak];

        LoudnessMeasurerFree(measurer);

    } else {
        if ([audioFile error]) {
            NSData *errorData = [NSKeyedArchiver archivedDataWithRootObject:[audioFile error] requiringSecureCoding:NO error:nil];
            [result setObject:errorData forKey:TrackKeyError];
        }
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
