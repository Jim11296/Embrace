//
//  AudioFileTableCellView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "AudioFileTableCellView.h"
#import "Track.h"
#import "BorderedView.h"
#import "Preferences.h"

@implementation AudioFileTableCellView

- (NSArray *) keyPathsToObserve
{
    NSArray *result = [super keyPathsToObserve];
    
    return [result arrayByAddingObjectsFromArray:@[  @"artist", @"tonality", @"beatsPerMinute" ]];
}


- (void) update
{
    [super update];
    
    Track *track = [self track];
    if (!track) return;

    NSString *artist = [track artist];
    if (!artist) artist = @"";
    [[self artistField] setStringValue:artist];

    Preferences *preferences = [Preferences sharedInstance];

    TonalityDisplayMode tonalityDisplayMode = [preferences tonalityDisplayMode];
    Tonality tonality = [track tonality];
    NSString *tonalityString = nil;

    if (tonality) {
        if (tonalityDisplayMode == TonalityDisplayModeTraditional) {
            tonalityString = GetTraditionalStringForTonality(tonality);
        } else if (tonalityDisplayMode == TonalityDisplayModeCamelot) {
            tonalityString = GetCamelotStringForTonality(tonality);
        }
    }
    
    NSString *bpmString = nil;
    NSInteger bpm = [track beatsPerMinute];
    if ([preferences showsBPM] && bpm) {
        bpmString = [NSString stringWithFormat:@"%ld", (long)[track beatsPerMinute]];
    }
    
    
    NSString *stringValue = @"";
    if (tonalityString && bpmString) {
        stringValue = [NSString stringWithFormat:@"%@, %@", bpmString, tonalityString];
    } else if (bpmString) {
        stringValue = bpmString;
    } else if (tonalityString) {
        stringValue = tonalityString;
    }

    NSTextField *artistField   = [self artistField];
    NSTextField *tonalityField = [self tonalityAndBPMField];
   
    if ([stringValue length]) {
        [tonalityField setStringValue:stringValue];
    } else {
        [tonalityField setStringValue:@""];
    }
    
    NSRect superBounds   = [[artistField superview] bounds];
    NSRect tonalityFrame = [tonalityField frame];
    NSRect artistFrame   = [artistField frame];
    
    tonalityFrame.origin.x   = artistFrame.origin.x   = 18;
    tonalityFrame.size.width = artistFrame.size.width = superBounds.size.width - (18 + 14);
    
    [artistField setFrame:artistFrame];
    [tonalityField setFrame:tonalityFrame];

    CGFloat tonalityWidth = 0;
    if ([stringValue length]) {
        [tonalityField sizeToFit];
        tonalityWidth = [tonalityField frame].size.width;
        [tonalityField setFrame:tonalityFrame];
    }
    
    artistFrame.size.width -= tonalityWidth;
    tonalityFrame.size.width = tonalityWidth;
    tonalityFrame.origin.x = NSMaxX(artistFrame);

    [artistField setFrame:artistFrame];
    [tonalityField setFrame:tonalityFrame];
}


@end
