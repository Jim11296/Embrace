//
//  Effect.m
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "Effect.h"
#import "EffectType.h"
#import "Player.h"
#import "EditEffectController.h"

static NSString *sNameKey = @"name";
static NSString *sInfoKey = @"info";

NSString * const EffectDidDeallocNotification = @"EffectDidDealloc";


@implementation Effect {
    EffectType   *_type;
    NSDictionary *_classInfoToLoad;
    AudioUnit     _audioUnit;
    EffectSettingsController *_settingsController;
}

@dynamic hasCustomView;


+ (instancetype) effectWithStateDictionary:(NSDictionary *)dictionary
{
    return [[self alloc] initWithStateDictionary:dictionary];
}


+ (instancetype) effectWithEffectType:(EffectType *)effectType
{
    return [[self alloc] initWithEffectType:effectType];
}


- (id) initWithEffectType:(EffectType *)effectType
{
    if ((self = [super init])) {
        _type = effectType;
    }
    
    return self;
}


- (id) initWithStateDictionary:(NSDictionary *)dictionary
{
    NSString *name = [dictionary objectForKey:sNameKey];
    NSData   *info = [dictionary objectForKey:sInfoKey];

    if (![name isKindOfClass:[NSString class]] || ![info isKindOfClass:[NSData class]]) {
        self = nil;
        return nil;
    }
    
    EffectType *typeToUse = nil;

    for (EffectType *type in [EffectType allEffectTypes]) {
        if ([[type name] isEqualToString:name]) {
            typeToUse = type;
        }
    }
    
    if (!typeToUse) {
        self = nil;
        return nil;
    }
    
    self = [self initWithEffectType:typeToUse];
 
    NSError *error = nil;
    _classInfoToLoad = [NSPropertyListSerialization propertyListWithData:info options:NSPropertyListImmutable format:NULL error:&error];
    
    if (!_classInfoToLoad || error) {
        self = nil;
        return nil;
    }
    
    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] postNotificationName:EffectDidDeallocNotification object:nil];
}

- (BOOL) loadClassInfoDictionary:(NSDictionary *)dictionary
{
    if (noErr != AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &dictionary, sizeof(dictionary))) {
        return NO;
    }
 
    AudioUnitParameter changedUnit;
    changedUnit.mAudioUnit = _audioUnit;
    changedUnit.mParameterID = kAUParameterListener_AnyParameter;

    AUParameterListenerNotify(NULL, NULL, &changedUnit);

    return YES;
}


- (BOOL) loadAudioPresetAtFileURL:(NSURL *)fileURL
{
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:fileURL];
    if (!dictionary) return NO;

    return [self loadClassInfoDictionary:dictionary];
}


- (AudioUnit) audioUnit
{
    return _audioUnit;
}


- (void) _setAudioUnit:(AudioUnit)audioUnit
{
    _audioUnit = audioUnit;
    
    if (_audioUnit && _classInfoToLoad) {
        [self loadClassInfoDictionary:_classInfoToLoad];
        _classInfoToLoad = nil;
    }
}


- (NSDictionary *) stateDictionary
{
    NSDictionary *classInfo = nil;
    UInt32 classInfoSize = sizeof(classInfo);
    
    if (noErr != AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0, &classInfo, &classInfoSize)) {
        return NO;
    }

    NSError  *error = nil;
    NSString *name  = [_type name];
    NSData   *info  = [NSPropertyListSerialization dataWithPropertyList:classInfo format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    
    if (error || !info || !name) return nil;
    
    return @{
        sNameKey: name,
        sInfoKey: info
    };
}


- (BOOL) hasCustomView
{
    UInt32 dataSize   = 0;
    Boolean isWritable = 0;
    AudioUnitGetPropertyInfo(_audioUnit, kAudioUnitProperty_CocoaUI, kAudioUnitScope_Global, 0, &dataSize, &isWritable);
    
    return (dataSize > 0);
}


- (void) setBypass:(BOOL)bypass
{
    UInt32 data = bypass;
    UInt32 dataSize = sizeof(data);
    
    AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &data, dataSize);
}


- (BOOL) bypass
{
    UInt32 data = 0;
    UInt32 dataSize = sizeof(data);
    
    AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0, &data, &dataSize);
    
    return (data > 0);
}

@end

