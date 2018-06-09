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
@property (nonatomic, weak) IBOutlet NSVisualEffectView *backgroundView;
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
    [window setContentMinSize:contentSize];
    [window setContentMaxSize:contentSize];

    CGRect rect = [window contentRectForFrameRect:[[self window] frame]];
    rect.size = contentSize;
    rect = [window frameRectForContentRect:rect];

    [window setFrame:rect display:YES animate:NO];

    [[self toolbar] setShowsBaselineSeparator:NO];
}


- (void) reloadData
{
    [_graphicEQView reloadData];
}


#pragma mark - IBActions

- (IBAction) flatten:(id)sender
{
    [self restoreDefaultValues:sender];
}


@end
