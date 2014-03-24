//
//  Preferences.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-13.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Preferences.h"
#import "AudioDevice.h"


NSString * const PreferencesDidChangeNotification = @"PreferencesDidChange";


static NSDictionary *sGetDefaultValues()
{
    static NSDictionary *sDefaultValues = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{

    sDefaultValues = @{
        @"numberOfLayoutLines": @2,

        @"showsArtist":       @YES,
        @"showsBPM":          @YES,
        @"showsComments":     @NO,
        @"showsGrouping":     @NO,
        @"showsKeySignature": @YES,
        @"showsEnergyLevel":  @NO,
        @"showsGenre":        @NO,

        @"keySignatureDisplayMode": @( KeySignatureDisplayModeRaw ),

        @"mainOutputAudioDevice": [AudioDevice defaultOutputDevice],
        @"mainOutputSampleRate":  @(0),
        @"mainOutputFrames":      @(0),
        @"mainOutputUsesHogMode": @(NO)
    };
    
    });
    
    return sDefaultValues;
}


static void sSetDefaultObject(id dictionary, NSString *key, id valueToSave, id defaultValue)
{
    void (^saveObject)(NSObject *, NSString *) = ^(NSObject *o, NSString *k) {
        if (o) {
            [dictionary setObject:o forKey:k];
        } else {
            [dictionary removeObjectForKey:k];
        }
    };

    if ([defaultValue isKindOfClass:[NSNumber class]]) {
        saveObject(valueToSave, key);

    } else if ([defaultValue isKindOfClass:[AudioDevice class]]) {
        saveObject([valueToSave dictionaryRepresentation], key);

    } else if ([defaultValue isKindOfClass:[NSData class]]) {
        saveObject(valueToSave, key);

    } else if ([defaultValue isKindOfClass:[NSData class]]) {
        saveObject(valueToSave, key);
    }
}


static void sRegisterDefaults()
{
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

    NSDictionary *defaultValuesDictionary = sGetDefaultValues();

    for (NSString *key in defaultValuesDictionary) {
        id value = [defaultValuesDictionary objectForKey:key];
        sSetDefaultObject(defaults, key, value, value);
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


@implementation Preferences


+ (id) sharedInstance
{
    static Preferences *sSharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sRegisterDefaults();
        sSharedInstance = [[Preferences alloc] init];
    });
    
    return sSharedInstance;
}


- (id) init
{
    if ((self = [super init])) {
        [self _load];
        
        for (NSString *key in sGetDefaultValues()) {
            [self addObserver:self forKeyPath:key options:0 context:NULL];
        }
    }

    return self;
}


- (void) _load
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSDictionary *defaultValuesDictionary = sGetDefaultValues();
    for (NSString *key in defaultValuesDictionary) {
        id defaultValue = [defaultValuesDictionary objectForKey:key];

        if ([defaultValue isKindOfClass:[NSNumber class]]) {
            [self setValue:@([defaults integerForKey:key]) forKey:key];

        } else if ([defaultValue isKindOfClass:[NSData class]]) {
            [self setValue:[defaults objectForKey:key] forKey:key];

        } else if ([defaultValue isKindOfClass:[NSString class]]) {
            [self setValue:[defaults objectForKey:key] forKey:key];

        } else if ([defaultValue isKindOfClass:[AudioDevice class]]) {
            NSDictionary *dictionary = [defaults objectForKey:key];

            if ([dictionary isKindOfClass:[NSDictionary class]]) {
                AudioDevice *device = [AudioDevice audioDeviceWithDictionary:dictionary];
                [AudioDevice selectChosenAudioDevice:device];
                if (device) [self setValue:device forKey:key];
            }
        }
    }
}


- (NSString *) _keyForViewAttribute:(ViewAttribute)attribute
{
    if (attribute == ViewAttributeArtist) {
        return @"showsArtist";

    } else if (attribute == ViewAttributeBeatsPerMinute) {
        return @"showsBPM";
        
    } else if (attribute == ViewAttributeComments) {
        return @"showsComments";

    } else if (attribute == ViewAttributeGrouping) {
        return @"showsGrouping";

    } else if (attribute == ViewAttributeKeySignature) {
        return @"showsKeySignature";
    
    } else if (attribute == ViewAttributeEnergyLevel) {
        return @"showsEnergyLevel";

    } else if (attribute == ViewAttributeGenre) {
        return @"showsGenre";
    }
    
    return nil;
}


- (void) _save
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Do audio device checking
    AudioDevice *device = [self mainOutputAudioDevice];
    
    if (![[device sampleRates] containsObject:@([self mainOutputSampleRate])]) {
        [self setMainOutputSampleRate:[[[device sampleRates] firstObject] doubleValue]];
    }

    if (![[device frameSizes] containsObject:@([self mainOutputFrames])]) {
        [self setMainOutputFrames:[[[device frameSizes] firstObject] unsignedIntValue]];
    }

    NSDictionary *defaultValuesDictionary = sGetDefaultValues();
    for (NSString *key in defaultValuesDictionary) {
        id defaultValue = [defaultValuesDictionary objectForKey:key];
        id selfValue    = [self valueForKey:key];
        
        sSetDefaultObject(defaults, key, selfValue, defaultValue);
    }
}


- (void) restoreDefaultColors
{
    NSDictionary *defaultValuesDictionary = sGetDefaultValues();

    for (NSString *key in defaultValuesDictionary) {
        id defaultValue = [defaultValuesDictionary objectForKey:key];

        if ([defaultValue isKindOfClass:[NSColor class]]) {
            [self setValue:defaultValue forKey:key];
        }
    }
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PreferencesDidChangeNotification object:self];
        [self _save];
    }
}


- (void) setViewAttribute:(ViewAttribute)attribute selected:(BOOL)selected
{
    NSString *key = [self _keyForViewAttribute:attribute];
    if (!key) return;
    
    [self setValue:@(selected) forKey:key];
}


- (BOOL) isViewAttributeSelected:(ViewAttribute)attribute
{
    NSString *key = [self _keyForViewAttribute:attribute];
    if (!key) return NO;

    return [[self valueForKey:key] boolValue];
}


@end
