// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import "MenuLabelView.h"

static NSString *sTagKey = @"tag";
static NSInteger sTagCount = 7;

static CGFloat sOffsetX    = 11;
static CGFloat sOffsetY    = 7;
static NSInteger sMasterTag = 1000;

static CGFloat sHorizontalPadding = 8;
static CGFloat sDotWidth          = 14;
static CGFloat sDotHeight         = 14;


@interface MenuLabelViewPiece : NSView
@property (nonatomic) NSInteger dotIndex;
@property (nonatomic) NSColor *borderColor;
@property (nonatomic) NSColor *fillColor;
@end


@implementation MenuLabelView {
    MenuLabelViewPiece *_ringView;
    NSArray            *_dotViews;

    NSArray  *_trackingAreas;
    NSInteger _selectedTag;
    NSInteger _hoverTag;
    BOOL      _didEnterAndExit;
}


- (id) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self setWantsLayer:YES];

        __block CGRect dotFrame = CGRectMake(sOffsetX, sOffsetY, sDotWidth, sDotHeight);

        MenuLabelViewPiece *(^makeDot)(TrackLabel, NSColorName, NSColorName) = ^(TrackLabel trackLabel, NSColorName borderName, NSColorName fillName) {
            MenuLabelViewPiece *dotView = [[MenuLabelViewPiece alloc] initWithFrame:dotFrame];
            
            if (borderName) [dotView setBorderColor:[NSColor colorNamed:borderName]];
            if (fillName)   [dotView setFillColor:  [NSColor colorNamed:fillName  ]];
            [dotView setDotIndex:trackLabel];
            
            [self addSubview:dotView];

            dotFrame.origin.x += sHorizontalPadding + sDotWidth;

            return dotView;
        };
        
        _ringView = [[MenuLabelViewPiece alloc] initWithFrame:CGRectMake(0, 0, sDotWidth + 8, sDotHeight + 8)];
        [_ringView setBorderColor:[NSColor colorNamed:@"MenuLabelRingBorder"]];
        [_ringView setFillColor:  [NSColor colorNamed:@"MenuLabelRingFill"  ]];
        [_ringView setDotIndex:NSNotFound];
        [self addSubview:_ringView];
        
        _dotViews = @[
            makeDot( TrackLabelNone,   @"MenuLabelRingBorder",   nil                    ),
            makeDot( TrackLabelRed,    @"MenuLabelRedBorder",    @"MenuLabelRedFill"    ),
            makeDot( TrackLabelOrange, @"MenuLabelOrangeBorder", @"MenuLabelOrangeFill" ),
            makeDot( TrackLabelYellow, @"MenuLabelYellowBorder", @"MenuLabelYellowFill" ),
            makeDot( TrackLabelGreen,  @"MenuLabelGreenBorder",  @"MenuLabelGreenFill"  ),
            makeDot( TrackLabelBlue,   @"MenuLabelBlueBorder",   @"MenuLabelBlueFill"   ),
            makeDot( TrackLabelPurple, @"MenuLabelPurpleBorder", @"MenuLabelPurpleFill" )
        ];
    }

    return self;
}


- (BOOL) wantsUpdateLayer
{
    return YES;
}


- (void) updateLayer { }


- (void) layout
{
    [super layout];

    NSInteger selectedIndex = _hoverTag;
    if (selectedIndex == NSNotFound && (_didEnterAndExit == NO)) {
        selectedIndex = _selectedTag;
    }
    
    if (selectedIndex == NSNotFound) {
        [_ringView setHidden:YES];
    } else {
        MenuLabelViewPiece *dotView = [_dotViews objectAtIndex:selectedIndex];
        [_ringView setFrame:CGRectInset([dotView frame], -4, -4)];
        [_ringView setHidden:NO];
    }
}



