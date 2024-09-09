// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "HugAudioFile.h"
#import "HugUtils.h"
#import "HugError.h"

#import <AVFoundation/AVFoundation.h>


static NSError *sMakeError(NSInteger code)
{
    return [NSError errorWithDomain:HugErrorDomain code:code userInfo:nil];
}


@implementation HugAudioFile {
    NSURL *_fileURL;
    NSURL *_exportedURL;
    ExtAudioFileRef _extAudioFile;
}


- (id) initWithFileURL:(NSURL *)fileURL
{
    if ((self = [super init])) {
        _fileURL = fileURL;
    }

    return self;
}


- (void) dealloc
{
    if (_exportedURL) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtURL:_exportedURL error:&error];
    }

    [self close];
}


- (NSString *) description
{
    NSString *friendlyString = [_fileURL path];

    if ([friendlyString length]) {
        return [NSString stringWithFormat:@"<%@: %p, \"%@\">", [self class], self, friendlyString];
    } else {
        return [super description];
    }
}


#pragma mark - Private Methods

- (BOOL) _reopenAudioFileWithURL:(NSURL *)url
{
    AudioStreamBasicDescription fileDataFormat   = {0};
    AudioStreamBasicDescription clientDataFormat = {0};
    
    BOOL ok = YES;

    if (ok) {
        ok = [self _getClientDataFormat:&clientDataFormat];
    }

    [self close];

    if (ok) {
        OSStatus err = ExtAudioFileOpenURL((__bridge CFURLRef)_exportedURL, &_extAudioFile);

        if (err != noErr) {
            HugLog(@"HugAudioFile", @"%@, ExtAudioFileOpenURL() failed %ld", self, (long)err);
            ok = NO;
        }
    }
    
    if (ok) ok = [self _setClientDataFormat:&clientDataFormat];
    if (ok) ok = [self _getFileDataFormat:&fileDataFormat];

    if (!ok) HugLog(@"HugAudioFile", @"-_reopenAudioFileWithURL: failed");

    return ok;
}


- (BOOL) _canRead
{
    SInt64 fileLengthFrames = 0;
    if (![self _getFileLengthFrames:&fileLengthFrames]) return NO;
    
    AudioStreamBasicDescription clientDataFormat = {0};
    if (![self _getClientDataFormat:&clientDataFormat]) return NO;

    UInt32 channelCount = clientDataFormat.mChannelsPerFrame;
    if (!channelCount) return NO;

    UInt32 framesToRead = 1024;
    AudioBufferList *bufferList = HugAudioBufferListCreate(channelCount, framesToRead, YES);
    
    OSStatus err = noErr;

    SInt64 frameOffset = 0;
    if (err == noErr) {
        err = ExtAudioFileTell(_extAudioFile, &frameOffset);
    }

    if (err == noErr) {
        err = ExtAudioFileRead(_extAudioFile, &framesToRead, bufferList);
    }
    
    if (err == noErr) {
        err = ExtAudioFileSeek(_extAudioFile, frameOffset);
    }
    
    HugAudioBufferListFree(bufferList, YES);

    return err == noErr;
}


- (BOOL) _convert
{
    AVAssetExportSession *session;
    BOOL hasProtectedContent = NO;

@autoreleasepool {
    AVAsset *asset = [AVAsset assetWithURL:_fileURL];
    hasProtectedContent = [asset hasProtectedContent];
    
    session = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
}

    NSString *typeToUse;
    NSString *extension;
    
    NSString *temporaryFilePath = NSTemporaryDirectory();
    temporaryFilePath = [temporaryFilePath stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    NSArray *fileTypes = [session supportedFileTypes];
    
    if ([fileTypes containsObject:AVFileTypeCoreAudioFormat]) {
        typeToUse = AVFileTypeCoreAudioFormat;
        extension = @"caf";

    } else if ([fileTypes containsObject:@"com.apple.m4a-audio"]) {
        typeToUse = @"com.apple.m4a-audio";
        extension = @"m4a";

    } else if ([fileTypes containsObject:@"public.mp3"]) {
        typeToUse = @"public.mp3";
        extension = @"mp3";

    } else {
        return NO;
    }
    
    temporaryFilePath = [temporaryFilePath stringByAppendingPathExtension:extension];
    _exportedURL = [NSURL fileURLWithPath:temporaryFilePath];

    [session setOutputFileType:typeToUse];
    [session setOutputURL:_exportedURL];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [session exportAsynchronouslyWithCompletionHandler:^{
        dispatch_semaphore_signal(semaphore);
    }];

    int64_t fifteenSecondsInNs = 15l * 1000 * 1000 * 1000;
    if (dispatch_semaphore_wait(semaphore, dispatch_time(0, fifteenSecondsInNs))) {
        HugLog(@"HugAudioFile", @"%@ dispatch_semaphore_wait() timed out!", self);
        [session cancelExport];
        return NO;
    }

    if ([session error]) {
        if (hasProtectedContent) {
            _error = sMakeError(HugErrorProtectedContent);
        } else {
            _error = sMakeError(HugErrorConversionFailed);
        }
    
        return NO;
    }
    
    return [self _reopenAudioFileWithURL:_exportedURL];
}


- (BOOL) _getFileDataFormat:(AudioStreamBasicDescription *)fileDataFormat
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileDataFormat, &size, fileDataFormat);

    if (err != noErr) {
        HugLog(@"HugAudioFile", @"%@, -getFileDataFormat: error %ld", self, (long)err);
        return NO;
    }

    return YES;
}


