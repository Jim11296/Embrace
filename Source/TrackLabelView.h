// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, TrackLabelViewStyle) {
    TrackLabelViewEdge,
    TrackLabelViewDot
};

@interface TrackLabelView : NSView

@property (nonatomic) TrackLabelViewStyle style;
@property (nonatomic) TrackLabel label;
@property (nonatomic) BOOL needsWhiteBorder;

@end