- (void) viewDidMoveToWindow
{
    for (NSTrackingArea *area in _trackingAreas) {
        [self removeTrackingArea:area];
    }

    NSMutableArray *trackingAreas = [NSMutableArray array];
    
    CGRect dotRect = CGRectMake(sOffsetX, sOffsetY, sDotWidth, sDotHeight);
    
    CGRect masterRect = CGRectNull;
    
    for (NSInteger i = 0; i < sTagCount; i++) {
        CGRect rectToTrack = CGRectInset(dotRect, -4, -4);

		NSTrackingAreaOptions trackingOptions = NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingActiveAlways;
        NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:rectToTrack options:trackingOptions owner:self userInfo:@{ sTagKey: @(i) }];
                                            
        [trackingAreas addObject:trackingArea];
        [self addTrackingArea:trackingArea];

        dotRect.origin.x += sHorizontalPadding + sDotWidth;
        
        masterRect = CGRectUnion(masterRect, rectToTrack);
    }

    {
        NSTrackingAreaOptions trackingOptions = NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingActiveAlways;
        NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:masterRect options:trackingOptions owner:self userInfo:@{ sTagKey: @(sMasterTag) }];
                                            
        [trackingAreas addObject:trackingArea];
        [self addTrackingArea:trackingArea];
    }
    
    _didEnterAndExit = NO;
}


- (void) mouseUp:(NSEvent*)event
{
    BOOL shouldSend = (_hoverTag != NSNotFound);

	_selectedTag = _hoverTag;
    _hoverTag = NSNotFound;

    [self setNeedsLayout:YES];

    if (shouldSend) {
        [self sendAction:[self action] to:[self target]];
    }

	[[[self enclosingMenuItem] menu] cancelTracking];
}


- (void) mouseEntered:(NSEvent *)event
{
    NSInteger tag = [[(id)[event userData] objectForKey:sTagKey] integerValue];

    if (tag != sMasterTag) {
        _hoverTag = tag;
        [self setNeedsLayout:YES];
    }
}


- (void) mouseExited:(NSEvent *)event
{
    NSInteger tag = [[(id)[event userData] objectForKey:sTagKey] integerValue];

    if (tag == sMasterTag) {
        _hoverTag = NSNotFound;
        _didEnterAndExit = YES;
        [self setNeedsLayout:YES];
    }
}


- (void) setSelectedTag:(NSInteger)selectedTag
{
    _hoverTag = NSNotFound;
    _selectedTag = selectedTag;

    if (_selectedTag == 0) {
        _selectedTag = NSNotFound;
    }

    [self setNeedsLayout:YES];
}


@end


#pragma mark - Piece View

@implementation MenuLabelViewPiece

- (id) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self setWantsLayer:YES];
        [self setLayerContentsRedrawPolicy:NSViewLayerContentsRedrawOnSetNeedsDisplay];
    }

    return self;
}


- (void) drawRect:(NSRect)dirtyRect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    CGRect bounds = [self bounds];

    if (_dotIndex == 0) {
        CGRect rect = CGRectInset(bounds, 3, 3);
    
        [_borderColor set];
        
        CGContextMoveToPoint(   context, CGRectGetMinX(rect), CGRectGetMinY(rect));
        CGContextAddLineToPoint(context, CGRectGetMaxX(rect), CGRectGetMaxY(rect));

        CGContextMoveToPoint(   context, CGRectGetMinX(rect), CGRectGetMaxY(rect));
        CGContextAddLineToPoint(context, CGRectGetMaxX(rect), CGRectGetMinY(rect));
        
        CGContextStrokePath(context);
        return;
    }
    
    if ([_fillColor alphaComponent] == 1.0 && [_borderColor alphaComponent] == 1.0) {
        [_borderColor set];
        CGContextFillEllipseInRect(context, CGRectInset(bounds, 0.0, 0.0 ));

        [_fillColor set];
        CGContextFillEllipseInRect(context, CGRectInset(bounds, 1.0, 1.0 ));
    
    } else if (_fillColor) {
        [_fillColor set];
        CGContextFillEllipseInRect(context,   CGRectInset(bounds, 0.0, 0.0 ));

        [_borderColor set];
        CGContextSetLineWidth(context, 1);
        CGContextStrokeEllipseInRect(context, CGRectInset(bounds, 0.5, 0.5));

    } else {
        NSBezierPath *outerPath = [NSBezierPath bezierPathWithOvalInRect:bounds];
        NSBezierPath *innerPath = [NSBezierPath bezierPathWithOvalInRect:CGRectInset(bounds, 1, 1)];

        [outerPath appendBezierPath:[innerPath bezierPathByReversingPath]];

        [_borderColor set];
        [outerPath fill];
    }
}


@end

