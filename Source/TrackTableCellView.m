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
#import "DotView.h"
#import "MaskView.h"

#define SLOW_ANIMATIONS 0





static NSColor *sGetBorderColorForTrackLabel(TrackLabel trackLabel)
{
    NSColorName name = nil;

    if      (trackLabel == TrackLabelRed)    name = @"SetlistLabelRedBorder";
    else if (trackLabel == TrackLabelOrange) name = @"SetlistLabelOrangeBorder";
    else if (trackLabel == TrackLabelYellow) name = @"SetlistLabelYellowBorder";
    else if (trackLabel == TrackLabelGreen)  name = @"SetlistLabelGreenBorder";
    else if (trackLabel == TrackLabelBlue)   name = @"SetlistLabelBlueBorder";
    else if (trackLabel == TrackLabelPurple) name = @"SetlistLabelPurpleBorder";
    
    return name ? [NSColor colorNamed:name] : nil;
}


static NSColor *sGetFillColorForTrackLabel(TrackLabel trackLabel)
{
    NSColorName name = nil;

    if      (trackLabel == TrackLabelRed)    name = @"SetlistLabelRedFill";
    else if (trackLabel == TrackLabelOrange) name = @"SetlistLabelOrangeFill";
    else if (trackLabel == TrackLabelYellow) name = @"SetlistLabelYellowFill";
    else if (trackLabel == TrackLabelGreen)  name = @"SetlistLabelGreenFill";
    else if (trackLabel == TrackLabelBlue)   name = @"SetlistLabelBlueFill";
    else if (trackLabel == TrackLabelPurple) name = @"SetlistLabelPurpleFill";
    
    return name ? [NSColor colorNamed:name] : nil;
}


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

    NSTextField    *_timeField;
    MaskView       *_timeMaskView;
    BOOL            _showsTime;
    
    NSArray        *_errorButtonConstraints;
    NSArray        *_endTimeConstraints;

    NoDropImageView    *_duplicateImageView;
    NSArray            *_duplicateConstraints;
    NSLayoutConstraint *_duplicateRightConstraint;
    
    DotView            *_dotView;
    NSArray            *_dotConstraints;
    NSLayoutConstraint *_dotRightConstraint;

    NSTrackingArea *_trackingArea;
    BOOL            _mouseInside;
    BOOL            _timeRequested;
    BOOL            _animatesTime;
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
    [self _updateTimeVisibilityAnimated:NO];
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
    [_errorButton setImage:[NSImage imageNamed:@"TrackErrorTemplate"]];
    [_errorButton setIconOnly:YES];
    [_errorButton setAutoresizingMask:NSViewMinXMargin];
    [_errorButton setTarget:self];
    [_errorButton setAction:@selector(_errorButtonClicked:)];
    [_errorButton setAlertColor:[Theme colorNamed:@"ButtonAlert"]];
    [_errorButton setAlertActiveColor:[Theme colorNamed:@"ButtonAlertActive"]];
    [_errorButton setInactiveColor:[self _bottomTextColor]];
    [_errorButton setAlert:YES];

    _timeField = [[NSTextField alloc] initWithFrame:NSZeroRect];

    [_timeField setBezeled:NO];
    [_timeField setSelectable:NO];
    [_timeField setEditable:NO];
    [_timeField setDrawsBackground:NO];
    [_timeField setAlignment:NSTextAlignmentRight];
    [_timeField setAlphaValue:0];
    [_timeField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_timeField setContentCompressionResistancePriority:(NSLayoutPriorityDefaultHigh + 1) forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_timeField setTranslatesAutoresizingMaskIntoConstraints:NO];

    _timeMaskView = [[MaskView alloc] initWithFrame:NSZeroRect];
    [_timeMaskView setTranslatesAutoresizingMaskIntoConstraints:NO];

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
        [NSLayoutConstraint constraintWithItem:_titleField         attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_errorButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-8.0],
        [NSLayoutConstraint constraintWithItem:_lineTwoLeftField   attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_errorButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-8.0],
        [NSLayoutConstraint constraintWithItem:_lineThreeLeftField attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_errorButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-8.0]
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
        CGFloat length = [_timeMaskView gradientLength] + 8;
        
        _endTimeConstraints = @[
            [NSLayoutConstraint constraintWithItem:_timeField attribute:NSLayoutAttributeRight    relatedBy:NSLayoutRelationEqual              toItem:targetField attribute:NSLayoutAttributeRight    multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:_timeField attribute:NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual              toItem:targetField attribute:NSLayoutAttributeBaseline multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:_timeField attribute:NSLayoutAttributeWidth    relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:targetField attribute:NSLayoutAttributeWidth    multiplier:1.0 constant:0.0],

            [NSLayoutConstraint constraintWithItem:_timeMaskView attribute:NSLayoutAttributeTop      relatedBy:NSLayoutRelationEqual toItem:_timeField attribute:NSLayoutAttributeTop       multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:_timeMaskView attribute:NSLayoutAttributeBottom   relatedBy:NSLayoutRelationEqual toItem:_timeField attribute:NSLayoutAttributeBottom    multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:_timeMaskView attribute:NSLayoutAttributeRight    relatedBy:NSLayoutRelationEqual toItem:_timeField attribute:NSLayoutAttributeRight     multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:_timeMaskView attribute:NSLayoutAttributeLeft     relatedBy:NSLayoutRelationEqual toItem:_timeField attribute:NSLayoutAttributeLeft      multiplier:1.0 constant:-length]
        ];
        
        [[targetField superview] addSubview:_timeField    positioned:NSWindowAbove relativeTo:targetField];
        [[targetField superview] addSubview:_timeMaskView positioned:NSWindowAbove relativeTo:targetField];

        [NSLayoutConstraint activateConstraints:_endTimeConstraints];
    }
}


