//
//  MainWindow.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CloseButton;

@interface WhiteWindow : NSWindow

- (void) setupWithHeaderView:(NSView *)contentView mainView:(NSView *)mainView;
- (void) setupAsParentWindow;

@property (nonatomic, strong) NSArray *hiddenViewsWhenInactive;
@property (nonatomic, strong, readonly) CloseButton *closeButton;

@end

@protocol WhiteWindowDelegate <NSObject>
@optional
- (BOOL) window:(WhiteWindow *)window cancelOperation:(id)sender;
@end
