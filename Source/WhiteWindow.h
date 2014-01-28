//
//  MainWindow.h
//  Embrace
//
//  Created by Ricci Adams on 2014-01-04.
//  Copyright (c) 2014 Ricci Adams. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WhiteWindow : NSWindow

- (void) setupWithHeaderView:(NSView *)contentView mainView:(NSView *)mainView;
- (void) setupAsParentWindow;

@end
