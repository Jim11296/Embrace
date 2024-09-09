// (c) 2016-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>


@interface MetadataParser : NSObject

- (instancetype) initWithURL:(NSURL *)URL fallbackTitle:(NSString *)fallbackTitle;

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSString *fallbackTitle;
@property (nonatomic, readonly) NSDictionary *metadata;

@end

