// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@protocol EmbraceSliderDragDelegate;


@interface EmbraceSlider : NSSlider <EmbraceWindowListener>

+ (void) drawKnobWithView:(NSView *)view rect:(CGRect)rect highlighted:(BOOL)highlighted;

@property (nonatomic, weak) id<EmbraceSliderDragDelegate> dragDelegate;
@property (readonly) NSRect knobRect;

@end


@interface EmbraceSliderCell : NSSliderCell

@end


@protocol EmbraceSliderDragDelegate <NSObject>
- (void) sliderDidStartDrag:(EmbraceSlider *)slider;
- (void) sliderDidEndDrag:(EmbraceSlider *)slider;
@end
