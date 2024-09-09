// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

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
