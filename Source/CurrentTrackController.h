//
//  LegacyCurrentTrackController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-21.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

@class WaveformView, Player;

@interface CurrentTrackController : NSWindowController <NSMenuDelegate>

- (IBAction) changeAppearance:(id)sender;
- (IBAction) changePinning:(id)sender;

@property (nonatomic, weak) IBOutlet WaveformView *waveformView;
@property (nonatomic, weak) IBOutlet NSVisualEffectView *effectView;

@property (nonatomic, strong) IBOutlet NSView *mainView;

@property (nonatomic, weak) IBOutlet NSTextField *noTrackLabel;
@property (nonatomic, weak) IBOutlet NSTextField *leftLabel;
@property (nonatomic, weak) IBOutlet NSTextField *rightLabel;

@property (nonatomic, weak) Player *player;

@end
