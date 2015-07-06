//
//  PlayBar.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-11.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "LabelMenuView.h"


static NSString *sTagKey = @"tag";
static NSInteger sTagCount = 7;

static CGFloat sOffsetX    = 11;
static CGFloat sOffsetY    = 7;
static NSInteger sMasterTag = 1000;

static CGFloat sHorizontalPadding = 8;
static CGFloat sDotWidth          = 14;
static CGFloat sDotHeight         = 14;


@implementation LabelMenuView {
    NSArray  *_trackingAreas;
    NSInteger _selectedTag;
    NSInteger _hoverTag;
    BOOL      _mouseInside;
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
}


- (void) drawRect:(NSRect)rect
{
    CGRect dotRect = CGRectMake(sOffsetX, sOffsetY, sDotWidth, sDotHeight);
  
    int dotInsideColors[7] = {
        0xffffff,
        0xff625c,
        0xffaa47,
        0xffd64b,
        0x83e163,
        0x4ebdfa,
        0xd68fe7
    };

    int dotOutsideColors[7] = {
        0x808080,
        0xff3830,
        0xf89000,
        0xfed647,
        0x3ec01d,
        0x20a9f1,
        0xc869da
    };
    
    
    NSInteger tagToCircle = _hoverTag;
    if (tagToCircle == NSNotFound) {
        tagToCircle = _selectedTag;
    }
    
    for (NSInteger i = 0; i < sTagCount; i++) {
        if (i == tagToCircle) {
            NSBezierPath *outsidePath = [NSBezierPath bezierPathWithOvalInRect:CGRectInset(dotRect, -4, -4)];
            NSBezierPath *insidePath  = [NSBezierPath bezierPathWithOvalInRect:CGRectInset(dotRect, -3, -3)];

            [GetRGBColor(0x808080, 0.2) set];
            [outsidePath fill];

            [GetRGBColor(0x808080, 1.0) set];
            [outsidePath appendBezierPath:[insidePath bezierPathByReversingPath]];
            [outsidePath fill];
        }

        [GetRGBColor(dotOutsideColors[i], 1.0) set];
        [[NSBezierPath bezierPathWithOvalInRect:dotRect] fill];

        [GetRGBColor(dotInsideColors[i], 1.0) set];
        [[NSBezierPath bezierPathWithOvalInRect:CGRectInset(dotRect, 1, 1)] fill];
        
        dotRect.origin.x += sHorizontalPadding + sDotWidth;
    }
}


- (void) mouseUp:(NSEvent*)event
{
    BOOL shouldSend = (_hoverTag != NSNotFound);

	_selectedTag = _hoverTag;
    _hoverTag = NSNotFound;

    [self setNeedsDisplay:YES];

    if (shouldSend) {
        [self sendAction:[self action] to:[self target]];
    }

	[[[self enclosingMenuItem] menu] cancelTracking];
}


- (void) mouseEntered:(NSEvent *)event
{
    NSInteger tag = [[(id)[event userData] objectForKey:sTagKey] integerValue];
    _hoverTag = tag;
    _mouseInside = YES;

	[self setNeedsDisplay:YES];
}


- (void) mouseExited:(NSEvent *)event
{
    NSInteger tag = [[(id)[event userData] objectForKey:sTagKey] integerValue];

    if (tag == sMasterTag) {
        _hoverTag = NSNotFound;
    }

    _mouseInside = NO;
	[self setNeedsDisplay:YES];
}


- (void) setSelectedTag:(NSInteger)selectedTag
{
    if (_selectedTag != selectedTag) {
        _hoverTag = NSNotFound;
        _selectedTag = selectedTag;
        [self setNeedsDisplay:YES];
    }
}


@end
