// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import "Effect.h"
#import "EffectType.h"
#import "Player.h"
#import "EditEffectController.h"

static NSString *sNameKey = @"name";
static NSString *sInfoKey = @"info";

NSString * const EffectDidDeallocNotification = @"EffectDidDealloc";


@implementation Effect {
    EffectType   *_type;
    NSDictionary *_defaultFullState;
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
        
        NSError *error = nil;
        _audioUnit = [[AUAudioUnit alloc] initWithComponentDescription:[effectType AudioComponentDescription] error:&error];
        _audioUnitError = error;

        if (_audioUnit) {
            MappedEffectTypeConfigurator configurator = [effectType configurator];
            if (configurator) configurator(_audioUnit);
        }

        NSString *defaultPresetPath = [[NSBundle mainBundle] pathForResource:[[self type] name] ofType:@"aupreset"];
        if (defaultPresetPath) {
            NSDictionary *defaultPreset = [NSDictionary dictionaryWithContentsOfFile:defaultPresetPath];
            [_audioUnit setFullState:defaultPreset];
        }

        _defaultFullState = [_audioUnit fullState];
    }
    
    return self;
}


- (id) initWithStateDictionary:(NSDictionary *)dictionary
{
    NSString *name = [dictionary objectForKey:sNameKey];
    NSData   *info = [dictionary objectForKey:sInfoKey];

    if (![name isKindOfClass:[NSString class]] || (info && ![info isKindOfClass:[NSData class]])) {
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
 
    if (info) {
        NSError *error = nil;
        
        NSDictionary *fullState = [NSPropertyListSerialization propertyListWithData:info options:NSPropertyListImmutable format:NULL error:&error];
        if (fullState) [_audioUnit setFullState:fullState];
        
        if (!fullState || error) {
            self = nil;
            return nil;
        }
    }

    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] postNotificationName:EffectDidDeallocNotification object:nil];
}


#pragma mark - Public Methods

- (void) loadAudioPresetAtFileURL:(NSURL *)fileURL
{
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:fileURL];
    if (!dictionary) return;

    [_audioUnit setFullState:dictionary];
}


- (BOOL) saveAudioPresetAtFileURL:(NSURL *)fileURL
{
    return [[_audioUnit fullState] writeToURL:fileURL atomically:YES];
}


- (void) restoreDefaultValues
{
    [_audioUnit setFullState:_defaultFullState];
}


- (NSDictionary *) stateDictionary
{
    NSDictionary *fullState = [_audioUnit fullState];
    if (!fullState) fullState = [NSDictionary dictionary];
    
    NSError  *error = nil;
    NSString *name  = [_type name];
    NSData   *info  = [NSPropertyListSerialization dataWithPropertyList:fullState format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    
    if (error || !info || !name) return nil;
    
    return @{
        sNameKey: name,
        sInfoKey: info
    };
}


#pragma mark Accessors

- (BOOL) hasCustomView
{
    return [_audioUnit providesUserInterface];
}


- (void) setBypass:(BOOL)bypass
{
    [_audioUnit setShouldBypassEffect:bypass];
}


- (BOOL) bypass
{
    return [_audioUnit shouldBypassEffect];
}

@end

