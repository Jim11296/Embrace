//
//  MainButton.h
//  Terpsichore
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Button : NSButton

@property (nonatomic, strong) NSColor *normalColor;
@property (nonatomic, strong) NSColor *activeColor;
@property (nonatomic, strong) NSColor *inactiveColor;
@property (nonatomic, strong) NSColor *disabledColor;

@end
