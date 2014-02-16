//
//  MainButton.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-09.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MainIconView : NSView

- (void) flipToImage:(NSImage *)image tintColor:(NSColor *)tintColor;

@property (nonatomic, strong) NSColor *tintColor;
@property (nonatomic, strong) NSImage *image;

@property (nonatomic, getter=isWiggling) BOOL wiggling;

@end
