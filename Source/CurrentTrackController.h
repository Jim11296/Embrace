// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

@class WaveformView, Player;

@interface CurrentTrackController : NSWindowController <NSMenuDelegate>

@property (nonatomic, weak) Player *player;

@end
