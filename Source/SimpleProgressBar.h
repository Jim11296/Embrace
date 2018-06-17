//
//  SimpleProgressBar.h
//  Embrace
//
//  Created by Ricci Adams on 2017-06-25.
//  Copyright (c) 2017 Ricci Adams. All rights reserved.
//

@interface SimpleProgressBar : NSView <EmbraceWindowListener>

@property (nonatomic) CGFloat percentage;

@property (nonatomic, getter=isRounded) BOOL rounded;

@end