- (void) mouseEntered:(NSEvent *)theEvent
{
    [super mouseEntered:theEvent];
    _mouseInside = YES;

    [self _updateTimeVisibilityAnimated:NO];
    [self _updateView];
    
    [[self _tableView] _trackTableViewCell:self mouseInside:YES];
}


- (void) mouseExited:(NSEvent *)theEvent
{
    [super mouseExited:theEvent];
    _mouseInside = NO;

    [self _updateTimeVisibilityAnimated:NO];
    [self _updateView];

    [[self _tableView] _trackTableViewCell:self mouseInside:NO];
}


- (void) mouseDown:(NSEvent *)theEvent
{
    NSUInteger mask = (NSEventModifierFlagControl | NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagOption);
    
    if (([theEvent modifierFlags] & mask) == NSEventModifierFlagControl) {
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
            [self _updateSpeakerImage];
            [self _updateFieldColors];
            
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ac) {
                [ac setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
                [ac setDuration:0.25];
                [self _updateSpeakerIconAnimated:YES];
            } completionHandler:nil];

        } else if ([keyPath isEqualToString:@"estimatedEndTime"]) {
            [self _updateFieldStrings];

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
        @"ignoresAutoGap",
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
        return [Theme colorNamed:@"SetlistTopTextSelectedMain"];
    }

    if ((trackStatus == TrackStatusPreparing) || (trackStatus == TrackStatusPlaying)) {
        if (_selected) {
            return [Theme colorNamed:@"SetlistTopTextPlayingSelected"];
        } else {
            return [Theme colorNamed:@"SetlistTopTextPlaying"];
        }

    } else if (trackStatus == TrackStatusPlayed) {
        return [Theme colorNamed:@"SetlistTopTextPlayed"];
    }
    
    return [Theme colorNamed:@"SetlistTopText"];
}


- (NSColor *) _bottomTextColor
{
    TrackStatus trackStatus = [[self track] trackStatus];

    if ([[self window] isMainWindow] && _selected && !_drawsLighterSelectedBackground)  {
        return [Theme colorNamed:@"SetlistBottomTextSelectedMain"];
    }

    if ((trackStatus == TrackStatusPreparing) || (trackStatus == TrackStatusPlaying)) {
        if (_selected) {
            return [Theme colorNamed:@"SetlistBottomTextPlayingSelected"];
        } else {
            return [Theme colorNamed:@"SetlistBottomTextPlaying"];
        }

    } else if (trackStatus == TrackStatusPlayed) {
        return [Theme colorNamed:@"SetlistBottomTextPlayed"];
    }
    
    return [Theme colorNamed:@"SetlistBottomText"];
}


