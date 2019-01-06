// (c) 2015-2018 Ricci Adams.  All rights reserved.

#import "EffectAdditions.h"

NSString * const EmbraceMappedEffect10BandEQ = @"EmbraceGraphicEQ10";
NSString * const EmbraceMappedEffect31BandEQ = @"EmbraceGraphicEQ31";


@implementation EffectType (EmbraceAdditions)

+ (void) embrace_registerMappedEffects
{
    AudioComponentDescription acd = {0};
    
    acd.componentType = kAudioUnitType_Effect;
    acd.componentSubType = kAudioUnitSubType_GraphicEQ;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    acd.componentFlags = kAudioComponentFlag_SandboxSafe;
    acd.componentFlagsMask = 0;

    [self registerMappedTypeWithName:EmbraceMappedEffect10BandEQ audioComponentDescription:&acd configurator:^(AUAudioUnit *unit) {
        AUParameter *parameter = [[unit parameterTree] parameterWithID:kGraphicEQParam_NumberOfBands scope:kAudioUnitScope_Global element:0];
        [parameter setValue:0];
    }];

    [self registerMappedTypeWithName:EmbraceMappedEffect31BandEQ audioComponentDescription:&acd configurator:^(AUAudioUnit *unit) {
        AUParameter *parameter = [[unit parameterTree] parameterWithID:kGraphicEQParam_NumberOfBands scope:kAudioUnitScope_Global element:0];
        [parameter setValue:1.0];
    }];
}


- (NSString *) friendlyName
{
    NSString *name = [self name];

    NSDictionary *map = @{
        EmbraceMappedEffect10BandEQ: NSLocalizedString(@"10-band Graphic Equalizer", nil),
        EmbraceMappedEffect31BandEQ: NSLocalizedString(@"31-band Graphic Equalizer", nil),

        @"AUDynamicsProcessor":   NSLocalizedString(@"Dynamics Processor", nil),
        @"AUHipass":              NSLocalizedString(@"Highpass Filter", nil),
        @"AUBandpass":            NSLocalizedString(@"Bandpass Filter", nil),
        @"AUHighShelfFilter":     NSLocalizedString(@"Highshelf Filter", nil),
        @"AUPeakLimiter":         NSLocalizedString(@"Peak Limiter", nil),
        @"AULowpass":             NSLocalizedString(@"Lowpass Filter", nil),
        @"AULowShelfFilter":      NSLocalizedString(@"Lowshelf Filter", nil),
        @"AUMultibandCompressor": NSLocalizedString(@"Multiband Compressor", nil),
        @"AUParametricEQ":        NSLocalizedString(@"1-Band Parametric Filter", nil),
        @"AUFilter":              NSLocalizedString(@"5-Band Parametric Filter", nil),
    };
    
    NSString *friendlyName = [map objectForKey:name];
    
    if (!friendlyName) {
        friendlyName = name;
    }
    
    return friendlyName;
}


@end
