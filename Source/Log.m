//
//  Log.m
//  Embrace
//
//  Created by Ricci Adams on 2014-03-26.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Log.h"
#import "Utils.h"


static NSFileHandle *sLogFileHandle = nil;
static NSDateFormatter *sLogFileDateFormatter = nil;


void EmbraceCleanupLogs(NSURL *directoryURL)
{
    NSArray *keys = @[
        NSURLCreationDateKey
    ];

    NSDirectoryEnumerationOptions options =
        NSDirectoryEnumerationSkipsSubdirectoryDescendants |
        NSDirectoryEnumerationSkipsPackageDescendants |
        NSDirectoryEnumerationSkipsHiddenFiles;
    
    __block NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directoryURL includingPropertiesForKeys:keys options:options error:&error];

    NSMutableArray *logURLs = [[contents sortedArrayUsingComparator:^(id a, id b) {
        NSURL *aURL = (NSURL *)a;
        NSURL *bURL = (NSURL *)b;
        
        NSDate *aDate = nil;
        if (![aURL getResourceValue:&aDate forKey:NSURLCreationDateKey error:&error]) {
            return NSOrderedSame;
        }
        
        NSDate *bDate = nil;
        if (![bURL getResourceValue:&bDate forKey:NSURLCreationDateKey error:&error]) {
            return NSOrderedSame;
        }

        if (aDate && bDate) {
            return [aDate compare:bDate];
        } else {
            return NSOrderedSame;
        }
    }] mutableCopy];
    
    while ([logURLs count] > 30) {
        NSURL *logToRemove = [logURLs firstObject];
        if (logToRemove) [logURLs removeObjectAtIndex:0];

        [[NSFileManager defaultManager] removeItemAtURL:logToRemove error:&error];
    }
}


void EmbraceOpenLogFile()
{
    if (sLogFileHandle) return;

    NSFileManager *manager = [NSFileManager defaultManager];

    NSError *error = nil;

    NSString *path = GetApplicationSupportDirectory();
    path = [path stringByAppendingPathComponent:@"Logs"];

    [manager createDirectoryAtURL:[NSURL fileURLWithPath:path] withIntermediateDirectories:YES attributes:nil error:&error];

    EmbraceCleanupLogs([NSURL fileURLWithPath:path isDirectory:YES]);

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd 'at' HH'.'mm'.'ss'.log'"];

    NSString *filename = [dateFormatter stringFromDate:[NSDate date]];
    path = [path stringByAppendingPathComponent:filename];

    if (![manager fileExistsAtPath:path]) {
        [manager createFileAtPath:path contents:[NSData data] attributes:nil];
    }
    
    sLogFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    [sLogFileHandle seekToEndOfFile];
}


void EmbraceLog(NSString *category, NSString *format, ...)
{
    if (!sLogFileHandle) {
        EmbraceOpenLogFile();
    }

    va_list v;

    va_start(v, format);

    if (!sLogFileDateFormatter) {
        sLogFileDateFormatter = [[NSDateFormatter alloc] init];
        [sLogFileDateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        [sLogFileDateFormatter setDateStyle:NSDateFormatterNoStyle];
    }

    NSString *dateString = [sLogFileDateFormatter stringFromDate:[NSDate date]];
    NSString *contents = [[NSString alloc] initWithFormat:format arguments:v];

    NSString *line = [NSString stringWithFormat:@"%@ [%@] %@\n", dateString, category, contents];
    [sLogFileHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    
    va_end(v);
}

