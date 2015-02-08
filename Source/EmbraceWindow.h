//
//  EmbraceWindow
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CloseButton, BorderedView;

@protocol MainWindowListener <NSObject>
- (void) windowDidUpdateMain:(NSWindow *)window;
@end

@interface EmbraceWindow : NSWindow

- (void) setupWithHeaderView: (BorderedView *) headerView
                    mainView: (NSView *) mainView
                  footerView: (BorderedView *) footerView;

- (void) setupAsParentWindow;

@property (nonatomic, readonly) NSArray *mainListeners;
- (void) addMainListener:(id<MainWindowListener>)listener;

@property (nonatomic, strong, readonly) CloseButton *closeButton;

@end

@protocol EmbraceWindowDelegate <NSObject>
@optional
- (BOOL) window:(EmbraceWindow *)window cancelOperation:(id)sender;
@end
