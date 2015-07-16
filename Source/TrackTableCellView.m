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
#import "NoDropImageView.h"
#import "Preferences.h"
#import "TrackTableView.h"
#import "StripeView.h"

#define SLOW_ANIMATIONS 0

@interface TrackTableCellView () <ApplicationEventListener>

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *borderedViewTopConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *titleDurationConstraint;

@property (nonatomic, weak) IBOutlet BorderedView *borderedView;
@property (nonatomic, weak) IBOutlet StripeView   *stripeView;

@property (nonatomic, weak) IBOutlet NSTextField *titleField;
@property (nonatomic, weak) IBOutlet NSTextField *durationField;

@property (nonatomic, weak) IBOutlet NSTextField *lineTwoLeftField;
@property (nonatomic, weak) IBOutlet NSTextField *lineTwoRightField;

@property (nonatomic, weak) IBOutlet NSTextField *lineThreeLeftField;
@property (nonatomic, weak) IBOutlet NSTextField *lineThreeRightField;

@property (nonatomic, weak) IBOutlet NSImageView *speakerImageView;
@property (nonatomic, weak) IBOutlet Button *errorButton;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *speakerTopConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *speakerLeftConstraint;

@end


@interface TrackTableView (Private)
- (void) _trackTableViewCell:(TrackTableCellView *)cellView mouseInside:(BOOL)mouseInside;
@end


@implementation TrackTableCellView {
    NSArray        *_observedKeyPaths;
    id              _observedObject;

    NSTextField    *_endTimeField;
    BOOL            _showsEndTime;
    
    NSArray        *_errorButtonConstraints;
    NSArray        *_endTimeConstraints;

    NoDropImageView *_duplicateImageView;
    NSArray         *_duplicateConstraints;

    NSTrackingArea *_trackingArea;
    BOOL            _mouseInside;
    BOOL            _endTimeRequested;
    BOOL            _animatesEndTime;
    BOOL            _animatesSpeakerImage;
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


- (TrackTableView *) _tableView
{
    NSView *view = [self superview];
    
    while (view) {
        if ([view isKindOfClass:[TrackTableView class]]) {
            return (TrackTableView *)view;
        }

        view = [view superview];
    }
    
    return nil;
}


- (void) _setupTrackTableCellView
{
    [(Application *)NSApp registerEventListener:self];

   
    NSTrackingAreaOptions options = NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways;
    _trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}


- (void) awakeFromNib
{
    [_endTimeField setFont:[[self lineTwoLeftField] font]];

    [_errorButton setImage:[NSImage imageNamed:@"TrackErrorTemplate"]];
    [_errorButton setIconOnly:YES];
    [_errorButton setAutoresizingMask:NSViewMinXMargin];
    [_errorButton setTarget:self];
    [_errorButton setAction:@selector(_errorButtonClicked:)];
    [_errorButton setAlertColor:GetRGBColor(0xff0000, 1.0)];
    [_errorButton setAlertActiveColor:GetRGBColor(0xd00000, 1.0)];
    [_errorButton setInactiveColor:[self _bottomTextColor]];
    [_errorButton setAlert:YES];

    _endTimeField = [[NSTextField alloc] initWithFrame:NSZeroRect];

    [_endTimeField setBezeled:NO];
    [_endTimeField setDrawsBackground:NO];
    [_endTimeField setSelectable:NO];
    [_endTimeField setEditable:NO];
    [_endTimeField setAlignment:NSRightTextAlignment];
    [_endTimeField setAlphaValue:0];
    [_endTimeField setContentHuggingPriority:(NSLayoutPriorityDefaultHigh + 1) forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_endTimeField setContentCompressionResistancePriority:(NSLayoutPriorityDefaultHigh + 1) forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_endTimeField setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_endTimeField setDrawsBackground:YES];

#if 0
    [_titleField setBackgroundColor:[NSColor yellowColor]];
    [_titleField setDrawsBackground:YES];
    [_lineThreeLeftField setBackgroundColor:[NSColor yellowColor]];
    [_lineThreeLeftField setDrawsBackground:YES];
    [_lineTwoLeftField setBackgroundColor:[NSColor yellowColor]];
    [_lineTwoLeftField setDrawsBackground:YES];
    [_lineThreeRightField setBackgroundColor:[NSColor yellowColor]];
    [_lineThreeRightField setDrawsBackground:YES];
    [_lineTwoRightField setBackgroundColor:[NSColor yellowColor]];
    [_lineTwoRightField setDrawsBackground:YES];
#endif

    _errorButtonConstraints = @[
        [NSLayoutConstraint constraintWithItem:_titleField         attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_errorButton attribute:NSLayoutAttributeLeading multiplier:1.0 constant:-8.0],
        [NSLayoutConstraint constraintWithItem:_lineTwoLeftField   attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_errorButton attribute:NSLayoutAttributeLeading multiplier:1.0 constant:-8.0],
        [NSLayoutConstraint constraintWithItem:_lineThreeLeftField attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_errorButton attribute:NSLayoutAttributeLeading multiplier:1.0 constant:-8.0]
    ];
    
    [NSLayoutConstraint activateConstraints:_errorButtonConstraints];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [context setDuration:0];
        [self _updateView];
    } completionHandler:^{
        _animatesSpeakerImage = YES;
    }];
}


