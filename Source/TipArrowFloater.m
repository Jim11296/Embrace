// (c) 2016-2019 Ricci Adams.  All rights reserved.

#import "TipArrowFloater.h"


@implementation TipArrowFloater {
    NSView *_arrowView;
}


- (void) showWithView:(NSView *)view rect:(NSRect)rect
{
    [self hide];
    
    if (![view window]) return;

    NSView *contentView = [[view window] contentView];

    CGRect rectInBase = [view convertRect:rect toView:contentView];
    
    CGSize arrowSize  = CGSizeMake(27, 31);
        
    CGRect arrowFrame = CGRectMake(
        rectInBase.origin.x + round((rectInBase.size.width - arrowSize.width) / 2),
        rectInBase.origin.y - (arrowSize.height + 2),
        arrowSize.width,
        arrowSize.height + 4
    );
    
    NSImageView *arrowView = [[NSImageView alloc] initWithFrame:arrowFrame];
    [arrowView setImage:[NSImage imageNamed:@"TipArrow"]];
    [arrowView setAutoresizingMask:NSViewWidthSizable|NSViewWidthSizable];
    [arrowView setImageScaling:NSImageScaleNone];
    [arrowView setImageAlignment:NSImageAlignBottom];
    [arrowView setWantsLayer:YES];

    CALayer *layer = [arrowView layer];
    
    CABasicAnimation *transformAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
    [transformAnimation setDuration:0.5];
    [transformAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    [transformAnimation setFromValue:[NSValue valueWithCATransform3D:CATransform3DIdentity]];
    [transformAnimation setToValue:  [NSValue valueWithCATransform3D:CATransform3DMakeTranslation(0, 4, 0)]];
    [transformAnimation setAutoreverses:YES];
    [transformAnimation setRepeatCount:HUGE_VALF];

    CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [opacityAnimation setDuration:0.5];
    [opacityAnimation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [opacityAnimation setFromValue:@(0.0)];
    [opacityAnimation setToValue:  @(1.0)];

    [layer addAnimation:transformAnimation forKey:@"transform"];
    [layer addAnimation:opacityAnimation forKey:@"opacity"];

    
    [[[view window] contentView] addSubview:arrowView];
    
    _arrowView = arrowView;
}


- (void) hide
{
    NSView *arrowView = _arrowView;
    _arrowView = nil;

    if (!arrowView) return;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [animation setDuration:0.5];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [animation setToValue:@(0.0)];
    [animation setDelegate:self];
    [animation setFillMode:kCAFillModeForwards];
    [animation setRemovedOnCompletion:NO];

    [[arrowView layer] addAnimation:animation forKey:@"opacity"];

    [arrowView performSelector:@selector(removeFromSuperview) withObject:nil afterDelay:0.5];
}


@end