- (BOOL) _getFileLengthFrames:(SInt64 *)fileLengthFrames
{
    UInt32 size = sizeof(SInt64);
    OSStatus err = ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, fileLengthFrames);

    if (err != noErr) {
        HugLog(@"HugAudioFile", @"%@, -getFileLengthFrames: error %ld", self, (long)err);
        return NO;
    }

    return YES;
}


- (BOOL) _setClientDataFormat:(AudioStreamBasicDescription *)clientDataFormat
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = ExtAudioFileSetProperty(_extAudioFile, kExtAudioFileProperty_ClientDataFormat, size, clientDataFormat);

    if (err != noErr) {
        HugLog(@"HugAudioFile", @"%@, -setClientDataFormat: error %ld", self, (long)err);
        return NO;
    }

    return YES;
}


- (BOOL) _getClientDataFormat:(AudioStreamBasicDescription *)clientDataFormat
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = ExtAudioFileGetProperty(_extAudioFile, kExtAudioFileProperty_ClientDataFormat, &size, clientDataFormat);
    
    if (err != noErr) {
        HugLog(@"HugAudioFile", @"%@, -getClientDataFormat: returned %ld", self, (long)err);
        return NO;
    }

    return YES;
}


#pragma mark - Public Methods

- (BOOL) open
{
    if (_extAudioFile) {
        return !_error;
    }

    _error = sMakeError(HugErrorOpenFailed);
    
    OSStatus openErr = ExtAudioFileOpenURL((__bridge CFURLRef)_fileURL, &_extAudioFile);
    if (openErr != noErr) {
        HugLog(@"HugAudioFile", @"ExtAudioFileOpenURL() returned %ld", (long)openErr);
        return NO;
    }

    AudioStreamBasicDescription fileDataFormat = {0};
    
    if (![self _getFileDataFormat:&fileDataFormat]) {
        return NO;
    }
    
    AudioStreamBasicDescription clientDataFormat = {
        fileDataFormat.mSampleRate,
        kAudioFormatLinearPCM,
        kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
        /* mBytesPerPacket   */  sizeof(float),             
        /* mFramesPerPacket  */  1, 
        /* mBytesPerFrame    */  sizeof(float),
        /* mChannelsPerFrame */  fileDataFormat.mChannelsPerFrame,
        /* mBitsPerChannel   */  sizeof(float) * 8,
        0
    };

    if (![self _setClientDataFormat:&clientDataFormat]) {
        return NO;
    }
    
    if (![self _canRead] && ![self _convert] && ![self _canRead]) {
        return NO;
    }
    
    SInt64 fileLengthFrames = 0;
    if (![self _getFileLengthFrames:&fileLengthFrames]) {
        return NO;
    }

    _error            = nil;
    _fileLengthFrames = fileLengthFrames;
    _format           = clientDataFormat;

    return YES;
}


- (void) close
{
    if (_extAudioFile) {
        ExtAudioFileDispose(_extAudioFile);
        _extAudioFile = NULL;
    }
}


- (BOOL) readFrames:(inout UInt32 *)ioNumberFrames intoBufferList:(inout AudioBufferList *)bufferList
{
    if (_error) return NO;

    OSStatus err = ExtAudioFileRead(_extAudioFile, ioNumberFrames, bufferList);

    if (err != noErr) {
        HugLog(@"HugAudioFile", @"%@, -readFrames:intoBufferList: error %ld", self, (long)err);
        _error = sMakeError(HugErrorReadFailed);
        return NO;
    }

    return YES;
}


- (BOOL) seekToFrame:(SInt64)startFrame
{
    if (_error) return NO;

    OSStatus err = ExtAudioFileSeek(_extAudioFile, startFrame);
    
    if (err != noErr) {
        HugLog(@"HugAudioFile", @"%@, -seekToFrame: error %ld", self, (long)err);
        _error = sMakeError(HugErrorReadFailed);
        return NO;
    }

    return YES;
}


#pragma mark - Accessors

- (double) sampleRate
{
    return _format.mSampleRate;
}


- (NSInteger) channelCount
{
    return _format.mChannelsPerFrame;
}


@end
