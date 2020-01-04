// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class Effect;


typedef void (^MappedEffectTypeConfigurator)(AUAudioUnit *unit);

@interface EffectType : NSObject

+ (void) registerMappedTypeWithName: (NSString *) name
          audioComponentDescription: (const AudioComponentDescription *) audioComponentDescription
                       configurator: (MappedEffectTypeConfigurator) configurator;

+ (NSArray *) allEffectTypes;

@property (nonatomic, readonly) NSString *manufacturer;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *fullName;

@property (nonatomic, readonly) AudioComponent AudioComponent;
@property (nonatomic, readonly) AudioComponentDescription AudioComponentDescription;

@property (nonatomic, readonly, getter=isMapped) BOOL mapped;
@property (nonatomic, readonly) MappedEffectTypeConfigurator configurator;

@end
