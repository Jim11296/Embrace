//
//  Preferences.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AudioDevice;

typedef NS_ENUM(NSInteger, KeySignatureDisplayMode) {
    KeySignatureDisplayModeRaw,
    KeySignatureDisplayModeTraditional,
    KeySignatureDisplayModeOpenKeyNotation
};


typedef NS_ENUM(NSInteger, TrackViewAttribute) {
    TrackViewAttributeArtist          = 0,
    TrackViewAttributeBeatsPerMinute  = 1,
    TrackViewAttributeComments        = 2,
    TrackViewAttributeGrouping        = 3,
    TrackViewAttributeKeySignature    = 4,
    TrackViewAttributeRawKeySignature = 5,
    TrackViewAttributeEnergyLevel     = 6,
    TrackViewAttributeGenre           = 7,
    TrackViewAttributeDuplicateStatus = 8,
    TrackViewAttributePlayingStatus   = 9,
    TrackViewAttributeLabelStripes    = 10,
    TrackViewAttributeLabelDots       = 11,
    TrackViewAttributeYear            = 12,
    TrackViewAttributeAlbumArtist     = 13
};

extern NSString * const PreferencesDidChangeNotification;


@interface Preferences : NSObject

+ (id) sharedInstance;

@property (nonatomic) NSInteger numberOfLayoutLines;
@property (nonatomic) BOOL shortensPlayedTracks;

- (void) setTrackViewAttribute:(TrackViewAttribute)attribute selected:(BOOL)selected;
- (BOOL) isTrackViewAttributeSelected:(TrackViewAttribute)attribute;

@property (nonatomic) BOOL showsAlbumArtist;
@property (nonatomic) BOOL showsArtist;
@property (nonatomic) BOOL showsBPM;
@property (nonatomic) BOOL showsComments;
@property (nonatomic) BOOL showsDuplicateStatus;
@property (nonatomic) BOOL showsGenre;
@property (nonatomic) BOOL showsGrouping;
@property (nonatomic) BOOL showsKeySignature;
@property (nonatomic) BOOL showsEnergyLevel;
@property (nonatomic) BOOL showsPlayingStatus;
@property (nonatomic) BOOL showsLabelDots;
@property (nonatomic) BOOL showsLabelStripes;
@property (nonatomic) BOOL showsYear;

@property (nonatomic) BOOL floatsOnTop;

@property (nonatomic) KeySignatureDisplayMode keySignatureDisplayMode;

@property (nonatomic) AudioDevice *mainOutputAudioDevice;
@property (nonatomic) double       mainOutputSampleRate;
@property (nonatomic) UInt32       mainOutputFrames;
@property (nonatomic) BOOL         mainOutputUsesHogMode;
@property (nonatomic) BOOL         mainOutputResetsVolume;

@property (nonatomic) BOOL         usesMasteringComplexitySRC;

@end
