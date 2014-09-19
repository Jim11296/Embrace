//
//  MainWindow.h
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

@interface WhiteWindow : NSWindow

- (void) setupWithHeaderView:(BorderedView *)headerView mainView:(NSView *)mainView;
- (void) setupAsParentWindow;

@property (nonatomic, readonly) NSArray *mainListeners;
- (void) addMainListener:(id<MainWindowListener>)listener;

@property (nonatomic, strong, readonly) CloseButton *closeButton;

@end

@protocol WhiteWindowDelegate <NSObject>
@optional
- (BOOL) window:(WhiteWindow *)window cancelOperation:(id)sender;
@end
