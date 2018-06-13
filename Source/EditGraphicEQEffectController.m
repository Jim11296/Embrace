//
//  EffectSettingsController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-06.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "EditGraphicEQEffectController.h"
#import "Effect.h"
#import "EffectAdditions.h"
#import "EffectType.h"
#import "BorderedView.h"
#import "GraphicEQView.h"

#import <AudioUnit/AUCocoaUIView.h>

@interface EditGraphicEQEffectController ()

@property (nonatomic, weak) IBOutlet NSToolbar *toolbar;
@property (nonatomic, weak) IBOutlet BorderedView *backgroundView;

@property (nonatomic, weak) IBOutlet GraphicEQView *graphicEQView;

@end


@implementation EditGraphicEQEffectController

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (NSString *) windowNibName
{
    return @"EditGraphicEQEffectWindow";
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    [_graphicEQView setAudioUnit:[[self effect] audioUnit]];

    CGSize contentSize = CGSizeMake(
        [_graphicEQView numberOfBands] == 10 ? 397 : 772,
        215
    );

    NSWindow *window = [self window];
    [window setTitlebarAppearsTransparent:YES];
    [window setTitleVisibility:NSWindowTitleHidden];
    [window setStyleMask:[window styleMask] | NSWindowStyleMaskFullSizeContentView];
    [window setContentMinSize:contentSize];
    [window setContentMaxSize:contentSize];

    CGRect rect = [window contentRectForFrameRect:[[self window] frame]];
    rect.size = contentSize;
    rect = [window frameRectForContentRect:rect];

    [window setFrame:rect display:YES animate:NO];

    [[self toolbar] setShowsBaselineSeparator:NO];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleWindowMainChanged:) name:NSWindowDidBecomeMainNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleWindowMainChanged:) name:NSWindowDidResignMainNotification object:nil];

    [self _handleWindowMainChanged:nil];
}


- (void) reloadData
{
    [_graphicEQView reloadData];
}


#pragma mark - Private Methods

- (void) _handleWindowMainChanged:(NSNotification *)note
{
    if ([[self window] isMainWindow]) {
        [_backgroundView setBackgroundGradientTopColor:   GetRGBColor(0xf0f0f0, 1.0)];
        [_backgroundView setBackgroundGradientBottomColor:GetRGBColor(0xd0d0d0, 1.0)];
        [_backgroundView setBackgroundColor:nil];
    } else {
        [_backgroundView setBackgroundGradientTopColor:   nil];
        [_backgroundView setBackgroundGradientBottomColor:nil];
        [_backgroundView setBackgroundColor:GetRGBColor(0xf4f4f4, 1.0)];
    }
}


#pragma mark - IBActions

- (IBAction) flatten:(id)sender
{
    [_graphicEQView flatten];
}


@end
