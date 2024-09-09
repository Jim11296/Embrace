// (c) 2015-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "EffectType.h"

extern NSString * const EmbraceMappedEffect10BandEQ;
extern NSString * const EmbraceMappedEffect31BandEQ;


@interface EffectType (EmbraceAdditions)

+ (void) embrace_registerMappedEffects;

- (NSString *) friendlyName;

@end
