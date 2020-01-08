//
//  MusicLocationsController.m
//  Embrace
//
//  Created by Ricci Adams on 2020-01-06.
//  Copyright © 2020 Ricci Adams. All rights reserved.
//

#import "MusicLocationsController.h"
#import "SandboxManager.h"


@interface MusicLocationsController ()

@property (nonatomic, strong) IBOutlet NSArrayController *arrayController;
@property (nonatomic) SandboxManager *sandboxManager;

@end


@implementation MusicLocationsController

- (NSString *) windowNibName
{
    return @"MusicLocationsWindow";
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) awakeFromNib
{
    [self setSandboxManager:[SandboxManager sharedInstance]];

    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:YES];
    [[self arrayController] setSortDescriptors:@[ sortDescriptor ]];
}


- (IBAction) addLocation:(id)sender
{
    __weak auto weakSelf = self;

    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    [openPanel setPrompt:NSLocalizedString(@"Add", nil)];
    [openPanel setAllowedFileTypes:@[ NSFileTypeDirectory ]];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:YES];

    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
        NSURL *fileURL = [openPanel URL];

        if ((returnCode == NSModalResponseOK) && fileURL) {
            SandboxPersistentGrant *grant = [[SandboxPersistentGrant alloc] initWithFileURL:fileURL];
            [[weakSelf arrayController] addObject:grant];
        }
    }];
}


- (IBAction) removeSelectedLocations:(id)sender
{
    NSArrayController *arrayController = [self arrayController];
    [arrayController removeObjects:[arrayController selectedObjects]];
}


@end
