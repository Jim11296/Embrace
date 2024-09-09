// (c) 2018-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

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
