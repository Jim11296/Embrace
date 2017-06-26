//
//  SimpleProgressBar.h
//  Embrace
//
//  Created by Ricci Adams on 2017-06-25.
//  Copyright (c) 2017 Ricci Adams. All rights reserved.
//

@interface SimpleProgressBar : NSView

@property (nonatomic) NSColor *inactiveColor;
@property (nonatomic) NSColor *activeColor;
@property (nonatomic) NSColor *tintColor;

@property (nonatomic) CGFloat percentage;
@property (nonatomic) CGFloat tintLevel;

@end