- (void) _errorButtonClicked:(id)sender
{
    [GetAppDelegate() displayErrorForTrack:[self track]];
}


- (void) _unrequestTime
{
    _timeRequested = NO;
    [self _updateTimeVisibilityAnimated:YES];
}


- (void) _updateTimeVisibilityAnimated:(BOOL)animated
{
    NSUInteger modifierFlags = [NSEvent modifierFlags];
    
    modifierFlags &= (
        NSEventModifierFlagOption  |
        NSEventModifierFlagCommand |
        NSEventModifierFlagControl |
        NSEventModifierFlagShift
    );
    
    BOOL isCommandKeyDown = (modifierFlags == NSEventModifierFlagOption);
    
    BOOL showsTime = ((isCommandKeyDown && _mouseInside) || _timeRequested);

    if (_showsTime != showsTime) {
        _showsTime = showsTime;
        _animatesTime = animated;
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
        [self _updateRightIcons];
        [self _updateFieldStrings];
        [self _updateFieldHidden];
        [self _updateFieldColors];
        [self _updateFieldAlphas];
    }

    [self _updateErrorButton];
    [self _updateSpeakerIconAnimated:NO];
    [self _adjustConstraintsForLineLayout];

    // Update constraints
    if ([track trackError] != TrackErrorNone) {
        [NSLayoutConstraint activateConstraints:_errorButtonConstraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:_errorButtonConstraints];
    }
}


- (void) _updateErrorButton
{
    if ([self isSelected]) {
        NSColor *textColor = [self _topTextColor];

        [_errorButton setAlertColor:textColor];
        [_errorButton setAlertActiveColor:textColor];

    } else {
        [_errorButton setAlertColor:[Theme colorNamed:@"ButtonAlert"]];
        [_errorButton setAlertActiveColor:[Theme colorNamed:@"ButtonAlertActive"]];
    }
}


- (void) _updateSpeakerIconAnimated:(BOOL)animated
{
    TrackStatus trackStatus = [[self track] trackStatus];
    BOOL        isPlaying   = (trackStatus == TrackStatusPlaying);
    
    if (![[Preferences sharedInstance] showsPlayingStatus]) {
        isPlaying = NO;
    }
    
    if (animated) {
        [[_speakerLeftConstraint animator] setConstant:(  isPlaying ? 4.0 : -18.0)];
        [[_speakerImageView      animator] setAlphaValue:(isPlaying ? 1.0 :  0.0 )];
    } else {
        [_speakerLeftConstraint setConstant:(  isPlaying ? 4.0 : -18.0)];
        [_speakerImageView      setAlphaValue:(isPlaying ? 1.0 :  0.0 )];
    }
}


