//
//  Component.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "EffectType.h"


@implementation EffectType {
    AudioComponent _component;
    AudioComponentDescription _componentDescription;
}

@synthesize AudioComponent = _component;
@synthesize AudioComponentDescription = _componentDescription;

+ (EffectFriendlyCategory) friendlyCategoryForName:(NSString *)name
{
    EffectFriendlyCategory result = EffectFriendlyCategorySpecial;

    NSDictionary *map = @{
        @"AUGraphicEQ":           @( EffectFriendlyCategoryEqualizers ),
        @"AUNBandEQ":             @( EffectFriendlyCategoryEqualizers ),
        @"AUParametricEQ":        @( EffectFriendlyCategoryEqualizers ),

        @"AULowpass":             @( EffectFriendlyCategoryFilters ),
        @"AULowShelfFilter":      @( EffectFriendlyCategoryFilters ),
        @"AUHipass":              @( EffectFriendlyCategoryFilters ),
        @"AUHighShelfFilter":     @( EffectFriendlyCategoryFilters ),

        @"AUDynamicsProcessor":   @( EffectFriendlyCategoryDynamics ),
        @"AUMultibandCompressor": @( EffectFriendlyCategoryDynamics ),
        @"AUPeakLimiter":         @( EffectFriendlyCategoryDynamics )
    };

    NSNumber *categoryNumber = [map objectForKey:name];
    if (categoryNumber) {
        result = [categoryNumber integerValue];
    }

    return result;
}


+ (NSString *) friendlyNameForName:(NSString *)name
{
    NSDictionary *map = @{
        @"AUDynamicsProcessor":   NSLocalizedString(@"Dynamics Processor", nil),
        @"AUGraphicEQ":           NSLocalizedString(@"Graphic Equalizer", nil),
        @"AUHipass":              NSLocalizedString(@"Highpass Filter", nil),
        @"AUHighShelfFilter":     NSLocalizedString(@"Highshelf Filter", nil),
        @"AUPeakLimiter":         NSLocalizedString(@"Peak Limiter", nil),
        @"AULowpass":             NSLocalizedString(@"Lowpass Filter", nil),
        @"AULowShelfFilter":      NSLocalizedString(@"Lowshelf Filter", nil),
        @"AUMultibandCompressor": NSLocalizedString(@"Multiband Compressor", nil),
        @"AUNBandEQ":             NSLocalizedString(@"N-Band Equalizer", nil),
        @"AUParametricEQ":        NSLocalizedString(@"Parametric Equalizer", nil),
    };
    
    NSString *friendlyName = [map objectForKey:name];
    
    if (!friendlyName) {
        friendlyName = name;
    }
    
    return friendlyName;
}


static BOOL sIsBlacklistedComponent(AudioComponent component)
{
    CFStringRef cfName = nil;
    AudioComponentCopyName(component, &cfName);

    NSString *name = CFBridgingRelease(cfName);
    if ([name isEqualToString:@"Apple: AUNetSend"] || [name isEqualToString:@"Apple: AUNetReceive"]) {
        return YES;
    }

    return NO;
}



+ (NSArray *) allEffectTypes
{
    static NSArray *sAllEffectTypes = nil;

    if (!sAllEffectTypes) {
        AudioComponentDescription description;

        description.componentType = kAudioUnitType_Effect;
        description.componentSubType = 0;
        description.componentManufacturer = 0;
        description.componentFlags = kAudioComponentFlag_SandboxSafe;
        description.componentFlagsMask = 0;

        UInt32 componentCount = AudioComponentCount(&description);

        NSMutableArray *types = [NSMutableArray arrayWithCapacity:componentCount];

        AudioComponent current = 0;

        do {
            @autoreleasepool {
                current = AudioComponentFindNext(current, &description);

                if (sIsBlacklistedComponent(current)) {
                    continue;
                }
                
                if (current) {
                    EffectType *type = [[EffectType alloc] _initWithComponent:current];
                    if (type) [types addObject:type];
                }
            }
        } while (current != 0);
        
        sAllEffectTypes = types;
    }
    
    return sAllEffectTypes;
}


- (id) _initWithComponent:(AudioComponent)component;
{
    if ((self = [super init])) {
        _component = component;
        _manufacturer = @"";
        _name = @"";

        if (noErr != AudioComponentGetDescription(component, &_componentDescription)) {
            self = nil;
            return nil;
        }

        CFStringRef cfFullName = NULL;

        if (noErr != AudioComponentCopyName(component, &cfFullName)) {
            self = nil;
            return nil;
        }
        
        _fullName = CFBridgingRelease(cfFullName);
        
        NSRange colonRange = [_fullName rangeOfString:@":"];

        if (colonRange.location != NSNotFound) {
            _manufacturer = [_fullName substringToIndex: colonRange.location];
            _name = [_fullName substringFromIndex: colonRange.location + 1];
            _name = [_name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        } else {
            _manufacturer = @"";
            _name = [_fullName copy];
        }
    }
    
    return self;
}


- (NSString *) friendlyName
{
    return [EffectType friendlyNameForName:[self name]];
}


- (EffectFriendlyCategory) friendlyCategory
{
    return [EffectType friendlyCategoryForName:[self name]];
}

@end
