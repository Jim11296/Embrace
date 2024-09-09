// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Foundation/Foundation.h>

@class Player, Preferences;

@interface PreferencesController : NSWindowController

- (void) selectPane:(NSInteger)tag animated:(BOOL)animated;

- (IBAction) selectPane:(id)sender;


// For bindings
@property (nonatomic, weak) Preferences *preferences;
@property (nonatomic, weak) Player *player;

@property (nonatomic) BOOL deviceHoggable;
@property (nonatomic) BOOL deviceConnected;

@property (nonatomic) BOOL resetVolumeEnabled;

@end
