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
@property (nonatomic) CGFloat topBorderHeight;
@property (nonatomic) CGFloat topBorderLeftInset;
@property (nonatomic) CGFloat topBorderRightInset;

@property (nonatomic) NSColor *bottomBorderColor;
@property (nonatomic) CGFloat bottomBorderHeight;
@property (nonatomic) CGFloat bottomBorderLeftInset;
@property (nonatomic) CGFloat bottomBorderRightInset;

@property (nonatomic) BOOL usesDashes;

@end
