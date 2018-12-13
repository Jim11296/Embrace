// (c) 2018 Ricci Adams.  All rights reserved.

@class AUAudioUnit;

@interface HugSimpleGraph : NSObject

- (void) addBlock:(AURenderPullInputBlock)inBlock;
- (void) addAudioUnit:(AUAudioUnit *)unit;

@property (nonatomic, readonly) AURenderPullInputBlock renderBlock;

@end