- (void) _adjustConstraintsForLineLayout
{
    if (_endTimeConstraints) {
        [NSLayoutConstraint deactivateConstraints:_endTimeConstraints];
        _endTimeConstraints = nil;
    }
    
    NSInteger numberOfLines = [[Preferences sharedInstance] numberOfLayoutLines];

    NSTextField *targetField = nil;
    CGFloat speakerTopY = 0;

    if (numberOfLines == 1) {
        targetField = [self durationField];
        speakerTopY = 0;
    } else if (numberOfLines == 2) {
        targetField = [self lineTwoRightField];
        speakerTopY = 7;
    } else if (numberOfLines == 3) {
        targetField = [self lineThreeRightField];
        speakerTopY = 16;
    }
    
    [_speakerTopConstraint setConstant:speakerTopY];

    NSTextField *oldTargetField = [[_endTimeConstraints lastObject] secondItem];

    if (targetField && (targetField != oldTargetField)) {
        _endTimeConstraints = @[
            [NSLayoutConstraint constraintWithItem:_endTimeField attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:targetField attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:_endTimeField attribute:NSLayoutAttributeLeading  relatedBy:NSLayoutRelationEqual toItem:targetField attribute:NSLayoutAttributeLeading  multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:_endTimeField attribute:NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual toItem:targetField attribute:NSLayoutAttributeBaseline multiplier:1.0 constant:0.0]
        ];
        
        [[targetField superview] addSubview:_endTimeField positioned:NSWindowAbove relativeTo:targetField];
        [NSLayoutConstraint activateConstraints:_endTimeConstraints];
    }
}


- (void) mouseEntered:(NSEvent *)theEvent
{
    [super mouseEntered:theEvent];
    _mouseInside = YES;

    [self _updateEndTimeVisibilityAnimated:NO];
    [self _updateView];
    
    [[self _tableView] _trackTableViewCell:self mouseInside:YES];
}


- (void) mouseExited:(NSEvent *)theEvent
{
    [super mouseExited:theEvent];
    _mouseInside = NO;

    [self _updateEndTimeVisibilityAnimated:NO];
    [self _updateView];

    [[self _tableView] _trackTableViewCell:self mouseInside:NO];
}


- (void) mouseDown:(NSEvent *)theEvent
{
    NSUInteger mask = (NSControlKeyMask | NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask);
    
    if (([theEvent modifierFlags] & mask) == NSControlKeyMask) {
        if ([self _tryToPresentContextMenuWithEvent:theEvent]) {
            return;
        }
    }

    [super mouseDown:theEvent];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == _observedObject) {
    
        if ([keyPath isEqualToString:@"trackStatus"]) {
            
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ac) {
                [ac setAllowsImplicitAnimation:YES];
                [ac setDuration:0.35];
                [self _updateSpeakerIcon];
                
                [self layoutSubtreeIfNeeded];
            } completionHandler:nil];

            [self _updateView];

        } else if ([_observedKeyPaths containsObject:keyPath]) {
            [self _updateView];
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
        @"trackError",
        @"trackLabel",
        @"duplicate"
    ];
    
    _observedObject = objectValue;

    for (NSString *keyPath in _observedKeyPaths) {
        [_observedObject addObserver:self forKeyPath:keyPath options:0 context:NULL];
    }

    [self _updateView];
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
            menu = [superview menuForEvent:event];
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

    if ([[self window] isMainWindow] && _selected && !_drawsLighterSelectedBackground)  {
        return [NSColor whiteColor];
    }

    if ((trackStatus == TrackStatusPreparing) || (trackStatus == TrackStatusPlaying)) {
        return GetRGBColor(_selected ? 0x0 : 0x1866e9, 1.0);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.5);
    }
    
    return [NSColor blackColor];
}


