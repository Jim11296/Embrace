//
//  Scripting.m
//  Embrace
//
//  Created by Ricci Adams on 2014-02-27.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Scripting.h"
#import "Track.h"
#import "SetlistController.h"
#import "AppDelegate.h"
#import "iTunesManager.h"

@interface Track (Scripting)
@end


@interface NSApplication (Scripting)
@end


@implementation NSApplication (Scripting)

- (NSArray *) scriptingTracks
{
    return [[GetAppDelegate() setlistController] tracks];
}


- (Track *) scriptingCurrentTrack
{
    return [[Player sharedInstance] currentTrack];
}


- (NSNumber *) scriptingElapsedTime
{
    Player *player = [Player sharedInstance];
    return [player isPlaying] ? @([player timeElapsed]) : @0;
}


- (NSNumber *) scriptingRemainingTime
{
    Player *player = [Player sharedInstance];
    return [player isPlaying] ? @([player timeRemaining]) : @0;
}

@end


@implementation Track (Scripting)

- (NSScriptObjectSpecifier *) objectSpecifier
{
    SetlistController *setlistController = [GetAppDelegate() setlistController];
    NSArray *tracks = [setlistController tracks];

    NSScriptObjectSpecifier *objectSpecifier = nil;
    NSUInteger index = [tracks indexOfObjectIdenticalTo:self];

    if (index != NSNotFound) {
        NSScriptClassDescription *containerDescription = (NSScriptClassDescription *)[NSApp classDescription];
        objectSpecifier = [[NSIndexSpecifier alloc] initWithContainerClassDescription:containerDescription containerSpecifier:nil key:@"scriptingTracks" index:index];
    }

    return objectSpecifier;
}


- (NSNumber *) scriptingTrackStatus
{
    return @([self trackStatus]);
}


- (NSString *) scriptingTitle
{
    return [self title];
}


- (NSString *) scriptingArtist
{
    return [self artist];
}


- (NSNumber *) scriptingDuration
{
    return @([self playDuration]);
}


- (NSURL *) scriptingFile
{
    return [self fileURL];
}


- (NSNumber *) scriptingDatabaseID
{
    return @([self databaseID]);
}


@end