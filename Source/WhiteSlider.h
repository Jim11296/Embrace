// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@protocol WhiteSliderDragDelegate;


@interface WhiteSlider : NSSlider <EmbraceWindowListener>

+ (void) drawKnobWithView:(NSView *)view rect:(CGRect)rect highlighted:(BOOL)highlighted;

@property (nonatomic, weak) id<WhiteSliderDragDelegate> dragDelegate;
@property (readonly) NSRect knobRect;

@end


@interface WhiteSliderCell : NSSliderCell

@end


@protocol WhiteSliderDragDelegate <NSObject>
- (void) whiteSliderDidStartDrag:(WhiteSlider *)slider;
- (void) whiteSliderDidEndDrag:(WhiteSlider *)slider;
@end
