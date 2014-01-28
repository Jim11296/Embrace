//
//  Component.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-03.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Effect;

@interface EffectType : NSObject

+ (NSArray *) allEffectTypes;

@property (nonatomic, readonly) NSString *manufacturer;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *fullName;

@property (nonatomic, readonly) AudioComponent AudioComponent;
@property (nonatomic, readonly) AudioComponentDescription AudioComponentDescription;

@end
