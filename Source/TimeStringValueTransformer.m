//
//  TimeStringValueTransformer.m
//  Embrace
//
//  Created by Ricci Adams on 2014-01-15.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import "TimeStringValueTransformer.h"

@implementation TimeStringValueTransformer

+ (Class) transformedValueClass
{
    return [NSString class];
}

+ (BOOL) allowsReverseTransformation
{
    return NO;
}

- (id) transformedValue:(id)value
{
    return GetStringForTime([value doubleValue]);
}


@end
