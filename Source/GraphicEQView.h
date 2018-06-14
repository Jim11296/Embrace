//
//  GraphicEQView.h
//  EQView
//
//  Created by Ricci Adams on 2015-07-09.
//  Copyright (c) 2015 Ricci Adams. All rights reserved.
//

@interface GraphicEQView : NSView

- (void) flatten;

- (void) reloadData;

@property (nonatomic) AudioUnit audioUnit;
@property (nonatomic, readonly) NSInteger numberOfBands;

@end
