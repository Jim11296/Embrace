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
#import "TracksController.h"
#import "AppDelegate.h"
#import "iTunesManager.h"

@interface Track (Scripting)
@end


@interface NSApplication (Scripting)
@end


@implementation NSApplication (Scripting)

- (NSArray *) scriptingTracks
{
    return [[[GetAppDelegate() setlistController] tracksController] tracks];
}


- (Track *) scriptingCurrentTrack
{
    return [[Player sharedInstance] currentTrack];
}


- (NSNumber *) scriptingCurrentIndex
{
    Track *currentTrack = [[Player sharedInstance] currentTrack];
    if (!currentTrack) return @(0);

    NSArray *tracks = [[[GetAppDelegate() setlistController] tracksController] tracks];
    NSUInteger index = [tracks indexOfObject:currentTrack];
    
    if (index == NSNotFound) {
        return @(0);
    } else {
        return @(index + 1);
    }
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
    TracksController *tracksController = [[GetAppDelegate() setlistController] tracksController];
    NSArray *tracks = [tracksController tracks];

    NSScriptObjectSpecifier *objectSpecifier = nil;
    NSUInteger index = [tracks indexOfObjectIdenticalTo:self];

    if (index != NSNotFound) {
        NSScriptClassDescription *containerDescription = (NSScriptClassDescription *)[NSApp classDescription];
        objectSpecifier = [[NSIndexSpecifier alloc] initWithContainerClassDescription:containerDescription containerSpecifier:nil key:@"scriptingTracks" index:index];
    }

    return objectSpecifier;
}


- (NSString *) scriptingAggregate
{
    NSString *(^getSanitizedString)(NSString *) = ^(NSString *inString) {
        if (!inString) return @"";

        if ([inString rangeOfString:@"\t"].location != NSNotFound) {
            return [inString stringByReplacingOccurrencesOfString:@"\t" withString:@"  "];
        } else {
            return inString;
        }
    };

    return [NSString stringWithFormat:@"%@\t%@\t%@\t%@\t%@\t%@\t%@\t%@",
        getSanitizedString( [self title]       ),
        getSanitizedString( [self artist]      ),
        getSanitizedString( [self album]       ),
        getSanitizedString( [self genre]       ),
        getSanitizedString( [self comments]    ),
        getSanitizedString( [self albumArtist] ),
        getSanitizedString( [self composer]    ),
        getSanitizedString( [self grouping]    )
    ];
}


- (NSNumber *) scriptingTrackStatus
{
    return @([self trackStatus]);
}


- (NSString *) scriptingTitle
{
    return [self title];
}


- (NSString *) scriptingAlbumArtist
{
    return [self albumArtist];
}


- (NSString *) scriptingAlbum
{
    return [self album];
}


- (NSString *) scriptingArtist
{
    return [self artist];
}


- (NSString *) scriptingComment
{
    return [self comments];
}


- (NSString *) scriptingComposer
{
    return [self composer];
}


- (NSString *) scriptingGrouping
{
    return [self grouping];
}


- (NSString *) scriptingGenre
{
    return [self genre];
}


- (NSNumber *) scriptingDuration
{
    return @([self playDuration]);
}


- (NSURL *) scriptingFile
{
    return [self externalURL];
}


- (NSNumber *) scriptingDatabaseID
{
    return @([self databaseID]);
}


- (NSNumber *) scriptingEnergyLevel
{
    return @([self energyLevel]);
}


- (void) setScriptingLabel:(NSNumber *)scriptingLabel
{
    [self setTrackLabel:[scriptingLabel integerValue]];
}


- (NSNumber *) scriptingLabel
{
    return @([self trackLabel]);
}


- (void) setScriptingStopsAfterPlaying:(NSNumber *)stopsAfterPlaying
{
    [self setStopsAfterPlaying:[stopsAfterPlaying boolValue]];
}


- (NSNumber *) scriptingStopsAfterPlaying
{
    return @([self stopsAfterPlaying]);
}


- (void) setScriptingIgnoresAutoGap:(NSNumber *)ignoresAutoGap
{
    [self setIgnoresAutoGap:[ignoresAutoGap boolValue]];
}


- (NSNumber *) scriptingIgnoresAutoGap
{
    return @([self ignoresAutoGap]);
}


- (NSString *) scriptingKeySignature
{
    return GetTraditionalStringForTonality([self tonality]);
}


- (NSNumber *) scriptingYear
{
    return @([self year]);
}


@end
