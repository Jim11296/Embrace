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


typedef NS_ENUM(NSInteger, ViewAttribute) {
    ViewAttributeArtist,
    ViewAttributeBeatsPerMinute,
    ViewAttributeComments,
    ViewAttributeGrouping,
    ViewAttributeKeySignature,
    ViewAttributeRawKeySignature,
    ViewAttributeEnergyLevel,
    ViewAttributeGenre
};

extern NSString * const PreferencesDidChangeNotification;


@interface Preferences : NSObject

+ (id) sharedInstance;

@property (nonatomic) NSInteger numberOfLayoutLines;

- (void) setViewAttribute:(ViewAttribute)attribute selected:(BOOL)selected;
- (BOOL) isViewAttributeSelected:(ViewAttribute)attribute;

@property (nonatomic) BOOL showsArtist;
@property (nonatomic) BOOL showsBPM;
@property (nonatomic) BOOL showsComments;
@property (nonatomic) BOOL showsGrouping;
@property (nonatomic) BOOL showsKeySignature;
@property (nonatomic) BOOL showsEnergyLevel;
@property (nonatomic) BOOL showsGenre;

@property (nonatomic) KeySignatureDisplayMode keySignatureDisplayMode;

@property (nonatomic) AudioDevice *mainOutputAudioDevice;
@property (nonatomic) double       mainOutputSampleRate;
@property (nonatomic) UInt32       mainOutputFrames;
@property (nonatomic) BOOL         mainOutputUsesHogMode;

@end
