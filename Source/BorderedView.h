//
//  BorderedView.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-07.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BorderedView : NSView

@property (nonatomic) NSColor *backgroundColor;

@property (nonatomic) NSColor *topBorderColor;
@property (nonatomic) CGFloat  topBorderHeight;
@property (nonatomic) NSColor *topDashBackgroundColor;

@property (nonatomic) NSColor *bottomBorderColor;
@property (nonatomic) CGFloat  bottomBorderHeight;
@property (nonatomic) NSColor *bottomDashBackgroundColor;

@end
