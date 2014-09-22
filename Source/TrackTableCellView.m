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

#define SLOW_ANIMATIONS 0

@interface TrackTableCellView () <ApplicationEventListener>
@end


@implementation TrackTableCellView {
    NSArray *_observedKeyPaths;
    id       _observedObject;

    CGFloat  _line1LeftFittedWidth;
    CGFloat  _line1RightFittedWidth;
    CGFloat  _line2LeftFittedWidth;
    CGFloat  _line2RightFittedWidth;
    CGFloat  _line3LeftFittedWidth;
    CGFloat  _line3RightFittedWidth;
    CGFloat  _endTimeFittedWidth;

    Button      *_errorButton;
    NSTextField *_endTimeField;
    BOOL         _endTimeVisible;
    
    NSTrackingArea *_trackingArea;
    BOOL            _mouseInside;
    BOOL            _endTimeRequested;
}


- (id) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self _setupTrackTableCellView];
    }
    
    return self;
}


- (id) initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self _setupTrackTableCellView];
    }
    
    return self;
}


- (void) application:(Application *)application flagsChanged:(NSEvent *)event
{
    [self _updateEndTimeVisibilityAnimated:NO];
}


- (void) dealloc
{
    [self _removeObservers];

    [_errorButton setTarget:nil];
    [_errorButton setAction:NULL];
}


- (void) viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];
    _mouseInside = NO;
}

- (void) _setupTrackTableCellView
{
    [(Application *)NSApp registerEventListener:self];

    _endTimeField = [[NSTextField alloc] initWithFrame:NSZeroRect];

    [_endTimeField setBezeled:NO];
    [_endTimeField setDrawsBackground:NO];
    [_endTimeField setSelectable:NO];
    [_endTimeField setEditable:NO];
    [_endTimeField setAlignment:NSRightTextAlignment];
    [_endTimeField setAlphaValue:0];

    _errorButton = [[Button alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];

    [_errorButton setImage:[NSImage imageNamed:@"track_error_template"]];
    [_errorButton setAutoresizingMask:NSViewMinXMargin];
    [_errorButton setTarget:self];
    [_errorButton setAction:@selector(_errorButtonClicked:)];
    [_errorButton setAlertColor:GetRGBColor(0xff0000, 1.0)];
    [_errorButton setAlertActiveColor:GetRGBColor(0xd00000, 1.0)];

    [_errorButton setAlert:YES];
    
    NSTrackingAreaOptions options = NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways;
    _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}


- (void) awakeFromNib
{
    [[[self lineTwoLeftField] superview] addSubview:_endTimeField];

    [_endTimeField setFont:[[self lineTwoLeftField] font]];

    [self _updateAllAnimated:NO];
}


- (void) mouseEntered:(NSEvent *)theEvent
{
    [super mouseEntered:theEvent];
    _mouseInside = YES;
    [self _updateEndTimeVisibilityAnimated:NO];
}


- (void) mouseExited:(NSEvent *)theEvent
{
    [super mouseExited:theEvent];
    _mouseInside = NO;
    [self _updateEndTimeVisibilityAnimated:NO];
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
            [self _updateAllAnimated:[keyPath isEqualToString:@"trackStatus"]];
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
        @"estimatedEndTime",
        @"pausesAfterPlaying",
        @"artist",
        @"tonality",
        @"comments",
        @"grouping",
        @"beatsPerMinute",
        @"trackStatus",
        @"trackError"
    ];
    
    _observedObject = objectValue;

    for (NSString *keyPath in _observedKeyPaths) {
        [_observedObject addObserver:self forKeyPath:keyPath options:0 context:NULL];
    }

    [self _updateAllAnimated:NO];
}


- (void) layout
{
    [super layout];
    [self _updateFieldsAnimated:NO];
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

    if ([[self window] isMainWindow] && _selected)  {
        return [NSColor whiteColor];
    }

    if (trackStatus == TrackStatusPlaying) {
        return GetRGBColor(_selected ? 0x0 : 0x1866e9, 1.0);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.4);
    }
    
    return [NSColor blackColor];
}


- (NSColor *) _bottomTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if ([[self window] isMainWindow] && _selected)  {
        return [NSColor colorWithCalibratedWhite:1.0 alpha:0.66];
    }

    if (trackStatus == TrackStatusPlaying) {
        return GetRGBColor(_selected ? 0x0 : 0x1866e9, 0.8);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.33);
    }
    
    return GetRGBColor(0x000000, 0.66);
}


