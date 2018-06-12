//
//  GradientView.h
//  Embrace
//
//  Created by Ricci Adams on 2016-12-10.
//  (c) 2016-2017 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MaskView : NSView
                   
// Either NSLayoutAttributeLeft or NSLayoutAttributeRight
@property (nonatomic) NSLayoutAttribute gradientLayoutAttribute;
@property (nonatomic) CGFloat gradientLength;

// If material is non-zero, an NSVisualEffectView is used.
@property (nonatomic) NSVisualEffectMaterial material;
@property (nonatomic, getter=isEmphasized) BOOL emphasized;
@property (nonatomic) NSColor *color;

@end
