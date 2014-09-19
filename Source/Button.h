//
//  MainButton.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Button : NSButton <MainWindowListener>

- (void) performOpenAnimationToImage:(NSImage *)image enabled:(BOOL)enabled;

- (void) performPopAnimation:(BOOL)isPopIn toImage:(NSImage *)image alert:(BOOL)alert;

@property (nonatomic, getter=isAlert) BOOL alert;

@property (nonatomic, strong) NSColor *normalColor;
@property (nonatomic, strong) NSColor *activeColor;
@property (nonatomic, strong) NSColor *inactiveColor;
@property (nonatomic, strong) NSColor *disabledColor;

@property (nonatomic, strong) NSColor *alertColor;
@property (nonatomic, strong) NSColor *alertActiveColor;

@property (nonatomic, assign, getter=isWiggling) BOOL wiggling;

@end
