// (c) 2015-2018 Ricci Adams.  All rights reserved.

@interface GraphicEQView : NSView

- (void) flatten;

- (void) reloadData;

@property (nonatomic) AudioUnit audioUnit;
@property (nonatomic, readonly) NSInteger numberOfBands;

@end
