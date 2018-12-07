// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "HugAudioFile.h"
#import "HugUtils.h"

#import <AVFoundation/AVFoundation.h>


@implementation HugAudioFile {
    NSURL *_fileURL;
    NSURL *_exportedURL;
    ExtAudioFileRef _audioFile;
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

    [self _clearAudioFile];
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

- (void) _clearAudioFile
{
    if (_audioFile) {
        ExtAudioFileDispose(_audioFile);
        _audioFile = NULL;
    }
}

- (OSStatus) _reopenAudioFileWithURL:(NSURL *)url
{
    AudioStreamBasicDescription fileDataFormat   = {0};
    AudioStreamBasicDescription clientDataFormat = {0};
    
    OSStatus err = noErr;

    if (err == noErr) {
        err = [self _getClientDataFormat:&clientDataFormat];
    }

    [self _clearAudioFile];

    if (err == noErr) {
        err = ExtAudioFileOpenURL((__bridge CFURLRef)_exportedURL, &_audioFile);
        if (err != noErr) HugLog(@"HugAudioFile", @"%@, ExtAudioFileOpenURL() failed %ld", self, (long)err);
    }
    
    if (err == noErr) {
        err = [self _setClientDataFormat:&clientDataFormat];
    }

    if (err == noErr) {
        err = [self _getFileDataFormat:&fileDataFormat];
    }

    if (err != noErr) HugLog(@"HugAudioFile", @"%@, -_reopenAudioFileWithURL: error %ld", self, (long)err);
    
    return err;
}


- (BOOL) _canRead
{
    SInt64 fileLengthFrames = 0;
    OSStatus err = noErr;
    
    if (err == noErr) {
        err = [self _getFileLengthFrames:&fileLengthFrames];
    }
    
    AudioStreamBasicDescription clientDataFormat = {0};
    
    if (err == noErr) {
        err = [self _getClientDataFormat:&clientDataFormat];
    }

    UInt32 channelCount = clientDataFormat.mChannelsPerFrame;
    if (!channelCount) return NO;

    AudioBufferList *bufferList = alloca(sizeof(AudioBufferList) * channelCount);

    bufferList->mNumberBuffers = channelCount;

    UInt32 framesToRead = 1024;

    for (NSInteger i = 0; i < channelCount; i++) {
        bufferList->mBuffers[i].mNumberChannels = 1;
        bufferList->mBuffers[i].mDataByteSize = framesToRead * sizeof(float);
        bufferList->mBuffers[i].mData = alloca(framesToRead * sizeof(float));
    }

    SInt64 frameOffset = 0;
    if (err == noErr) {
        err = ExtAudioFileTell(_audioFile, &frameOffset);
    }

    if (err == noErr) {
        err = ExtAudioFileRead(_audioFile, &framesToRead, bufferList);
    }
    
    if (err == noErr) {
        err = ExtAudioFileSeek(_audioFile, frameOffset);
    }
    
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
            _audioFileError = HugAudioFileErrorProtectedContent;
        } else {
            _audioFileError = HugAudioFileErrorConversionFailed;
        }
    
        return NO;
    }
    
    OSStatus err = [self _reopenAudioFileWithURL:_exportedURL];

    return err == noErr;
}


- (OSStatus) _getFileDataFormat:(AudioStreamBasicDescription *)fileDataFormat
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileDataFormat, &size, fileDataFormat);

    if (err != noErr) HugLog(@"HugAudioFile", @"%@, -getFileDataFormat: error %ld", self, (long)err);

    return err;
}


- (OSStatus) _getFileLengthFrames:(SInt64 *)fileLengthFrames
{
    UInt32 size = sizeof(SInt64);
    OSStatus err = ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileLengthFrames, &size, fileLengthFrames);

    if (err != noErr) HugLog(@"HugAudioFile", @"%@, -getFileLengthFrames: error %ld", self, (long)err);

    return err;
}


- (OSStatus) _setClientDataFormat:(AudioStreamBasicDescription *)clientDataFormat
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, size, clientDataFormat);

    if (err != noErr) HugLog(@"HugAudioFile", @"%@, -setClientDataFormat: error %ld", self, (long)err);

    return err;
}


- (OSStatus) _getClientDataFormat:(AudioStreamBasicDescription *)clientDataFormat
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, &size, clientDataFormat);
    
    if (err != noErr) HugLog(@"HugAudioFile", @"%@, -getClientDataFormat: returned %ld", self, (long)err);

    return err;
}


#pragma mark - Public Methods

- (BOOL) prepare
{
    if (_audioFile) return NO;

    _audioFileError = HugAudioFileErrorOpenFailed;
    
    OSStatus openErr = ExtAudioFileOpenURL((__bridge CFURLRef)_fileURL, &_audioFile);
    if (openErr != noErr) {
        HugLog(@"HugAudioFile", @"ExtAudioFileOpenURL() returned %ld", (long)openErr);
        return NO;
    }

    AudioStreamBasicDescription fileDataFormat = {0};
    
    if ([self _getFileDataFormat:&fileDataFormat] != noErr) {
        return NO;
    }

    AudioStreamBasicDescription clientDataFormat = {
        fileDataFormat.mSampleRate,
        kAudioFormatLinearPCM,
        kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
        sizeof(float),    // mBytesPerPacket
        1,                // mFramesPerPacket
        sizeof(float),    // mBytesPerFrame
        fileDataFormat.mChannelsPerFrame,
        sizeof(float) * 8 // mBitsPerChannel
    };

    if ([self _setClientDataFormat:&clientDataFormat] != noErr) {
        return NO;
    }
    
    if (![self _canRead] && ![self _convert] && ![self _canRead]) {
        return NO;
    }
    
    SInt64 fileLengthFrames = 0;
    if ([self _getFileLengthFrames:&fileLengthFrames] != noErr) {
        return NO;
    }

    _audioFileError   = HugAudioFileErrorNone;
    _fileLengthFrames = fileLengthFrames;
    _format           = clientDataFormat;

    return YES;
}


- (OSStatus) readFrames:(inout UInt32 *)ioNumberFrames intoBufferList:(inout AudioBufferList *)bufferList
{
    OSStatus err = ExtAudioFileRead(_audioFile, ioNumberFrames, bufferList);
    if (err != noErr) HugLog(@"HugAudioFile", @"%@, -readFrames:intoBufferList: error %ld", self, (long)err);
    return err;
}


- (OSStatus) seekToFrame:(SInt64)startFrame
{
    OSStatus err = ExtAudioFileSeek(_audioFile, startFrame);
    if (err != noErr) HugLog(@"HugAudioFile", @"%@, -seekToFrame: error %ld", self, (long)err);
    return err;
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
