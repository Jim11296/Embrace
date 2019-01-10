// (c) 2018-2019 Ricci Adams.  All rights reserved.

#import <AudioToolbox/AudioToolbox.h>

typedef void (^HugSimpleGraphErrorBlock)(OSStatus err, NSInteger index);

@interface HugSimpleGraph : NSObject

- (instancetype) initWithErrorBlock:(HugSimpleGraphErrorBlock)errorBlock;

- (void) addBlock:(AURenderPullInputBlock)inBlock;
- (void) addAudioUnit:(AUAudioUnit *)unit;

@property (nonatomic, readonly) HugSimpleGraphErrorBlock errorBlock;

@property (nonatomic, readonly) AURenderPullInputBlock renderBlock;

@end

