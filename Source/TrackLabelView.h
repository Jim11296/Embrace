// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>
#import "Track.h"


typedef NS_ENUM(NSInteger, TrackLabelViewStyle) {
    TrackLabelViewEdge,
    TrackLabelViewDot
};

@interface TrackLabelView : NSView

@property (nonatomic) TrackLabelViewStyle style;
@property (nonatomic) TrackLabel label;
@property (nonatomic) BOOL needsWhiteBorder;

@end
