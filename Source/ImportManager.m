//
//  ImportManager.m
//  Embrace
//
//  Created by Ricci Adams on 2016-07-31.
//  Copyright © 2016 Ricci Adams. All rights reserved.
//

#import "ImportManager.h"
#import "Track.h"

static NSInteger sMaxDepth = 5;


@implementation ImportManager {
    NSArray *_cachedInput;
    NSArray *_cachedResults;
}


+ (id) sharedInstance
{
    static ImportManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[ImportManager alloc] init];
    });

    return sSharedInstance;
}


- (BOOL) canOpenURLs:(NSArray<NSURL *> *)inURLS
{
    NSArray *collectedURLs = [self _collectedAudioFileURLsWithURLs:inURLS];
    return [collectedURLs count] > 0;
}


- (NSArray<Track *> *) tracksWithURLs:(NSArray *)inURLs
{
    NSArray *collectedURLs = [self _collectedAudioFileURLsWithURLs:inURLs];
    
    NSMutableArray *tracks = [NSMutableArray array];

    for (NSURL *collectedURL in collectedURLs) {
        Track *track = [Track trackWithFileURL:collectedURL];
        if (track) [tracks addObject:track];
    }

    return tracks;
}


- (NSArray<NSURL *> *) _collectedAudioFileURLsWithURLs:(NSArray<NSURL *> *)inURLs
{
    if (inURLs && [_cachedInput isEqual:inURLs]) {
        return _cachedResults;
    }
    
    NSMutableArray *results = [NSMutableArray array];

    for (NSURL *inURL in inURLs) {
        sCollectURL(inURL, results, 0);
    }
    
    _cachedInput   = inURLs;
    _cachedResults = results;

    return results;
}



static NSString *sGetFileType(NSURL *url)
{
    NSString *typeIdentifier = nil;
    NSError  *error = nil;
    [url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:&error];

    return typeIdentifier;
}


static void sCollectURL(NSURL *inURL, NSMutableArray *results, NSInteger depth)
{
    if (depth > sMaxDepth) {
        return;
    }
    
    depth++;

    NSString *type = sGetFileType(inURL);
    if (!type) return;

    if (UTTypeConformsTo((__bridge CFStringRef)type, kUTTypeM3UPlaylist)) {
        if (depth < sMaxDepth) {
            sCollectM3UPlaylistURL(inURL, results, depth);
        }

    } else if (UTTypeConformsTo((__bridge CFStringRef)type, kUTTypeFolder)) {
        if (depth < sMaxDepth) {
            sCollectFolderURL(inURL, results, depth);
        }

    } else if (UTTypeConformsTo((__bridge CFStringRef)type, kUTTypeAudiovisualContent)) {
        [results addObject:inURL];
    }
}


static void sCollectFolderURL(NSURL *inURL, NSMutableArray *results, NSInteger depth)
{
    NSDirectoryEnumerationOptions options =
        NSDirectoryEnumerationSkipsSubdirectoryDescendants |
        NSDirectoryEnumerationSkipsPackageDescendants |    
        NSDirectoryEnumerationSkipsHiddenFiles;
        
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:inURL includingPropertiesForKeys:@[ NSURLTypeIdentifierKey ] options:options error:&error];

    for (NSURL *url in contents) {
        sCollectURL(url, results, depth);
    }
}


static void sCollectM3UPlaylistURL(NSURL *inURL, NSMutableArray *results, NSInteger depth)
{
    EmbraceLog(@"ImportManager", @"Parsing M3U at: %@", inURL);

    NSData *data = [NSData dataWithContentsOfURL:inURL];
    if (!data) return;
    
    NSString *contents = nil;
    if (!contents || [contents length] < 8) {
        EmbraceLog(@"ImportManager", @"Trying UTF-8 encoding");
        contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    if (!contents || [contents length] < 8) {
        EmbraceLog(@"ImportManager", @"Trying UTF-16 encoding");
        contents = [[NSString alloc] initWithData:data encoding:NSUTF16StringEncoding];
    }

    if (!contents || [contents length] < 8) {
        EmbraceLog(@"ImportManager", @"Trying Latin-1 encoding");
        contents = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    
    if ([contents length] >= 8) {
        for (NSString *line in [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            if ([line hasPrefix:@"#"]) {
                continue;

            } else if ([line hasPrefix:@"file:"]) {
                NSURL *url = [NSURL URLWithString:line];
                
                if ([url isFileURL]) {
                    sCollectURL(url, results, depth);
                }
                
            } else {
                NSURL *url = [NSURL fileURLWithPath:[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                
                if ([url isFileURL]) {
                    sCollectURL(url, results, depth);
                }
            }
        }
    }

    EmbraceLog(@"ImportManager", @"Results: %@", results);
}


@end