- (void) _errorButtonClicked:(id)sender
{
    [GetAppDelegate() displayErrorForTrackError:[[self track] trackError]];
}


- (void) _unrequestEndTime
{
    _endTimeRequested = NO;
    [self _updateEndTimeVisibilityAnimated:YES];
}


- (void) _updateEndTimeVisibilityAnimated:(BOOL)animated
{
    NSUInteger modifierFlags = [NSEvent modifierFlags];
    
    modifierFlags &= (NSAlternateKeyMask | NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask);
    
    BOOL isCommandKeyDown = (modifierFlags == NSAlternateKeyMask);
    
    BOOL endTimeVisible = ((isCommandKeyDown && _mouseInside) || _endTimeRequested);

    if ([[self track] trackStatus] == TrackStatusPlayed) {
        endTimeVisible = NO;
    }

    if (_endTimeVisible != endTimeVisible) {
        _endTimeVisible = endTimeVisible;

        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
    #if SLOW_ANIMATIONS
            [context setDuration:1];
    #endif

            [self _updateFieldsAnimated:animated];
        } completionHandler:NULL];
    }
}


#pragma mark - Update

- (void) _updateAllAnimated:(BOOL)animated
{
    [self _updateBorderedView];
    [self _updateSpeakerImage];
    [self _updateFieldsAnimated:animated];
    [self _updateErrorButton];

    NSColor *topTextColor    = [self _topTextColor];
    NSColor *bottomTextColor = [self _bottomTextColor];

    [[self titleField]    setTextColor:topTextColor];
    [[self durationField] setTextColor:topTextColor];

    [[self lineTwoLeftField]    setTextColor:bottomTextColor];
    [[self lineTwoRightField]   setTextColor:bottomTextColor];
    [[self lineThreeLeftField]  setTextColor:bottomTextColor];
    [[self lineThreeRightField] setTextColor:bottomTextColor];

    [_endTimeField setFont:[[self lineTwoLeftField] font]];
    [_endTimeField setTextColor:bottomTextColor];
}


- (void) _updateSpeakerImage
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if ([[self window] isMainWindow] && _selected)  {
        [[self speakerImageView] setImage:[NSImage imageNamed:@"white_speaker"]];
        return;
    }

    if (trackStatus == TrackStatusPlaying) {
        if (_selected) {
            [[self speakerImageView] setImage:[NSImage imageNamed:@"black_speaker"]];
        } else {
            [[self speakerImageView] setImage:[NSImage imageNamed:@"blue_speaker"]];
        }

        return;
    }
    
    [[self speakerImageView] setImage:[NSImage imageNamed:@"black_speaker"]];
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
        if ([[self window] isMainWindow]) {
            [borderedView setBackgroundColor:GetActiveHighlightColor()];
        } else {
            [borderedView setBackgroundColor:GetInactiveHighlightColor()];
        }
    } else {
        [borderedView setBackgroundColor:nil];
    }

    if (_drawsInsertionPointWorkaround) {
        [borderedView setTopBorderColor:GetActiveHighlightColor()];
        [borderedView setTopBorderHeight:3];
    } else {
        [borderedView setTopBorderColor:nil];
        [borderedView setTopBorderHeight:0];
    }
}


