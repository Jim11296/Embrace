//
//  EffectAdditions.h
//  Embrace
//
//  Created by Ricci Adams on 2015-07-12.
//  Copyright (c) 2015 Ricci Adams. All rights reserved.
//

#import "EffectType.h"

extern NSString * const EmbraceMappedEffect10BandEQ;
extern NSString * const EmbraceMappedEffect31BandEQ;


@interface EffectType (EmbraceAdditions)

+ (void) embrace_registerMappedEffects;

- (NSString *) friendlyName;

@end
