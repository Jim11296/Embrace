//
//  Log.m
//  Embrace
//
//  Created by Ricci Adams on 2014-03-26.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Log.h"

static NSString *sLogFileDirectory = nil;

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


void EmbraceLogSetDirectory(NSString *path)
{
    if (sLogFileHandle) return;

    NSFileManager *manager = [NSFileManager defaultManager];

    NSError *error = nil;

    [manager createDirectoryAtURL:[NSURL fileURLWithPath:path] withIntermediateDirectories:YES attributes:nil error:&error];

    EmbraceCleanupLogs([NSURL fileURLWithPath:path isDirectory:YES]);
    sLogFileDirectory = [path copy];

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


NSString *EmbraceLogGetDirectory(void)
{
    return sLogFileDirectory;
}


void EmbraceLog(NSString *category, NSString *format, ...)
{
    if (!sLogFileHandle) return;

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
    
    NSLog(@"%@", line);
    
    va_end(v);
}


void _EmbraceLogMethod(const char *f)
{
    NSString *string = [NSString stringWithUTF8String:f];

    if ([string hasPrefix:@"-["] || [string hasPrefix:@"+["]) {
        NSCharacterSet *cs = [NSCharacterSet characterSetWithCharactersInString:@"+-[]"];
        
        string = [string stringByTrimmingCharactersInSet:cs];
        NSArray *components = [string componentsSeparatedByString:@" "];
        
        EmbraceLog([components firstObject], @"%@", [components lastObject]);
        
    } else {
        EmbraceLog(@"Function", @"%@", string);
    }
}

