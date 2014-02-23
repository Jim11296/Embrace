//
//  SongTableViewCell.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrackTableCellView.h"
#import "Track.h"
#import "BorderedView.h"
#import "Button.h"
#import "AppDelegate.h"
#import "Preferences.h"


@implementation TrackTableCellView {
    NSArray *_observedKeyPaths;
    id       _observedObject;

    Button *_errorButton;
    NSTextField *_endTimeField;
    BOOL _endTimeVisible;
}

- (void) dealloc
{
    [self _removeObservers];

    [_errorButton setTarget:nil];
    [_errorButton setAction:NULL];
}


- (void) mouseDown:(NSEvent *)theEvent
{
    [super mouseDown:theEvent];

    NSUInteger mask = (NSControlKeyMask | NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask);
    
    if (([theEvent modifierFlags] & mask) == NSControlKeyMask) {
        [self _tryToPresentContextMenuWithEvent:theEvent];
    }
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _observedObject) {
        if ([_observedKeyPaths containsObject:keyPath]) {
            [self _updateAll];
        }
    }
}


- (void) setObjectValue:(id)objectValue
{
    [self _removeObservers];

    [super setObjectValue:objectValue];
    
    _observedKeyPaths = @[
        @"title",
        @"artist",
        @"playDuration",
        @"pausesAfterPlaying",
        @"artist",
        @"tonality",
        @"beatsPerMinute",
        @"trackStatus",
        @"trackError"
    ];
    
    _observedObject = objectValue;

    for (NSString *keyPath in _observedKeyPaths) {
        [_observedObject addObserver:self forKeyPath:keyPath options:0 context:NULL];
    }

    [self _updateAll];
}


#pragma mark - Private Methods

- (void) _removeObservers
{
    for (NSString *keyPath in _observedKeyPaths) {
        [_observedObject removeObserver:self forKeyPath:keyPath context:NULL];
    }

    _observedKeyPaths = nil;
    _observedObject   = nil;
}


- (BOOL) _tryToPresentContextMenuWithEvent:(NSEvent *)event
{
    NSView *superview = [self superview];
    NSMenu *menu = nil;

    while (superview) {
        if ([superview isKindOfClass:[NSTableView class]]) {
            menu = [superview menu];
            if (menu) break;
        }
        
        superview = [superview superview];
    }
    
    if (menu) {
        [NSMenu popUpContextMenu:menu withEvent:event forView:self];
        return YES;
    }
    
    return NO;

}


- (NSColor *) _topTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if (trackStatus == TrackStatusPlaying) {
        return GetRGBColor(0x1866e9, 1.0);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.4);
    }
    
    return [NSColor blackColor];
}


- (NSColor *) _bottomTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if (trackStatus == TrackStatusPlaying) {
        return GetRGBColor(0x1866e9, 0.8);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.33);
    }
    
    return GetRGBColor(0x000000, 0.66);
}


- (void) _errorButtonClicked:(id)sender
{
    [GetAppDelegate() displayErrorForTrackError:[[self track] trackError]];
}


- (void) _hideEndTime
{
    _endTimeVisible = NO;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self _updateBottomFieldsAnimated:YES];
    } completionHandler:NULL];
}


#pragma mark - Update

- (void) _updateAll
{
    [self _updateBorderedView];
    [self _updateTopFields];
    [self _updateBottomFieldsAnimated:NO];
    [self _updateErrorButton];
}


- (void) _updateBorderedView
{
    Track *track = [self track];
    if (!track) return;

    BorderedView *borderedView = [self borderedView];

    NSColor *bottomBorderColor = [NSColor colorWithCalibratedWhite:(0xE8 / 255.0) alpha:1.0];
    CGFloat bottomBorderHeight = -1;
    BOOL usesDashes = NO;

    if ([track pausesAfterPlaying] && ([track trackStatus] != TrackStatusPlayed)) {
        bottomBorderColor = [NSColor redColor];
        bottomBorderHeight = 2;
        usesDashes = YES;
    }

    [borderedView setBottomBorderColor:bottomBorderColor];
    [borderedView setBottomBorderHeight:bottomBorderHeight];
    [borderedView setUsesDashes:usesDashes];

    if (_selected) {
        [borderedView setBackgroundColor:GetRGBColor(0xecf2fe, 1.0)];
    } else {
        [borderedView setBackgroundColor:nil];
    }

    if (_drawsInsertionPointWorkaround) {
        [borderedView setTopBorderColor:GetRGBColor(0x3874d7, 1.0)];
        [borderedView setTopBorderHeight:3];
    } else {
        [borderedView setTopBorderColor:nil];
        [borderedView setTopBorderHeight:0];
    }
}


- (void) _updateTopFields
{
    Track *track = [self track];
    if (!track) return;

    NSString *titleString = [track title];
    if (!titleString) titleString = @"";
    [[self titleField] setStringValue:titleString];
    [[self titleField] setTextColor:[self _topTextColor]];
    
    NSString *durationString = GetStringForTime(round([track playDuration]));
    if (!durationString) durationString = @"";
    [[self durationField] setStringValue:durationString];
    [[self durationField] setTextColor:[self _topTextColor]];
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

    [artistField   setTextColor:[self _bottomTextColor]];
    [tonalityField setTextColor:[self _bottomTextColor]];
}


- (void) _updateErrorButton
{
    TrackError trackError = [[self track] trackError];
    
    if (trackError) {
        NSSize boundsSize = [self bounds].size;
        NSRect errorFrame = NSMakeRect(boundsSize.width - 34, round((boundsSize.height - 16) / 2), 16, 16);

        if (!_errorButton) {
            _errorButton = [[Button alloc] initWithFrame:errorFrame];
            [self addSubview:_errorButton];

            [_errorButton setImage:[NSImage imageNamed:@"track_error_template"]];
            [_errorButton setAutoresizingMask:NSViewMinXMargin];
            [_errorButton setTarget:self];
            [_errorButton setAction:@selector(_errorButtonClicked:)];
            [_errorButton setAlertColor:GetRGBColor(0xff0000, 1.0)];
            [_errorButton setAlertActiveColor:GetRGBColor(0xd00000, 1.0)];

            [_errorButton setAlert:YES];
        }
    
        [[self durationField]       setHidden:YES];
        [[self tonalityAndBPMField] setHidden:YES];
       
        [_errorButton setFrame:errorFrame];
        [self addSubview:_errorButton];

    } else if (!trackError) {
        [[self durationField]       setHidden:NO];
        [[self tonalityAndBPMField] setHidden:NO];

        [_errorButton removeFromSuperview];
    }
}


#pragma mark - Public Methods

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
    [_endTimeField setTextColor:[self _bottomTextColor]];

    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(_hideEndTime) withObject:nil afterDelay:2];

    _endTimeVisible = YES;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [self _updateBottomFieldsAnimated:YES];
    } completionHandler:NULL];
}


#pragma mark - Accessors

- (void) setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    [self _updateAll];
}


- (void) setDrawsInsertionPointWorkaround:(BOOL)drawsInsertionPointWorkaround
{
    if (_drawsInsertionPointWorkaround != drawsInsertionPointWorkaround) {
        _drawsInsertionPointWorkaround = drawsInsertionPointWorkaround;
        [self _updateAll];
    }
}


- (void) setSelected:(BOOL)selected
{
    if (_selected != selected) {
        _selected = selected;
        [self _updateAll];
    }
}


- (Track *) track
{
    return (Track *)[self objectValue];
}


@end
