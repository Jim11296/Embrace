//
//  Effect.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const EffectDidDeallocNotification;

@class EffectType;
@class EffectSettingsController;

@interface Effect : NSObject

+ (instancetype) effectWithStateDictionary:(NSDictionary *)dictionary;
- (id) initWithStateDictionary:(NSDictionary *)dictionary;

+ (instancetype) effectWithEffectType:(EffectType *)effectType;
- (id) initWithEffectType:(EffectType *)effectType;

- (void) loadDefaultValues;
- (BOOL) loadAudioPresetAtFileURL:(NSURL *)fileURL;

- (NSDictionary *) stateDictionary;

- (AudioUnit) audioUnit;

@property (nonatomic, readonly) EffectType *type;
@property (nonatomic, readonly) BOOL hasCustomView;
@property (nonatomic) BOOL bypass;

@end