- (NSColor *) _bottomTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if ([[self window] isMainWindow] && _selected && !_drawsLighterSelectedBackground)  {
        return [NSColor colorWithCalibratedWhite:1.0 alpha:0.66];
    }

    if ((trackStatus == TrackStatusPreparing) || (trackStatus == TrackStatusPlaying)) {
        return GetRGBColor(_selected ? 0x0 : 0x1866e9, 0.8);
    } else if (trackStatus == TrackStatusPlayed) {
        return GetRGBColor(0x000000, 0.4);
    }
    
    return GetRGBColor(0x000000, 0.66);
}


- (void) _errorButtonClicked:(id)sender
{
    [GetAppDelegate() displayErrorForTrack:[self track]];
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
    
    BOOL showsEndTime = ((isCommandKeyDown && _mouseInside) || _endTimeRequested);

    if ([[self track] trackStatus] == TrackStatusPlayed) {
        showsEndTime = NO;
    }

    if (_showsEndTime != showsEndTime) {
        _showsEndTime = showsEndTime;
        _animatesEndTime = animated;
        [self _updateView];
    }
}


#pragma mark - Update

- (void) _updateView
{
    Track *track = [self track];

    [self _updateStripeAndBorderedView];
    [self _updateSpeakerImage];

    if ([self track]) {
        [self _updateDuplicateIcon];
        [self _updateFieldStrings];
        [self _updateFieldHidden];
        [self _updateFieldColors];
        [self _updateFieldAlphas];
    }

    [self _updateSpeakerIcon];
    [self _adjustConstraintsForLineLayout];

    // Update constraints
    if ([track trackError] != TrackErrorNone) {
        [NSLayoutConstraint activateConstraints:_errorButtonConstraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:_errorButtonConstraints];
    }
}


- (void) _updateSpeakerIcon
{
    TrackStatus trackStatus = [[self track] trackStatus];
    BOOL        isPlaying   = (trackStatus == TrackStatusPlaying);
    
    [_speakerLeftConstraint setConstant:(  isPlaying ? 4.0 : -18.0)];
    [_speakerImageView      setAlphaValue:(isPlaying ? 1.0 :  0.0 )];
}


