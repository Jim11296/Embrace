//
//  OutputWindowController.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-05.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "EffectsController.h"

#import "EditEffectController.h"
#import "AppDelegate.h"
#import "EffectType.h"
#import "Effect.h"
#import "Player.h"



@interface EffectsController () <NSMenuDelegate>
@end


@implementation EffectsController

@dynamic player;

- (NSString *) windowNibName
{
    return @"EffectsWindow";
}


- (void) dealloc
{
    [[self effectsArrayController] removeObserver:self forKeyPath:@"selectionIndexes" context:NULL];
}


- (void) windowDidLoad
{
    [super windowDidLoad];

    NSMenu *menu = [[self addButton] menu];

    for (EffectType *type in [EffectType allEffectTypes]) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[type name] action:NULL keyEquivalent:@""];
        [menuItem setRepresentedObject:type];
        [menu addItem:menuItem];
    }
    
    [[self tableView] setDoubleAction:@selector(editEffect:)];
}


- (IBAction) addEffect:(id)sender
{
    EffectType *type = [[sender selectedItem] representedObject];
    
    Effect *effect = [Effect effectWithEffectType:type];
    [[self effectsArrayController] addObject:effect];
}


- (IBAction) editEffect:(id)sender
{
    Effect *selectedEffect = [[[self effectsArrayController] selectedObjects] lastObject];

    if (selectedEffect) {
        [[GetAppDelegate() editControllerForEffect:selectedEffect] showWindow:self];
    }
}


- (void) delete:(id)sender
{
    NSArrayController *arrayController = [self effectsArrayController];

    NSArray *selectedObjects = [arrayController selectedObjects];
    
    for (Effect *effect in selectedObjects) {
        [GetAppDelegate() closeEditControllerForEffect:effect];
    }
    
    [arrayController removeObjects:selectedObjects];
}


- (Player *) player
{
    return [Player sharedInstance];
}


@end
