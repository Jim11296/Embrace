// (c) 2015-2019 Ricci Adams.  All rights reserved.

@class AUAudioUnit;

@interface GraphicEQView : NSView

- (void) flatten;

- (void) reloadData;

@property (nonatomic) AUAudioUnit *audioUnit;
@property (nonatomic, readonly) NSInteger numberOfBands;

@end
