// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import <Foundation/Foundation.h>

@class EmbraceWindow;


@protocol EmbraceWindowListener <NSObject>
- (void) windowDidUpdateMain:(NSWindow *)window;
@end


@protocol EmbraceWindowDelegate <NSWindowDelegate>
@optional
- (BOOL) window:(EmbraceWindow *)window cancelOperation:(id)sender;
@end


@interface EmbraceWindow : NSWindow

@property (nonatomic, readonly) NSArray *listeners;
- (void) addListener:(id<EmbraceWindowListener>)listener;

@property (atomic, assign) id<EmbraceWindowDelegate> delegate;
@end
