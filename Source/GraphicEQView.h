// (c) 2015-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

@class AUAudioUnit;

@interface GraphicEQView : NSView

- (void) flatten;

- (void) reloadData;

@property (nonatomic) AUAudioUnit *audioUnit;
@property (nonatomic, readonly) NSInteger numberOfBands;

@end
