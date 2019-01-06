//
//  HugCallbackHelper.h
//  Embrace
//
//  Created by Ricci Adams on 2018-11-29.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HugSimpleAudioGraph : NSObject

- (void) clear;

- (void) addBlock:(AURenderPullInputBlock)pullBlock;
- (void) addAudioUnit:(AudioUnit)unit;
- (void) addAUAudioUnit:(AUAudioUnit *)unit;

@property (nonatomic, copy) AURenderPullInputBlock masterBlock;

@end
