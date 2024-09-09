// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import <Cocoa/Cocoa.h>

@protocol WorkerProtocol;

@class EditEffectController, Effect;
@class SetlistController, Track;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (id<WorkerProtocol>) workerProxyWithErrorHandler:(void (^)(NSError *error))handler;

- (void) performPreferredPlaybackAction;

- (void) displayErrorForTrack:(Track *)track;

- (void) showEffectsWindow;
- (void) showCurrentTrack;
- (void) showPreferences;

@property (nonatomic, readonly) SetlistController *setlistController;

- (EditEffectController *) editControllerForEffect:(Effect *)effect;
- (void) closeEditControllerForEffect:(Effect *)effect;

@end
