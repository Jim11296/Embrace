// (c) 2014-2018 Ricci Adams.  All rights reserved.

#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, SetlistButtonIcon) {
    SetlistButtonIconNone        = 0,
    SetlistButtonIconPlay        = 1,
    SetlistButtonIconStop        = 2,
    SetlistButtonIconReallyStop  = 3,
    SetlistButtonIconDeviceIssue = 4,
    SetlistButtonIconGear        = 5,
};


@interface SetlistButton : NSButton <EmbraceWindowListener>

- (void) setImage:(NSImage *)image NS_UNAVAILABLE; // Use setIcon:

- (void) setIcon:(SetlistButtonIcon)icon animated:(BOOL)animated;
@property (nonatomic) SetlistButtonIcon icon;

@property (nonatomic, assign, getter=isOutlined) BOOL outlined;

@end
