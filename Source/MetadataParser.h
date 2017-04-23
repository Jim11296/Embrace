//  Copyright (c) 2016-2017 Ricci Adams. All rights reserved.


#import <Foundation/Foundation.h>


@interface MetadataParser : NSObject

- (instancetype) initWithURL:(NSURL *)URL fallbackTitle:(NSString *)fallbackTitle;

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSString *fallbackTitle;
@property (nonatomic, readonly) NSDictionary *metadata;

@end