- (void) _updateFieldStrings
{
    Preferences *preferences = [Preferences sharedInstance];

    Track *track = [self track];
    if (!track) return;

    NSInteger numberOfLines = [preferences numberOfLayoutLines];

    BOOL showsArtist         = [preferences showsArtist];
    BOOL showsBeatsPerMinute = [preferences showsBPM];
    BOOL showsComments       = [preferences showsComments];
    BOOL showsGrouping       = [preferences showsGrouping];
    BOOL showsKeySignature   = [preferences showsKeySignature];
    BOOL showsEnergyLevel    = [preferences showsEnergyLevel];
    BOOL showsGenre          = [preferences showsGenre];

    NSMutableArray *left2  = [NSMutableArray array];
    NSMutableArray *right2 = [NSMutableArray array];
    NSMutableArray *left3  = [NSMutableArray array];
    NSMutableArray *right3 = [NSMutableArray array];

    NSString *artist = [track artist];
    if (showsArtist && [artist length]) {
        [left2 addObject:artist];
    }

    if (showsComments) {
        NSString *comments = [track comments];

        if ([comments length]) {
            if (numberOfLines == 2) {
                [([left2 count] ? right2 : left2) addObject:comments];
            } else {
                [([left3 count] ? right3 : left3) addObject:comments];
            }
        }
    }

    if (showsGrouping) {
        NSString *grouping = [track grouping];

        if ([grouping length]) {
            if (numberOfLines == 2) {
                [([left2 count] ? right2 : left2) addObject:grouping];
            } else {
                [([left3 count] ? right3 : left3) addObject:grouping];
            }
        }
    }
    
    NSInteger bpm = [track beatsPerMinute];
    if (showsBeatsPerMinute && bpm) {
        [right2 addObject:[NSNumberFormatter localizedStringFromNumber:@(bpm) numberStyle:NSNumberFormatterDecimalStyle]];
    }

    NSInteger energyLevel = [track energyLevel];
    if (showsEnergyLevel && energyLevel) {
        [right2 addObject:[NSNumberFormatter localizedStringFromNumber:@(energyLevel) numberStyle:NSNumberFormatterDecimalStyle]];
    }

    NSMutableArray *arrayForTonality = right2;
    if (numberOfLines == 3 && (((int)showsComments + (int)showsGrouping) < 2)) {
        arrayForTonality = right3;
    }
    
    if (showsKeySignature) {
        KeySignatureDisplayMode displayMode = [preferences keySignatureDisplayMode];
        NSString *keySignatureString = nil;
        
        if (displayMode == KeySignatureDisplayModeRaw) {
            keySignatureString = [track initialKey];

        } else if (displayMode == KeySignatureDisplayModeTraditional) {
            keySignatureString = GetTraditionalStringForTonality([track tonality]);

        } else if (displayMode == KeySignatureDisplayModeOpenKeyNotation) {
            keySignatureString = GetOpenKeyNotationStringForTonality([track tonality]);
        }
        
        if ([keySignatureString length]) {
            [arrayForTonality addObject:keySignatureString];
        }
    }

    NSMutableArray *arrayForGenre = left2;
    NSString *genre = [track genre];
    if (showsGenre && [genre length]) {
        if (numberOfLines == 3) {
            arrayForGenre = [left3 count] ? right3 : left3;
        }
        
        [arrayForGenre addObject:genre];
    }

    NSString *joiner = NSLocalizedString(@" \\U2013 ", nil);
    
    NSString *left2String = [left2  componentsJoinedByString:joiner];
    [[self lineTwoLeftField] setStringValue:left2String];

    NSString *right2String = [right2 componentsJoinedByString:joiner];
    [[self lineTwoRightField] setStringValue:right2String];

    NSString *left3String = [left3 componentsJoinedByString:joiner];
    [[self lineThreeLeftField]  setStringValue:left3String];

    NSString *right3String = [right3 componentsJoinedByString:joiner];
    [[self lineThreeRightField] setStringValue:right3String];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterNoStyle];
    [formatter setTimeStyle:NSDateFormatterMediumStyle];
    
    NSDate   *endTime       = [[self track] estimatedEndTimeDate];
    NSString *endTimeString = [formatter stringFromDate:endTime];

    [_endTimeField setStringValue:endTimeString];

    CGFloat (^getFittedWidth)(NSTextField *) = ^(NSTextField *field) {
        NSRect frame = [field frame];
        [field sizeToFit];
        CGFloat result = [field frame].size.width;
        [field setFrame:frame];
        
        return result;
    };

    NSString *titleString = [track title];
    if (!titleString) titleString = @"";
    [[self titleField] setStringValue:titleString];
    
    NSString *durationString = GetStringForTime(round([track playDuration]));
    if (!durationString) durationString = @"";
    [[self durationField] setStringValue:durationString];

    if ([titleString length]) {
        _line1LeftFittedWidth = getFittedWidth([self titleField]);
    } else {
        _line1LeftFittedWidth = 0;
    }

    if ([durationString length]) {
        _line1RightFittedWidth = getFittedWidth([self durationField]);
    } else {
        _line1RightFittedWidth = 0;
    }
    
    if ([left2String length]) {
        _line2LeftFittedWidth = getFittedWidth([self lineTwoLeftField]);
    } else {
        _line2LeftFittedWidth = 0;
    }

    if ([right2String length]) {
        _line2RightFittedWidth = getFittedWidth([self lineTwoRightField]);
    } else {
        _line2RightFittedWidth = 0;
    }

    if ([left3String length]) {
        _line3LeftFittedWidth = getFittedWidth([self lineThreeLeftField]);
    } else {
        _line3LeftFittedWidth = 0;
    }

    if ([right3String length]) {
        _line3RightFittedWidth = getFittedWidth([self lineThreeRightField]);
    } else {
        _line3RightFittedWidth = 0;
    }
    
    if ([endTimeString length]) {
        _endTimeFittedWidth = getFittedWidth(_endTimeField);
    } else {
        _endTimeFittedWidth = 0;
    }
}


