// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

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
