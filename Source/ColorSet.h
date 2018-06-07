//
//  Color.h
//  Embrace
//
//  Created by Ricci Adams on 2018-06-06.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface ColorSet : NSColor

- (void) addColor:(NSColor *)color forAppearanceName:(NSAppearanceName)appearanceName;

@end

