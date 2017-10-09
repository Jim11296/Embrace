//
//  TrialBottomView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-05-02.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrialBottomView.h"
#import "BorderedView.h"

#if TRIAL

@implementation TrialBottomView

- (id)initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        NSRect textFrame = [self bounds];
        
        BorderedView *borderedView = [[BorderedView alloc] initWithFrame:[self bounds]];
        
        [borderedView setTopBorderColor:GetRGBColor(0xB3CCFF, 1.0)];
        [borderedView setBackgroundColor:GetRGBColor(0xF2F7FF, 1.0)];
        [borderedView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

        [self addSubview:borderedView];
        
        NSTextField *textView = [[NSTextField alloc] initWithFrame:textFrame];
        [textView setEditable:NO];
        [textView setSelectable:NO];
        [textView setBordered:NO];
        [textView setBackgroundColor:[NSColor clearColor]];
        [textView setDrawsBackground:NO];
        [textView setAlignment:NSCenterTextAlignment];
        [textView setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin|NSViewMaxYMargin];

        NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
        [ps setAlignment:NSCenterTextAlignment];

        NSMutableAttributedString *as = [[NSMutableAttributedString alloc] init];
        
        NSAttributedString *as1 = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Purchase Embrace", nil) attributes:@{
            NSForegroundColorAttributeName: GetRGBColor(0x1866E9, 1.0),
            NSParagraphStyleAttributeName: ps
        }];
        [as appendAttributedString:as1];
        
        NSAttributedString *as2 = [[NSAttributedString alloc] initWithString:NSLocalizedString(@" to add\nmore than five songs.", nil) attributes:@{
            NSForegroundColorAttributeName: GetRGBColor(0x0, 0.5),
            NSParagraphStyleAttributeName: ps
        }];
        [as appendAttributedString:as2];
       
        NSTrackingAreaOptions options = NSTrackingInVisibleRect | NSTrackingCursorUpdate | NSTrackingActiveAlways;
        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];
        [self addTrackingArea:area];
        
        [textView setAttributedStringValue:as];

        [self addSubview:textView];

        [textView sizeToFit];
        NSRect textViewFrame = [textView frame];

        textViewFrame.origin.y = round((frame.size.height - textViewFrame.size.height) / 2);
        textViewFrame.size.width = frame.size.width;

        [textView setFrame:textViewFrame];
    }

    return self;
}

- (void) mouseDown:(NSEvent *)theEvent
{
    NSURL *url = [NSURL URLWithString:@"macappstore://itunes.apple.com/us/app/embrace/id817962217?mt=12"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}


- (void) cursorUpdate:(NSEvent *)event
{
    [[NSCursor pointingHandCursor] set];
}


@end

#endif
