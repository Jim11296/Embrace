//
//  BorderedView.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-07.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TrackLabelViewStyle) {
    TrackLabelViewStripe,
    TrackLabelViewDot
};

@interface TrackLabelView : NSView

@property (nonatomic) TrackLabelViewStyle style;
@property (nonatomic) TrackLabel label;
@property (nonatomic) BOOL needsWhiteBorder;

@end
