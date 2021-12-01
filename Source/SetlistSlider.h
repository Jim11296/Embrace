// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@protocol SetlistSliderDragDelegate;


@interface SetlistSlider : NSSlider <EmbraceWindowListener>

@property (nonatomic, weak) id<SetlistSliderDragDelegate> dragDelegate;
@property (readonly) NSRect knobRect;

@end


@interface SetlistSliderCell : NSSliderCell

@end


@protocol SetlistSliderDragDelegate <NSObject>
- (void) sliderDidStartDrag:(SetlistSlider *)slider;
- (void) sliderDidEndDrag:(SetlistSlider *)slider;
@end
