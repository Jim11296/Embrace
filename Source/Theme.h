//
//  Theme.h
//  Embrace
//
//  Created by Ricci Adams on 2018-06-06.
//  Copyright © 2018 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Track.h"


@interface Theme : NSObject

+ (NSColor *) colorNamed:(NSColorName)colorName;
+ (NSShadow *) shadowNamed:(NSString *)shadowName;

@end


