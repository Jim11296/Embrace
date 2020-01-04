// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@class Effect;

@interface EditEffectController : NSWindowController

- (id) initWithEffect:(Effect *)effect index:(NSInteger)index;

@property (nonatomic, weak) Effect *effect;

- (IBAction) loadPreset:(id)sender;
- (IBAction) savePreset:(id)sender;
- (IBAction) restoreDefaultValues:(id)sender;
- (IBAction) toggleBypass:(id)sender;

@end