- (void) _updateDuplicateIcon
{
    BOOL showsDuplicateIcon = [[Preferences sharedInstance] showsDuplicateStatus] && [[self track] isDuplicate];
    
    if (showsDuplicateIcon && !_duplicateImageView) {
        NSImage *image = [NSImage imageNamed:@"DuplicateTemplate"];
        [image setTemplate:YES];
        
        _duplicateImageView = [[NoDropImageView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        [_duplicateImageView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_duplicateImageView setImage:image];
        [[_durationField superview] addSubview:_duplicateImageView];
        
        _duplicateConstraints = @[
            [NSLayoutConstraint constraintWithItem:_duplicateImageView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_durationField attribute:NSLayoutAttributeLeading multiplier:1.0 constant:-4.0],
            [NSLayoutConstraint constraintWithItem:_duplicateImageView attribute:NSLayoutAttributeTop      relatedBy:NSLayoutRelationEqual toItem:_durationField attribute:NSLayoutAttributeTop     multiplier:1.0 constant:4.0]
        ];

        [NSLayoutConstraint activateConstraints:_duplicateConstraints];

    } else if (!showsDuplicateIcon && _duplicateImageView) {
        [_duplicateImageView removeFromSuperview];
        _duplicateImageView = nil;
        
        [NSLayoutConstraint deactivateConstraints:_duplicateConstraints];
        _duplicateConstraints = nil;
    }

    [_titleDurationConstraint setConstant:showsDuplicateIcon ? 18 : 8];
}


- (void) _updateStripeAndBorderedView
{
    Track *track = [self track];
    if (!track) return;

    BorderedView *borderedView = [self borderedView];

    NSColor *bottomBorderColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.1];
    NSColor *bottomDashBackgroundColor = nil;

    CGFloat bottomBorderHeight = -1;
    CGFloat topConstraintValue = 0;

    if ([track pausesAfterPlaying] && ([track trackStatus] != TrackStatusPlayed)) {
        bottomBorderColor = [NSColor redColor];
        bottomDashBackgroundColor = GetRGBColor(0xffd0d0, 1.0);
        bottomBorderHeight = 2;
    }


    [borderedView setBottomBorderColor:bottomBorderColor];
    [borderedView setBottomBorderHeight:bottomBorderHeight];
    [borderedView setBottomDashBackgroundColor:bottomDashBackgroundColor];

    TrackLabel trackLabel = [track trackLabel];
    [[self stripeView] setFillColor:GetFillColorForTrackLabel(trackLabel)];
    [[self stripeView] setBorderColor:GetBorderColorForTrackLabel(trackLabel)];

    if (_selected) {
        if ([[self window] isMainWindow] && !_drawsLighterSelectedBackground) {
            [borderedView setBackgroundColor:GetActiveHighlightColor()];
        } else {
            [borderedView setBackgroundColor:GetInactiveHighlightColor()];
        }
        
        topConstraintValue = -2;

    } else {
       [borderedView setBackgroundColor:[NSColor whiteColor]];
    }
    
   
    [_endTimeField setBackgroundColor:[borderedView backgroundColor]];

    if (_drawsInsertionPointWorkaround) {
        [borderedView setTopBorderColor:GetActiveHighlightColor()];
        [borderedView setTopBorderHeight:2];
        topConstraintValue = 0;

    } else {
        [borderedView setTopBorderColor:nil];
        [borderedView setTopBorderHeight:0];
    }

    [_borderedViewTopConstraint setConstant:topConstraintValue];
}


- (void) _updateSpeakerImage
{
    BOOL isPlaying = ([[self track] trackStatus] == TrackStatusPlaying);

    if ([[self window] isMainWindow] && _selected)  {
        [[self speakerImageView] setImage:[NSImage imageNamed:@"SpeakerWhite"]];
        return;
    }

    if (isPlaying) {
        if (_selected) {
            [[self speakerImageView] setImage:[NSImage imageNamed:@"SpeakerBlack"]];
        } else {
            [[self speakerImageView] setImage:[NSImage imageNamed:@"SpeakerBlue"]];
        }

        return;
    }
    
    [[self speakerImageView] setImage:[NSImage imageNamed:@"SpeakerBlack"]];
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
    
    [[self lineTwoLeftField]    setStringValue:[left2  componentsJoinedByString:joiner]];
    [[self lineTwoRightField]   setStringValue:[right2 componentsJoinedByString:joiner]];
    [[self lineThreeLeftField]  setStringValue:[left3  componentsJoinedByString:joiner]];
    [[self lineThreeRightField] setStringValue:[right3 componentsJoinedByString:joiner]];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterNoStyle];
    [formatter setTimeStyle:NSDateFormatterMediumStyle];
    
    NSDate   *endTime       = [[self track] estimatedEndTimeDate];
    NSString *endTimeString = [formatter stringFromDate:endTime];

    [_endTimeField setStringValue:endTimeString];
    [_endTimeField setFont:[[self lineTwoLeftField] font]];
    [_endTimeField setTextColor:[self _bottomTextColor]];
    
    NSString *titleString = [track title];
    if (!titleString) titleString = @"";
    [[self titleField] setStringValue:titleString];
    
    NSString *durationString = GetStringForTime(round([track playDuration]));
    if (!durationString) durationString = @"";
    [[self durationField] setStringValue:durationString];
}


