//
//  OutputWindowController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "ExportManager.h"
#import "Track.h"


@implementation ExportManager {
    ExportManagerFormat _format;
    NSSavePanel *_savePanel;
}


+ (id) sharedInstance
{
    static ExportManager *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sSharedInstance = [[ExportManager alloc] init];
    });

    return sSharedInstance;
}


- (NSInteger) runModalWithTracks:(NSArray<Track *> *)tracks
{
    EmbraceLogMethod();

    NSSavePanel *savePanel = [NSSavePanel savePanel];
    _savePanel = savePanel; 

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterLongStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    
    NSDate *date = [[tracks firstObject] playedTimeDate];
    if (!date) date = [NSDate date];
    
    NSString *dateString = [formatter stringFromDate:date];

    NSString *suggestedNameFormat = NSLocalizedString(@"Embrace (%@)", nil);
    NSString *suggestedName = [NSString stringWithFormat:suggestedNameFormat, dateString];
    [savePanel setNameFieldStringValue:suggestedName];

    [savePanel setTitle:NSLocalizedString(@"Save Set List", nil)];

    NSView  *view = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 200, 41.0)];
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 8, 60, 22)];
    [label setEditable:NO];
    [label setStringValue:NSLocalizedString(@"Format:", nil)];
    [label setBordered:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setFont:[NSFont controlContentFontOfSize:13]];

    NSPopUpButton *popupButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(55.0, 9, 145, 22.0) pullsDown:NO];
    [popupButton addItemsWithTitles:@[ @"Plain Text", @"M3U", @"M3U8" ]];
    [popupButton setTarget:self];
    [popupButton setAction:@selector(_selectFormat:)];
    
    NSInteger exportIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"export-index"];
    [popupButton selectItemAtIndex:exportIndex];
    [self _selectFormat:popupButton];

    [view addSubview:label];
    [view addSubview:popupButton];

    [savePanel setAccessoryView:view];

    if (!LoadPanelState(savePanel, @"save-set-list-panel")) {
        NSString *desktopPath = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) firstObject];
        
        if (desktopPath) {
            [savePanel setDirectoryURL:[NSURL fileURLWithPath:desktopPath]];
        }
    }
   
    NSInteger result = [savePanel runModal];

    if (result == NSModalResponseOK) {
        SavePanelState(savePanel, @"save-set-list-panel");
        
        NSURL *URL = [savePanel URL];

        NSString *contents = [self stringWithFormat:_format tracks:tracks];

        NSError *error = nil;
        [contents writeToURL:URL atomically:YES encoding:NSUTF8StringEncoding error:&error];

        if (error) {
            EmbraceLog(@"ExportManager", @"Error saving set list to %@, %@", URL, error);
            NSBeep();
        }
    }
    
    _format    = ExportManagerFormatNone;
    _savePanel = nil;
    
    return result;
}


- (void) _selectFormat:(id)sender
{
    NSInteger index = [sender indexOfSelectedItem];
    NSString *name  = [_savePanel nameFieldStringValue];
    NSString *extension;

    if (index == 2) {
        extension = @"m3u8";
        _format = ExportManagerFormatM3U;

    } else if (index == 1) {
        extension = @"m3u";
        _format = ExportManagerFormatM3U;
    
    } else {
        extension = @"txt";
        _format = ExportManagerFormatPlainText;
    }

    name = [name stringByDeletingPathExtension];
    name = [name stringByAppendingPathExtension:extension];

    [_savePanel setNameFieldStringValue:name];
    [_savePanel setAllowedFileTypes:@[ extension ]];
    
    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"export-index"];
}


- (NSString *) _artistAndTitleWithTrack:(Track *)track
{
    NSMutableString *result = [NSMutableString string];

    NSString *artist = [track artist];
    if (artist) [result appendFormat:@"%@ %C ", artist, (unichar)0x2014];
    
    NSString *title = [track title];
    if (!title) title = @"???";

    [result appendFormat:@"%@", title];

    return result;
}


- (NSString *) _plainTextStringWithTracks:(NSArray<Track *> *)tracks
{
    NSMutableArray *played = [NSMutableArray array];
    NSMutableArray *queued = [NSMutableArray array];

    for (Track *track in tracks) {
        NSString *line = [self _artistAndTitleWithTrack:track];

        if ([track trackStatus] == TrackStatusQueued) {
            [queued addObject:line];
        } else {
            [played addObject:line];
        }
    }
    
    NSString *result = @"";
    NSString *playedString = [played count] ? [played componentsJoinedByString:@"\n"] : nil;
    NSString *queuedString = [queued count] ? [queued componentsJoinedByString:@"\n"] : nil;

    if (playedString && queuedString) {
        result = [NSString stringWithFormat:@"%@\n\nUnplayed:\n%@", playedString, queuedString];

    } else if (queuedString) {
        result = queuedString;

    } else if (playedString) {
        result = playedString;
    }
    
    return result;
}


- (NSString *) _M3UStringWithTracks:(NSArray<Track *> *)tracks
{
    NSMutableArray *lines = [NSMutableArray array];
    
    [lines addObject:@"#EXTM3U"];
    
    for (Track *track in tracks) {
        NSInteger duration = ceil([track duration]);
        NSString *title    = [self _artistAndTitleWithTrack:track];
        NSString *filePath = [[track externalURL] path];
        
        [lines addObject:@""];
        [lines addObject:[NSString stringWithFormat:@"#EXTINF:%ld,%@", (long)duration, title]];
        if  (filePath) [lines addObject:filePath];
    }
    
    [lines addObject:@""];

    return [lines componentsJoinedByString:@"\n"];
}


- (NSString *) stringWithFormat:(ExportManagerFormat)format tracks:(NSArray<Track *> *)tracks
{
    if (format == ExportManagerFormatPlainText) {
        return [self _plainTextStringWithTracks:tracks];
    } else if (format == ExportManagerFormatM3U) {
        return [self _M3UStringWithTracks:tracks];
    }
    
    return nil;
}


@end
