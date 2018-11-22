// (c) 2017-2018 Ricci Adams.  All rights reserved.

#import "FileSystemMonitor.h"


@interface FileSystemMonitor ()
- (void) _invokeCallbackWithEvents:(NSArray<FileSystemMonitorEvent *> *)events;
@end


@interface FileSystemMonitorEvent ()

- (instancetype) _initWithEventId: (FSEventStreamEventId) eventId
                       eventFlags: (FSEventStreamEventFlags) eventFlags
                        eventPath: (NSString *) eventPath;

@end


static void sEventStreamCallback(
    ConstFSEventStreamRef streamRef, 
    void *clientCallBackInfo, 
    size_t eventCount, 
    void *rawEventPaths, 
    const FSEventStreamEventFlags eventFlags[], 
    const FSEventStreamEventId eventIds[]
) {
    NSMutableArray *events = [NSMutableArray array];
    NSArray *eventPaths = (__bridge NSArray *)rawEventPaths;

    NSInteger i = 0;
    for (NSString *eventPath in eventPaths) {
        FileSystemMonitorEvent *event = [[FileSystemMonitorEvent alloc] _initWithEventId:eventIds[i] eventFlags:eventFlags[i] eventPath:eventPath];
        [events addObject:event];
        i++;
    }


    FileSystemMonitor *monitor = (__bridge id)clientCallBackInfo;
    __weak FileSystemMonitor *weakMonitor = monitor;

    dispatch_async(dispatch_get_main_queue(), ^{
        [weakMonitor _invokeCallbackWithEvents:events];
    });
}


@implementation FileSystemMonitor {
    dispatch_queue_t _eventQueue;
    FSEventStreamRef _eventStream;
    FileSystemMonitorCallback _callback;
}

- (instancetype) initWithURL:(NSURL *)url callback:(FileSystemMonitorCallback)callback
{
    if ((self = [super init])) {
        NSString *path = [url path];
        
        if (path && callback) {
            [self _setupWithPath:path callback:callback];
        }
    }

    return self;
}

- (void) dealloc
{
    FSEventStreamSetDispatchQueue(_eventStream, NULL);
    FSEventStreamInvalidate(_eventStream);
    FSEventStreamRelease(_eventStream);
    _eventStream = NULL;
}

- (void) _invokeCallbackWithEvents:(NSArray<FileSystemMonitorEvent *> *)events
{
    if (_callback) {
        _callback(events);
    }
}


- (void) _setupWithPath:(NSString *)path callback:(FileSystemMonitorCallback)callback
{
    NSArray *paths = @[ path ];

    _callback = [callback copy];

    FSEventStreamContext callbackInfo = {0};

    callbackInfo.version = 0;
    callbackInfo.info    = (__bridge void *)self;
    callbackInfo.retain  = NULL;
    callbackInfo.release = NULL;
    callbackInfo.copyDescription = NULL;

    _eventQueue = dispatch_queue_create("FileSystemMonitor", DISPATCH_QUEUE_SERIAL);
    
    _eventStream = FSEventStreamCreate(
        kCFAllocatorDefault, 
        &sEventStreamCallback,
        &callbackInfo, 
        (__bridge CFArrayRef)paths, 
        kFSEventStreamEventIdSinceNow, 
        0.1, 
        kFSEventStreamCreateFlagUseCFTypes
    );

    FSEventStreamSetDispatchQueue(_eventStream, _eventQueue);
    
}

- (void) start
{
    FSEventStreamStart(_eventStream);
    FSEventStreamFlushAsync(_eventStream);
}


- (void) stop
{
    FSEventStreamStop(_eventStream);
}


@end


@implementation FileSystemMonitorEvent

- (instancetype) _initWithEventId: (FSEventStreamEventId) eventId
                       eventFlags: (FSEventStreamEventFlags) eventFlags
                        eventPath: (NSString *) eventPath
{
    if ((self = [super init])) {
        _eventId = eventId;
        _eventFlags = eventFlags;
        _eventPath = eventPath;
    }
    
    return self;
}

@end