- (void) _updateFieldHidden
{
    NSInteger numberOfLines = [[Preferences sharedInstance] numberOfLayoutLines];

    NSTextField *line1Right = [self durationField];
    NSTextField *line2Left  = [self lineTwoLeftField];
    NSTextField *line2Right = [self lineTwoRightField];
    NSTextField *line3Left  = [self lineThreeLeftField];
    NSTextField *line3Right = [self lineThreeRightField];

    BOOL showError = [[self track] trackError] != TrackErrorNone;

    [line2Left  setHidden:(numberOfLines < 2)];
    [line3Left  setHidden:(numberOfLines < 3)];

    [line1Right setHidden:showError];
    [line2Right setHidden:showError || (numberOfLines < 2)];
    [line3Right setHidden:showError || (numberOfLines < 3)];
}


- (void) _updateFieldFramesAnimated:(BOOL)animated
{
    Track *track = [self track];
    if (!track) return;

    NSInteger numberOfLines = [[Preferences sharedInstance] numberOfLayoutLines];

    NSTextField *line1Left  = [self titleField];
    NSTextField *line1Right = [self durationField];
    NSTextField *line2Left  = [self lineTwoLeftField];
    NSTextField *line2Right = [self lineTwoRightField];
    NSTextField *line3Left  = [self lineThreeLeftField];
    NSTextField *line3Right = [self lineThreeRightField];

    NSImageView *speakerImageView = [self speakerImageView];

    NSRect superBounds = [[line2Left superview] bounds];

    CGFloat textLeftX = 6;

    BOOL isPlaying = [[self track] trackStatus] == TrackStatusPlaying;
    if (isPlaying) {
        textLeftX += 24;
    }

    NSRect speakerFrame = NSZeroRect;
    speakerFrame.size = [[speakerImageView image] size];
    speakerFrame.origin.y = round((superBounds.size.height - speakerFrame.size.height) / 2);
    speakerFrame.origin.x = isPlaying ? 8 : -speakerFrame.size.width;
    
    if (animated) {
        [[speakerImageView animator] setFrame:speakerFrame];
        [[speakerImageView animator] setAlphaValue:(isPlaying ? 1.0 : 0.0)];
    } else {
        [speakerImageView setFrame:speakerFrame];
        [speakerImageView setAlphaValue:(isPlaying ? 1.0 : 0.0)];
    }

    void (^layoutLine)(NSTextField *, NSTextField *, CGFloat, CGFloat, NSInteger) = ^(NSTextField *left, NSTextField *right, CGFloat leftFittedWidth, CGFloat rightFittedWidth, NSInteger lineNumber) {
        CGRect leftFrame  = [left  frame];
        CGRect rightFrame = [right frame];
        CGRect endFrame   = [_endTimeField frame];

        BOOL lastLine = (lineNumber == numberOfLines);

        CGFloat maxWidth = superBounds.size.width - (textLeftX + 6);

        leftFrame.origin.x  =
        rightFrame.origin.x =
        endFrame.origin.x   =
            textLeftX;

        leftFrame.size.width  =
        rightFrame.size.width =
        endFrame.size.width   =
            maxWidth;
        
        endFrame.size.width = _endTimeFittedWidth;
        endFrame.origin.x += maxWidth - _endTimeFittedWidth;
        endFrame.origin.y = rightFrame.origin.y;
        endFrame.size.height = rightFrame.size.height;

        if (lastLine && (numberOfLines == 1)) {
            endFrame.origin.y -= 3.0;
        }

        if (rightFittedWidth > maxWidth) {
            rightFittedWidth = maxWidth;
        }

        rightFrame.size.width = rightFittedWidth;
        rightFrame.origin.x += maxWidth - rightFittedWidth;

        leftFrame.size.width -= ((lastLine && _endTimeVisible) ? _endTimeFittedWidth : rightFittedWidth);
        if (leftFrame.size.width < 0) {
            leftFrame.size.width = 0;
        }

        if (animated) {
            [[left  animator] setFrame:leftFrame];
            [[right animator] setFrame:rightFrame];

            if (lastLine) [[_endTimeField animator] setFrame:endFrame];

        } else {
            [left  setFrame:leftFrame];
            [right setFrame:rightFrame];

            if (lastLine) [_endTimeField setFrame:endFrame];
        }
    };
    
    if (numberOfLines < 2) {
        layoutLine(line1Left, line1Right, _line1LeftFittedWidth, _line1RightFittedWidth, 1);
    
    } else if (numberOfLines == 2) {
        layoutLine(line1Left, line1Right, _line1LeftFittedWidth, _line1RightFittedWidth, 1);
        layoutLine(line2Left, line2Right, _line2LeftFittedWidth, _line2RightFittedWidth, 2);
    
    } else if (numberOfLines == 3) {
        layoutLine(line1Left, line1Right, _line1LeftFittedWidth, _line1RightFittedWidth, 1);
        layoutLine(line2Left, line2Right, _line2LeftFittedWidth, _line2RightFittedWidth, 2);
        layoutLine(line3Left, line3Right, _line3LeftFittedWidth, _line3RightFittedWidth, 3);
    }
}


