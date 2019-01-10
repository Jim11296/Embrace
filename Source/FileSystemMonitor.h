// (c) 2017-2019 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@class FileSystemMonitorEvent;

typedef void (^FileSystemMonitorCallback)(NSArray<FileSystemMonitorEvent *> *events);


@interface FileSystemMonitor : NSObject

- (instancetype) initWithURL:(NSURL *)url callback:(FileSystemMonitorCallback)callback;

- (void) start;
- (void) stop;

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly, copy) FileSystemMonitorCallback callback;

@end


@interface FileSystemMonitorEvent : NSObject
@property (nonatomic, readonly) FSEventStreamEventId eventId;
@property (nonatomic, readonly) FSEventStreamEventFlags eventFlags;
@property (nonatomic, readonly) NSString *eventPath;
@end

