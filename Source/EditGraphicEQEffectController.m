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
#import "GraphicEQView.h"
#import "Button.h"

#import <AudioUnit/AUCocoaUIView.h>

@interface EditGraphicEQEffectController ()

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
        [_graphicEQView numberOfBands] == 10 ? 395 : 770,
        215
    );

    NSWindow *window = [self window];
    [window setContentMinSize:contentSize];
    [window setContentMaxSize:contentSize];
    [window setMovableByWindowBackground:YES];
    [window setTitleVisibility:NSWindowTitleHidden];
    [window setTitlebarAppearsTransparent:YES];

    CGRect rect = [window contentRectForFrameRect:[window frame]];
    rect.size = contentSize;
    rect = [window frameRectForContentRect:rect];

    [window setFrame:rect display:YES animate:NO];
    
    // Adjust subviews (we can't do this in Interface Builder as the NSVisualEffectView
    // obscures the toolbar
    //
    [[self backgroundView] setFrame:[[window contentView] bounds]];

    CGRect eqViewFrame = [[self backgroundView] bounds];
    eqViewFrame.size.height -= 34;
    [[self graphicEQView] setFrame:eqViewFrame];
}


- (void) reloadData
{
    [_graphicEQView reloadData];
}


#pragma mark - IBActions

- (IBAction) flatten:(id)sender
{
    [_graphicEQView flatten];
}


@end
