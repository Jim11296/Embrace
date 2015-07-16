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
#import "EffectAdditions.h"
#import "Player.h"


typedef NS_ENUM(NSInteger, EffectCategory) {
    EffectCategoryEqualizers = 1,
    EffectCategoryFilters,
    EffectCategoryDynamics,
    EffectCategoryOther
};


static EffectCategory sGetCategory(NSString *name)
{
    EffectCategory result = EffectCategoryOther;

    NSDictionary *map = @{
        @"EmbraceGraphicEQ10":    @( EffectCategoryEqualizers ),
        @"EmbraceGraphicEQ31":    @( EffectCategoryEqualizers ),

        @"AUBandpass":            @( EffectCategoryFilters ),
        @"AUParametricEQ":        @( EffectCategoryFilters ),
        @"AULowpass":             @( EffectCategoryFilters ),
        @"AULowShelfFilter":      @( EffectCategoryFilters ),
        @"AUHipass":              @( EffectCategoryFilters ),
        @"AUHighShelfFilter":     @( EffectCategoryFilters ),
        @"AUFilter":              @( EffectCategoryFilters ),

        @"AUDynamicsProcessor":   @( EffectCategoryDynamics ),
        @"AUMultibandCompressor": @( EffectCategoryDynamics ),
        @"AUPeakLimiter":         @( EffectCategoryDynamics )
    };

    NSNumber *categoryNumber = [map objectForKey:name];
    if (categoryNumber) {
        result = [categoryNumber integerValue];
    }

    return result;
}


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
    NSMenu *filterMenu = [[NSMenu alloc] init];
    NSMenu *otherMenu  = [[NSMenu alloc] init];
    
    NSArray *allEffectTypes = [EffectType allEffectTypes];
    
    allEffectTypes = [allEffectTypes sortedArrayUsingComparator:^(id objectA, id objectB) {
        EffectType *typeA = (EffectType *)objectA;
        EffectType *typeB = (EffectType *)objectB;
        
        EffectCategory categoryA = sGetCategory([typeA name]);
        EffectCategory categoryB = sGetCategory([typeB name]);
        
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
    
    EffectCategory lastCategory = 0;
    
    BOOL didAddItem = NO;

    for (EffectType *type in allEffectTypes) {
        NSString *name = [type name];
        EffectCategory category = sGetCategory(name);
        NSString *friendlyName = [type friendlyName];

        if (category != lastCategory) {
            if (didAddItem) {
                [menu addItem:[NSMenuItem separatorItem]];
            }

            lastCategory = category;
        }
    
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:friendlyName action:NULL keyEquivalent:@""];
        [menuItem setRepresentedObject:type];

        if (category == EffectCategoryOther) {
            [otherMenu addItem:menuItem];
            
            [menuItem setTarget:[[self addButton] target]];
            [menuItem setAction:[[self addButton] action]];

        } else if (category == EffectCategoryFilters) {
            [filterMenu addItem:menuItem];
            
            [menuItem setTarget:[[self addButton] target]];
            [menuItem setAction:[[self addButton] action]];

        } else {
            [menu addItem:menuItem];
        }

        didAddItem = YES;
    }

    NSMenuItem *filterMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Filters", nil) action:nil keyEquivalent:@""];
    [filterMenuItem setSubmenu:filterMenu];
    
    NSMenuItem *otherMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Other Effects", nil) action:nil keyEquivalent:@""];
    [otherMenuItem setSubmenu:otherMenu];

    [filterMenu setAutoenablesItems:NO];
    [otherMenu setAutoenablesItems:NO];

    [menu addItem:filterMenuItem];
    [menu addItem:otherMenuItem];
    
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
