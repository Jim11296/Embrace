//
//  AudioFileTableCellView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "AudioFileTableCellView.h"
#import "Track.h"
#import "Button.h"
#import "BorderedView.h"
#import "Preferences.h"
#import "AppDelegate.h"


@implementation AudioFileTableCellView {
    NSTextField *_endTimeField;
    Button *_errorButton;
    BOOL _endTimeVisible;
}


- (void) dealloc
{
    [_errorButton setTarget:nil];
    [_errorButton setAction:NULL];
}


- (NSArray *) keyPathsToObserve
{
    NSArray *result = [super keyPathsToObserve];
    
    return [result arrayByAddingObjectsFromArray:@[  @"artist", @"tonality", @"beatsPerMinute", @"trackError" ]];
}


- (void) showEndTime
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterNoStyle];
    [formatter setTimeStyle:NSDateFormatterMediumStyle];
    
    NSDate *endTime   = [[self track] estimatedEndTime];
    
    if (!endTime) return;
    
    NSString *endString = [formatter stringFromDate:endTime];

    if (!_endTimeField) {
        NSTextField *(^makeField)() = ^{
            NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];

            [field setFont:[_artistField font]];
            [field setBezeled:NO];
            [field setDrawsBackground:NO];
            [field setSelectable:NO];
            [field setEditable:NO];
            
            [field setAlphaValue:0];

            [[_artistField superview] addSubview:field];

            
            return field;
        };
    
        _endTimeField   = makeField();
        [_endTimeField setAlignment:NSRightTextAlignment];
    }

    [_endTimeField setStringValue:endString];
    [_endTimeField setTextColor:[self bottomTextColor]];

    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(_hideEndTime) withObject:nil afterDelay:2];

    _endTimeVisible = YES;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self _updateBottomFieldsAnimated:YES];
    } completionHandler:NULL];
}


- (void) _hideEndTime
{
    _endTimeVisible = NO;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self _updateBottomFieldsAnimated:YES];
    } completionHandler:NULL];
}


- (void) update
{
    [super update];
    [self _updateBottomFieldsAnimated:NO];
}


- (void) _errorButtonClicked:(id)sender
{
    [GetAppDelegate() displayErrorForTrackError:[[self track] trackError]];
}


- (void) _updateBottomFieldsAnimated:(BOOL)animated
{
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
    
    tonalityFrame.origin.x   = artistFrame.origin.x   = 14;
    tonalityFrame.size.width = artistFrame.size.width = superBounds.size.width - (14 + 14);
    
    [tonalityField setFrame:tonalityFrame];
    
    NSRect endTimeFrame = tonalityFrame;
    [_endTimeField setFrame:endTimeFrame];

    CGFloat tonalityWidth = 0;
    CGFloat endTimeWidth = 0;

    if ([stringValue length]) {
        [tonalityField sizeToFit];
        tonalityWidth = [tonalityField frame].size.width;
        [tonalityField setFrame:tonalityFrame];
    }
    
    if (_endTimeField && _endTimeVisible) {
        [_endTimeField sizeToFit];
        endTimeWidth = [_endTimeField frame].size.width;
        [_endTimeField setFrame:endTimeFrame];
    }
    
    CGFloat rightWidth = MAX(tonalityWidth, endTimeWidth);
    
    artistFrame.size.width -= rightWidth;
    tonalityFrame.size.width = rightWidth;
    tonalityFrame.origin.x = NSMaxX(artistFrame);

    endTimeFrame.size.width = rightWidth;
    endTimeFrame.origin.x = NSMaxX(artistFrame);

    [tonalityField setFrame:tonalityFrame];
    if (_endTimeVisible) {
        [_endTimeField setFrame:endTimeFrame];
    }

    if (animated) {
        [[artistField animator] setFrame:artistFrame];
        [[tonalityField animator] setAlphaValue:(_endTimeVisible ? 0.0 : 1.0)];
        [[_endTimeField animator] setAlphaValue:(_endTimeVisible ? 1.0 : 0)];
    } else {
        [artistField setFrame:artistFrame];
        [tonalityField setAlphaValue:(_endTimeVisible ? 0.0 : 1.0)];
        [_endTimeField setAlphaValue:(_endTimeVisible ? 1.0 : 0)];
    }

    [artistField   setTextColor:[self bottomTextColor]];
    [tonalityField setTextColor:[self bottomTextColor]];
    
    TrackError trackError = [[self track] trackError];
    
    if (trackError && !_errorButton) {
        [[self durationField]       setHidden:YES];
        [[self tonalityAndBPMField] setHidden:YES];

        NSSize boundsSize = [self bounds].size;
        
        NSRect errorFrame = NSMakeRect(boundsSize.width - 34, round((boundsSize.height - 16) / 2), 16, 16);

        _errorButton = [[Button alloc] initWithFrame:errorFrame];
        [_errorButton setImage:[NSImage imageNamed:@"track_error_template"]];
        [_errorButton setAlert:YES];
        [_errorButton setAutoresizingMask:NSViewMinXMargin];

        [_errorButton setTarget:self];
        [_errorButton setAction:@selector(_errorButtonClicked:)];
        
        [_errorButton setAlertColor:GetRGBColor(0xff0000, 1.0)];
        [_errorButton setAlertActiveColor:GetRGBColor(0xd00000, 1.0)];
        
        [self addSubview:_errorButton];


    } else if (_errorButton && !trackError) {
        [[self durationField]       setHidden:NO];
        [[self tonalityAndBPMField] setHidden:NO];

        [_errorButton setTarget:nil];
        [_errorButton setAction:NULL];

        [_errorButton removeFromSuperview];
    }
}


@end