- (void) _updateFieldHidden
{
    NSInteger numberOfLines = [[Preferences sharedInstance] numberOfLayoutLines];

    NSTextField *line1Right  = [self durationField];
    NSTextField *line2Left   = [self lineTwoLeftField];
    NSTextField *line2Right  = [self lineTwoRightField];
    NSTextField *line3Left   = [self lineThreeLeftField];
    NSTextField *line3Right  = [self lineThreeRightField];
    Button      *errorButton = [self errorButton];

    BOOL showError = [[self track] trackError] != TrackErrorNone;

    [line1Right  setHidden:showError];
    [line2Left   setHidden:(numberOfLines < 2)];
    [line2Right  setHidden:showError || (numberOfLines < 2)];
    [line3Left   setHidden:(numberOfLines < 3)];
    [line3Right  setHidden:showError || (numberOfLines < 3)];
    [errorButton setHidden:!showError];
}


- (void) _updateFieldColors
{
    NSColor *topTextColor    = [self _topTextColor];
    NSColor *bottomTextColor = [self _bottomTextColor];

    [[self titleField]    setTextColor:topTextColor];
    [[self durationField] setTextColor:topTextColor];

    [[self lineTwoLeftField]    setTextColor:bottomTextColor];
    [[self lineTwoRightField]   setTextColor:bottomTextColor];
    [[self lineThreeLeftField]  setTextColor:bottomTextColor];
    [[self lineThreeRightField] setTextColor:bottomTextColor];
    
    [_duplicateImageView setTintColor:topTextColor];
}


- (void) _updateFieldAlphas
{
    BOOL shortensPlayedTracks = [[Preferences sharedInstance] shortensPlayedTracks];
    BOOL isPlayedTrack        = [[self track] trackStatus] == TrackStatusPlayed;
    
    if (shortensPlayedTracks && isPlayedTrack) {
        [[[self lineTwoLeftField]    animator] setAlphaValue:_expandedPlayedTrack ? 1.0 : 0.0];
        [[[self lineThreeLeftField]  animator] setAlphaValue:_expandedPlayedTrack ? 1.0 : 0.0];
        [[[self lineTwoRightField]   animator] setAlphaValue:_expandedPlayedTrack ? 1.0 : 0.0];
        [[[self lineThreeRightField] animator] setAlphaValue:_expandedPlayedTrack ? 1.0 : 0.0];
    } else {
        [[self lineTwoLeftField]    setAlphaValue:1.0];
        [[self lineThreeLeftField]  setAlphaValue:1.0];
        [[self lineTwoRightField]   setAlphaValue:1.0];
        [[self lineThreeRightField] setAlphaValue:1.0];
    }

    CGFloat endTimeAlpha = _showsEndTime ? 1.0 : 0.0;
    
    if (_animatesEndTime) {
        [[_endTimeField animator] setAlphaValue:endTimeAlpha];
    } else {
        [_endTimeField setAlphaValue:endTimeAlpha];
    }

    [_endTimeField setContentCompressionResistancePriority:(_showsEndTime ? (NSLayoutPriorityDefaultHigh + 1) : 1) forOrientation:NSLayoutConstraintOrientationHorizontal];
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
    [self _updateView];
}


- (void) setDrawsInsertionPointWorkaround:(BOOL)drawsInsertionPointWorkaround
{
    if (_drawsInsertionPointWorkaround != drawsInsertionPointWorkaround) {
        _drawsInsertionPointWorkaround = drawsInsertionPointWorkaround;
        [self _updateView];
    }
}


- (void) setDrawsLighterSelectedBackground:(BOOL)drawsLighterSelectedBackground
{
    if (_drawsLighterSelectedBackground != drawsLighterSelectedBackground) {
        _drawsLighterSelectedBackground = drawsLighterSelectedBackground;
        [self _updateView];
    }
}


- (void) setExpandedPlayedTrack:(BOOL)expandedPlayedTrack
{
    if (_expandedPlayedTrack != expandedPlayedTrack) {
        _expandedPlayedTrack = expandedPlayedTrack;
        [self _updateView];
    }
}


- (void) setSelected:(BOOL)selected
{
    if (_selected != selected) {
        _selected = selected;
        [self _updateView];
    }
}


- (Track *) track
{
    return (Track *)[self objectValue];
}


@end
