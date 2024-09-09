// (c) 2016-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>

@interface TipArrowFloater : NSObject <CAAnimationDelegate>

- (void) showWithView:(NSView *)view rect:(NSRect)rect;
- (void) hide;


@end
