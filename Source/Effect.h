// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

extern NSString * const EffectDidDeallocNotification;

@class EffectType;
@class EffectSettingsController;

@interface Effect : NSObject

+ (instancetype) effectWithStateDictionary:(NSDictionary *)dictionary;
- (id) initWithStateDictionary:(NSDictionary *)dictionary;

+ (instancetype) effectWithEffectType:(EffectType *)effectType;
- (id) initWithEffectType:(EffectType *)effectType;

- (void) loadAudioPresetAtFileURL:(NSURL *)fileURL;
- (BOOL) saveAudioPresetAtFileURL:(NSURL *)fileURL;
- (void) restoreDefaultValues;

- (NSDictionary *) stateDictionary;

@property (nonatomic) AUAudioUnit *audioUnit;
@property (nonatomic) NSError *audioUnitError;

@property (nonatomic, readonly) EffectType *type;
@property (nonatomic, readonly) BOOL hasCustomView;
@property (nonatomic) BOOL bypass;

@end
