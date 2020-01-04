// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "EffectType.h"

static NSMutableArray *sMappedEffectTypes = nil;

@implementation EffectType {
    AudioComponent _component;
    AudioComponentDescription _componentDescription;
}

@synthesize AudioComponent = _component;
@synthesize AudioComponentDescription = _componentDescription;


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


+ (void) registerMappedTypeWithName: (NSString *) name
          audioComponentDescription: (const AudioComponentDescription *) audioComponentDescription
                       configurator: (MappedEffectTypeConfigurator) configurator
{
    if (!sMappedEffectTypes) {
        sMappedEffectTypes = [NSMutableArray array];
    }

    EffectType *effectType = [[self alloc] _initAsMappedWithName:name audioComponentDescription:audioComponentDescription configurator:configurator];
    if (effectType) [sMappedEffectTypes addObject:effectType];
}

+ (NSArray *) allEffectTypes
{
    static NSArray *sBuiltInEffectTypes = nil;
    
    void (^gather)(NSMutableArray *, OSType) = ^(NSMutableArray *array, OSType componentType) { 
        AudioComponentDescription description;

        description.componentType = componentType;
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
        
        [array addObjectsFromArray:types];
    };

    if (!sBuiltInEffectTypes) {
        NSMutableArray *array = [NSMutableArray array];

        gather(array, kAudioUnitType_Effect);
        gather(array, kAudioUnitType_MusicEffect);
        
        sBuiltInEffectTypes = array;
    }
    
    NSMutableArray *result = [NSMutableArray array];
    
    if (sMappedEffectTypes)  [result addObjectsFromArray:sMappedEffectTypes];
    if (sBuiltInEffectTypes) [result addObjectsFromArray:sBuiltInEffectTypes];
    
    return result;
}


- (id) _initAsMappedWithName:(NSString *)name audioComponentDescription:(const AudioComponentDescription *)acd configurator:(MappedEffectTypeConfigurator)configurator
{
    if ((self = [super init])) {
        _manufacturer = nil;
        _componentDescription = *acd;
        _component = AudioComponentFindNext(NULL, &_componentDescription);
        _name = _fullName = name;
        
        if (!_component) {
            self = nil;
            return nil;
        }

        _mapped = YES;
        _configurator = configurator;
    }
    
    return self;
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


@end
