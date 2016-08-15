//
//  WhiteSlider.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WhiteSliderDragDelegate;

@interface WhiteSlider : NSSlider <EmbraceWindowListener>

@property (nonatomic, weak) id<WhiteSliderDragDelegate> dragDelegate;
@property (nonatomic) double doubleValueBeforeDrag;

@property (readonly) NSRect knobRect;

@end

@interface WhiteSliderCell : NSSliderCell

@end


@protocol WhiteSliderDragDelegate <NSObject>
- (void) whiteSliderDidStartDrag:(WhiteSlider *)slider;
- (void) whiteSliderDidEndDrag:(WhiteSlider *)slider;
@end
