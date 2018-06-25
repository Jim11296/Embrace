// (c) 2014-2018 Ricci Adams.  All rights reserved.

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