- (void) _updateFieldAlphasAnimated:(BOOL)animated
{
    NSInteger numberOfLines = [[Preferences sharedInstance] numberOfLayoutLines];

    NSTextField *line1Right = [self durationField];
    NSTextField *line2Right = [self lineTwoRightField];
    NSTextField *line3Right = [self lineThreeRightField];

    CGFloat line1Alpha = 1.0;
    CGFloat line2Alpha = 2.0;
    CGFloat line3Alpha = 3.0;

    if (numberOfLines == 1) {
        line1Alpha = (_endTimeVisible ? 0.0 : 1.0);
    } else if (numberOfLines == 2) {
        line2Alpha = (_endTimeVisible ? 0.0 : 1.0);
    } else if (numberOfLines == 3) {
        line3Alpha = (_endTimeVisible ? 0.0 : 1.0);
    }
    
    if (animated) {
        [[line1Right animator] setAlphaValue:line1Alpha];
        [[line2Right animator] setAlphaValue:line2Alpha];
        [[line3Right animator] setAlphaValue:line3Alpha];

        [[_endTimeField animator] setAlphaValue:(_endTimeVisible ? 1.0 : 0)];

    } else {
        [line1Right setAlphaValue:line1Alpha];
        [line2Right setAlphaValue:line2Alpha];
        [line3Right setAlphaValue:line3Alpha];

        [_endTimeField setAlphaValue:(_endTimeVisible ? 1.0 : 0)];
    }
}


- (void) _updateFieldsAnimated:(BOOL)animated
{
    Track *track = [self track];
    if (!track) return;
    
    [self _updateFieldStrings];
    [self _updateFieldHidden];
    [self _updateFieldFramesAnimated:animated];
    [self _updateFieldAlphasAnimated:animated];
}


- (void) _updateErrorButton
{
    TrackError trackError = [[self track] trackError];
    
    if (trackError) {
        NSSize boundsSize = [self bounds].size;
        NSRect errorFrame = NSMakeRect(boundsSize.width - 34, round((boundsSize.height - 16) / 2), 16, 16);
        
        [_errorButton setFrame:errorFrame];
        [self addSubview:_errorButton];

    } else if (!trackError) {
        [_errorButton removeFromSuperview];
    }
}


#pragma mark - Public Methods

- (void) revealEndTime
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_unrequestEndTime) object:nil];
    [self performSelector:@selector(_unrequestEndTime) withObject:nil afterDelay:2];

    _endTimeRequested = YES;
    [self _updateEndTimeVisibilityAnimated:YES];
}


#pragma mark - Accessors

- (void) setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    [self _updateAllAnimated:NO];
}


- (void) setDrawsInsertionPointWorkaround:(BOOL)drawsInsertionPointWorkaround
{
    if (_drawsInsertionPointWorkaround != drawsInsertionPointWorkaround) {
        _drawsInsertionPointWorkaround = drawsInsertionPointWorkaround;
        [self _updateAllAnimated:NO];
    }
}


- (void) setSelected:(BOOL)selected
{
    if (_selected != selected) {
        _selected = selected;
        [self _updateAllAnimated:NO];
    }
}


- (Track *) track
{
    return (Track *)[self objectValue];
}


@end
