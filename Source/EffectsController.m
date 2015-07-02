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


- (IBAction) addEffect:(id)sender;
- (IBAction) editEffect:(id)sender;
- (IBAction) delete:(id)sender;

- (IBAction) updateStereoBalance:(id)sender;

@property (nonatomic, strong) IBOutlet NSArrayController *effectsArrayController;

@property (nonatomic, strong) IBOutlet NSMenu *tableMenu;

@property (nonatomic, weak) IBOutlet NSPopUpButton *addButton;

@property (nonatomic, weak) IBOutlet NSTableView *tableView;


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
    NSMenu *specialMenu = [[NSMenu alloc] init];
    
    NSArray *allEffectTypes = [EffectType allEffectTypes];
    
    allEffectTypes = [allEffectTypes sortedArrayUsingComparator:^(id objectA, id objectB) {
        EffectType *typeA = (EffectType *)objectA;
        EffectType *typeB = (EffectType *)objectB;
        
        EffectFriendlyCategory categoryA = [typeA friendlyCategory];
        EffectFriendlyCategory categoryB = [typeB friendlyCategory];
        
        if (categoryA > categoryB) {
            return NSOrderedDescending;
        } else if (categoryB > categoryA) {
            return NSOrderedAscending;
        } else {
            NSString *nameA = [typeA friendlyName];
            NSString *nameB = [typeB friendlyName];
            
            return [nameA compare:nameB];
        }
    }];
    
    EffectFriendlyCategory lastFriendlyCategory = 0;
    
    BOOL didAddItem = NO;

    for (EffectType *type in allEffectTypes) {
        EffectFriendlyCategory friendlyCategory = [type friendlyCategory];

        if (friendlyCategory != lastFriendlyCategory) {
            if (didAddItem) {
                [menu addItem:[NSMenuItem separatorItem]];
            }

            lastFriendlyCategory = friendlyCategory;
        }
    
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[type friendlyName] action:NULL keyEquivalent:@""];
        [menuItem setRepresentedObject:type];

        if (friendlyCategory != EffectFriendlyCategorySpecial) {
            [menu addItem:menuItem];
        } else {
            [specialMenu addItem:menuItem];
            
            [menuItem setTarget:[[self addButton] target]];
            [menuItem setAction:[[self addButton] action]];
        }

        didAddItem = YES;
    }
    
    NSMenuItem *specialMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Special", nil) action:nil keyEquivalent:@""];
    [specialMenuItem setSubmenu:specialMenu];
    
    [specialMenu setAutoenablesItems:NO];
    
    [menu addItem:specialMenuItem];
    
    [[self tableView] setDoubleAction:@selector(editEffect:)];

    [[self window] setExcludedFromWindowsMenu:YES];
}


- (IBAction) addEffect:(id)sender
{
    id representedObject = nil;

    if ([sender isKindOfClass:[NSPopUpButton class]]) {
        representedObject = [[sender selectedItem] representedObject];
    } else {
        representedObject = [sender representedObject];
    }

    EffectType *type = representedObject;
    
    Effect *effect = [Effect effectWithEffectType:type];
    if (effect) [[self effectsArrayController] addObject:effect];
}


- (IBAction) editEffect:(id)sender
{
    Effect *selectedEffect = [[[self effectsArrayController] selectedObjects] lastObject];

    if ([selectedEffect audioUnitError]) {
        NSAlert *alert = [[NSAlert alloc] init];
        
        [alert setMessageText:NSLocalizedString(@"Could not load Effect", nil)];
        [alert setInformativeText:NSLocalizedString(@"Contact the effect's manufacturer for a sandbox-compliant version.", nil)];
        
        [alert runModal];
        
    } else if (selectedEffect) {
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


- (IBAction) updateStereoBalance:(id)sender
{
    double doubleValue = [sender doubleValue];

    if (doubleValue >= 0.48 && doubleValue <= 0.52) {
        [sender setDoubleValue:0.5];
    }
}


- (Player *) player
{
    return [Player sharedInstance];
}


@end
