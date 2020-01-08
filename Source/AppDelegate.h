// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import <Cocoa/Cocoa.h>

@protocol WorkerProtocol;

@class EditEffectController, ViewTrackController, Effect;
@class SetlistController, Track;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (id<WorkerProtocol>) workerProxyWithErrorHandler:(void (^)(NSError *error))handler;

- (void) performPreferredPlaybackAction;

- (void) displayErrorForTrack:(Track *)track;

- (void) showEffectsWindow;
- (void) showCurrentTrack;
- (void) showPreferences;
- (void) showMusicLocations;

@property (nonatomic, readonly) SetlistController *setlistController;

- (EditEffectController *) editControllerForEffect:(Effect *)effect;
- (void) closeEditControllerForEffect:(Effect *)effect;

- (ViewTrackController *) viewTrackControllerForTrack:(Track *)track;
- (void) closeViewTrackControllerForEffect:(Track *)track;


@end
