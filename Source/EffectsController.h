//
//  OutputWindowController.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Player;

@interface EffectsController : NSWindowController

- (IBAction) addEffect:(id)sender;
- (IBAction) editEffect:(id)sender;
- (IBAction) delete:(id)sender;

@property (nonatomic, strong) Player *player;
@property (nonatomic, strong) IBOutlet NSArrayController *effectsArrayController;

@property (nonatomic, strong) IBOutlet NSMenu *tableMenu;

@property (nonatomic, weak) IBOutlet NSPopUpButton *addButton;

@property (nonatomic, weak) IBOutlet NSTableView *tableView;

@end