- (void) _updateRightIcons
{
    TrackLabel trackLabel = [[self track] trackLabel];

    BOOL showsDuplicateIcon = [[Preferences sharedInstance] showsDuplicateStatus] && [[self track] isDuplicate];
    BOOL showsDot           = [[Preferences sharedInstance] showsLabelDots] && (trackLabel != TrackLabelNone);

    if (showsDuplicateIcon && !_duplicateImageView) {
        NSImage *image = [NSImage imageNamed:@"DuplicateTemplate"];
        [image setTemplate:YES];
        
        _duplicateImageView = [[NoDropImageView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        [_duplicateImageView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_duplicateImageView setImage:image];
        [[_durationField superview] addSubview:_duplicateImageView positioned:NSWindowBelow relativeTo:nil];

        _duplicateRightConstraint = [NSLayoutConstraint constraintWithItem:_duplicateImageView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_durationField attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-4.0];
        
        _duplicateConstraints = @[
            _duplicateRightConstraint,
            [NSLayoutConstraint constraintWithItem:_duplicateImageView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_durationField attribute:NSLayoutAttributeTop     multiplier:1.0 constant:4.0]
        ];

        [NSLayoutConstraint activateConstraints:_duplicateConstraints];

    } else if (!showsDuplicateIcon && _duplicateImageView) {
        [_duplicateImageView removeFromSuperview];
        _duplicateImageView = nil;
        
        [NSLayoutConstraint deactivateConstraints:_duplicateConstraints];
        _duplicateConstraints = nil;
        _duplicateRightConstraint = nil;
    }


    if (showsDot && !_dotView) {
        _dotView = [[DotView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
        [_dotView setTranslatesAutoresizingMaskIntoConstraints:NO];

        [[_durationField superview] addSubview:_dotView positioned:NSWindowBelow relativeTo:nil];

        _dotRightConstraint = [NSLayoutConstraint constraintWithItem:_dotView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_durationField attribute:NSLayoutAttributeLeft multiplier:1.0 constant:-4.0];

        _dotConstraints = @[
            _dotRightConstraint,
            [NSLayoutConstraint constraintWithItem:_dotView attribute:NSLayoutAttributeTop      relatedBy:NSLayoutRelationEqual toItem:_durationField attribute:NSLayoutAttributeTop     multiplier:1.0 constant:4.0],
            [NSLayoutConstraint constraintWithItem:_dotView attribute:NSLayoutAttributeWidth    relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute     multiplier:1.0 constant:10.0],
            [NSLayoutConstraint constraintWithItem:_dotView attribute:NSLayoutAttributeHeight   relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute     multiplier:1.0 constant:10.0]
        ];

        [NSLayoutConstraint activateConstraints:_dotConstraints];

        
    } else if (!showsDot && _dotView) {
        [_dotView removeFromSuperview];
        _dotView = nil;
        
        [NSLayoutConstraint deactivateConstraints:_dotConstraints];
        _dotConstraints = nil;
        _dotRightConstraint = nil;
    }


    NSInteger constant = 8;
    
    if (showsDuplicateIcon && showsDot) {
        constant = 28 + 4;
        [_duplicateRightConstraint setConstant:-18];
        [_dotRightConstraint setConstant:-4];

    } else if (showsDuplicateIcon) {
        constant = 18;
        [_duplicateRightConstraint setConstant:-4];

    } else if (showsDot) {
        constant = 8;
        [_dotRightConstraint setConstant:-4];
    }

    if (showsDot) {
        NSColor *borderColor = [self isSelected] ?
            [NSColor whiteColor] :
            sGetBorderColorForTrackLabel(trackLabel);
        
        [_dotView setFillColor:sGetFillColorForTrackLabel(trackLabel)];
        [_dotView setBorderColor:borderColor];
    }

    [_titleDurationConstraint setConstant:constant];
}


- (void) _updateStripeAndBorderedView
{
    Track *track = [self track];
    if (!track) return;

    BorderedView *borderedView = [self borderedView];

    NSColor *bottomBorderColor = [Theme colorNamed:@"SetlistSeparator"];
    NSColor *bottomDashBackgroundColor = nil;

    CGFloat bottomBorderHeight = -1;
    CGFloat topConstraintValue = 0;

    if ([track trackStatus] != TrackStatusPlayed) {
        if ([track stopsAfterPlaying]) {
            bottomDashBackgroundColor = [Theme colorNamed:@"SetlistStopAfterPlayingStripe1"];
            bottomBorderColor         = [Theme colorNamed:@"SetlistStopAfterPlayingStripe2"];
            bottomBorderHeight = 2;

        } else if ([track ignoresAutoGap]) {
            bottomBorderColor = [Theme colorNamed:@"SetlistIgnoreAutoGapStripe"];
            bottomBorderHeight = 2;
        }
    }

    [borderedView setBottomBorderColor:bottomBorderColor];
    [borderedView setBottomBorderHeight:bottomBorderHeight];
    [borderedView setBottomDashBackgroundColor:bottomDashBackgroundColor];

    TrackLabel trackLabel = [track trackLabel];
    [[self stripeView] setFillColor:sGetFillColorForTrackLabel(trackLabel)];
    [[self stripeView] setBorderColor:sGetBorderColorForTrackLabel(trackLabel)];
    [[self stripeView] setHidden:![[Preferences sharedInstance] showsLabelStripes]];

    NSColor *backgroundColor = nil;

    if (_selected) {
        if ([[self window] isMainWindow] && !_drawsLighterSelectedBackground) {
            backgroundColor = [Theme colorNamed:@"SetlistActiveHighlight"];
        } else {
            backgroundColor = [Theme colorNamed:@"SetlistInactiveHighlight"];
        }
        
        topConstraintValue = -2;

    } else {
       backgroundColor = [NSColor whiteColor];
    }
    
    [_borderedView setBackgroundColor:backgroundColor];
//    [_timeMaskView setColor:backgroundColor];

    [_timeMaskView setMaterial:NSVisualEffectMaterialUltraDark];
    
    [_timeMaskView setGradientLength:32];
    [_timeMaskView setGradientLayoutAttribute:NSLayoutAttributeLeft];

    if (_drawsInsertionPointWorkaround) {
        [borderedView setTopBorderColor:[Theme colorNamed:@"SetlistActiveHighlight"]];
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

    if ([[self window] isMainWindow] && _selected && !_drawsLighterSelectedBackground)  {
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

    NSMutableArray *a_2L = [NSMutableArray array];
    NSMutableArray *a_2R = [NSMutableArray array];
    NSMutableArray *a_3L = [NSMutableArray array];
    NSMutableArray *a_3R = [NSMutableArray array];

    NSMutableArray *(^sparsest)(NSArray<NSMutableArray *> *) = ^(NSArray<NSMutableArray *> *arrays) {
        NSMutableArray *result = nil;
        NSInteger minCount = NSIntegerMax;
        
        for (NSMutableArray *array in arrays) {
            NSInteger arrayCount = [array count];

            if (arrayCount < minCount) {
                result = array;
                minCount = arrayCount;
            }
        }

        return result;
    };

    NSString *(^collectAttributes)(NSArray *) = ^(NSArray *attributes) {
        NSMutableArray *strings = [NSMutableArray array];

        for (NSNumber *attributeNumber in attributes) {
            TrackViewAttribute attribute = [attributeNumber integerValue];
            NSString *string = nil;

            if (attribute == TrackViewAttributeAlbumArtist) {
                string = [track albumArtist];

            } else if (attribute == TrackViewAttributeArtist) {
                string = [track artist];

            } else if (attribute == TrackViewAttributeBeatsPerMinute) {
                NSInteger bpm = [track beatsPerMinute];
                if (bpm) string = [NSNumberFormatter localizedStringFromNumber:@(bpm) numberStyle:NSNumberFormatterDecimalStyle];

            } else if (attribute == TrackViewAttributeComments) {
                string = [track comments];

            } else if (attribute == TrackViewAttributeEnergyLevel) {
                NSInteger energyLevel = [track energyLevel];
                if (energyLevel) string = [NSNumberFormatter localizedStringFromNumber:@(energyLevel) numberStyle:NSNumberFormatterDecimalStyle];
        
            } else if (attribute == TrackViewAttributeGenre) {
                string = [track genre];

            } else if (attribute == TrackViewAttributeGrouping) {
                string = [track grouping];

            } else if (attribute == TrackViewAttributeKeySignature) {
                KeySignatureDisplayMode displayMode = [preferences keySignatureDisplayMode];
        
                if (displayMode == KeySignatureDisplayModeRaw) {
                    string = [track initialKey];

                } else if (displayMode == KeySignatureDisplayModeTraditional) {
                    string = GetTraditionalStringForTonality([track tonality]);

                } else if (displayMode == KeySignatureDisplayModeOpenKeyNotation) {
                    string = GetOpenKeyNotationStringForTonality([track tonality]);
                }

            } else if (attribute == TrackViewAttributeYear) {
                NSInteger year = [track year];
                if (year) string = [NSString stringWithFormat:@"%ld", (long)year];
            }
            
            if (string) [strings addObject:string];
        }

        NSString *joiner = NSLocalizedString(@" \\U2013 ", nil);
        return [strings componentsJoinedByString:joiner];
    };

    if ([preferences showsArtist]) {
        [a_2L addObject:@(TrackViewAttributeArtist)];
    }

    if ([preferences showsAlbumArtist]) {
        [a_2L addObject:@(TrackViewAttributeAlbumArtist)];
    }

    if ([preferences showsYear]) {
        [a_2L addObject:@(TrackViewAttributeYear)];
    }

    if ([preferences showsBPM]) {
        [a_2R addObject:@(TrackViewAttributeBeatsPerMinute)];
    }
    
    if ([preferences showsEnergyLevel]) {
        [a_2R addObject:@(TrackViewAttributeEnergyLevel)];
    }

    if ([preferences showsKeySignature]) {
        [a_2R addObject:@(TrackViewAttributeKeySignature)];
    }

    if ([preferences showsComments]) {
        [(numberOfLines == 3 ? a_3L : a_2R) addObject:@(TrackViewAttributeComments)];
    }

    if ([preferences showsGrouping]) {
        NSMutableArray *array;

        if (numberOfLines == 2) {
            array = sparsest(@[ a_2R, a_2L ]);
        } else {
            array = sparsest(@[ a_3R, a_3L, a_2R, a_2L ]);
        }

        [array addObject:@(TrackViewAttributeGrouping)];
    }

    if ([preferences showsGenre]) {
        NSMutableArray *array;

        if (numberOfLines == 2) {
            array = sparsest(@[ a_2R, a_2L ]);
        } else {
            array = sparsest(@[ a_3L, a_3R, a_2R, a_2L ]);
        }

        [array addObject:@(TrackViewAttributeGenre)];
    }

  
    [[self lineTwoLeftField]    setStringValue:collectAttributes(a_2L)];
    [[self lineTwoRightField]   setStringValue:collectAttributes(a_2R)];
    [[self lineThreeLeftField]  setStringValue:collectAttributes(a_3L)];
    [[self lineThreeRightField] setStringValue:collectAttributes(a_3R)];

    NSString *timeString = @"";
    NSString *timeStringFormat;
    NSDate   *date;
    
    if ([track trackStatus] == TrackStatusPlayed) {
        date = [track playedTimeDate];
        timeStringFormat = NSLocalizedString(@"Played at %@", nil);
    } else {
        date = [track estimatedEndTimeDate];
        timeStringFormat = NSLocalizedString(@"Ends at %@", nil);
    }

    if (date) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterNoStyle];
        [formatter setTimeStyle:NSDateFormatterMediumStyle];

        timeString = [NSString stringWithFormat:timeStringFormat, [formatter stringFromDate:date]];
    }

    if ([[NSFont class] respondsToSelector:@selector(monospacedDigitSystemFontOfSize:weight:)]) {
        NSFont *font = [[self lineTwoLeftField] font];
        font = [NSFont monospacedDigitSystemFontOfSize:[font pointSize] weight:NSFontWeightRegular];
        [_timeField setFont:font];
    } else {
        [_timeField setFont:[[self lineTwoLeftField] font]];
    }
        
    [_timeField setStringValue:timeString];
    [_timeField setTextColor:[self _bottomTextColor]];
    
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

    CGFloat endTimeAlpha = _showsTime ? 1.0 : 0.0;
    
    if (_animatesTime) {
        [[_timeField    animator] setAlphaValue:endTimeAlpha];
        [[_timeMaskView animator] setAlphaValue:endTimeAlpha];

    } else {
        [_timeField    setAlphaValue:endTimeAlpha];
        [_timeMaskView setAlphaValue:endTimeAlpha];
    }

    [_timeField setContentCompressionResistancePriority:(_showsTime ? (NSLayoutPriorityDefaultHigh + 1) : 1) forOrientation:NSLayoutConstraintOrientationHorizontal];
}



#pragma mark - Public Methods

- (void) revealTime
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_unrequestTime) object:nil];
    [self performSelector:@selector(_unrequestTime) withObject:nil afterDelay:2];

    _timeRequested = YES;
    [self _updateTimeVisibilityAnimated:YES];

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
