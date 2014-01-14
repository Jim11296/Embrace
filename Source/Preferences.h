//
//  Preferences.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AudioDevice;

typedef NS_ENUM(NSInteger, KeySignatureMode) {
    KeySignatureModeNone,
    KeySignatureModeTraditional,
    KeySignatureModeCamelot
};

extern NSString * const PreferencesDidChangeNotification;


@interface Preferences : NSObject

+ (id) sharedInstance;

@property (nonatomic) BOOL preventsAccidents;
@property (nonatomic) BOOL warnsAboutIssues;

@property (nonatomic) BOOL exportsHistory;
@property (nonatomic) BOOL groupsHistoryByFolder;
@property (nonatomic) NSString *historyFolderName;

@property (nonatomic) KeySignatureMode keySignatureMode;

@property (nonatomic) AudioDevice *mainOutputAudioDevice;
@property (nonatomic) double       mainOutputSampleRate;
@property (nonatomic) UInt32       mainOutputFrames;
@property (nonatomic) BOOL         mainOutputUsesHogMode;

@property (nonatomic) AudioDevice *editingAudioDevice;

@property (nonatomic) NSData   *preferredLibraryData;
@property (nonatomic) NSString *preferredLibraryName;

@end
