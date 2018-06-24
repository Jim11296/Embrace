//
//  TrialBottomView.m
//  Embrace
//
//  Created by Ricci Adams on 2014-05-02.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TrialBottomView.h"
#import "HairlineView.h"

#if TRIAL

@implementation TrialBottomView

- (id) initWithFrame:(NSRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        NSRect textFrame = [self bounds];

        if (@available(macOS 10.14, *)) {
            NSVisualEffectView *backgroundView = [[NSVisualEffectView alloc] initWithFrame:[self bounds]];
            
            [backgroundView setMaterial:NSVisualEffectMaterialHeaderView];
            [backgroundView setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
            [backgroundView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

            [self addSubview:backgroundView];
        } else {
            NSBox *box = [[NSBox alloc] initWithFrame:[self bounds]];
            [box setFillColor:[NSColor colorWithWhite:0.95 alpha:1.0]];
            [box setBorderColor:[NSColor clearColor]];
            [box setBoxType:NSBoxCustom];
            
            [box setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

            [self addSubview:box];
        }
        
        CGRect hairlineFrame = [self bounds];
        hairlineFrame.origin.y = hairlineFrame.size.height - 1;
        hairlineFrame.size.height = 1;

        HairlineView *hairlineView = [[HairlineView alloc] initWithFrame:[self bounds]];
        [hairlineView setFrame:hairlineFrame];
        [hairlineView setAutoresizingMask:NSViewWidthSizable];
        [hairlineView setBorderColor:[Theme colorNamed:@"SetlistSeparator"]];
        [hairlineView setLayoutAttribute:NSLayoutAttributeTop];

        [self addSubview:hairlineView];
        
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
            NSForegroundColorAttributeName: [NSColor textColor],
            NSFontAttributeName: [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold],
            NSParagraphStyleAttributeName: ps
        }];
        [as appendAttributedString:as1];
        
        NSAttributedString *as2 = [[NSAttributedString alloc] initWithString:NSLocalizedString(@" to add\nmore than five songs.", nil) attributes:@{
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
            NSFontAttributeName: [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium],
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
