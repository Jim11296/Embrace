// (c) 2014-2019 Ricci Adams.  All rights reserved.

#import "EmbraceWindow.h"


@implementation EmbraceWindow {
    NSHashTable *_listeners;
}

@dynamic delegate;

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) cancelOperation:(id)sender
{
    if ([[self delegate] respondsToSelector:@selector(window:cancelOperation:)]) {
        BOOL result = [(id)[self delegate] window:self cancelOperation:sender];
        if (result) return;
    }

    [super cancelOperation:sender];
}


- (void) _updateMain:(NSNotification *)note
{
    for (id<EmbraceWindowListener> listener in _listeners) {
        [listener windowDidUpdateMain:self];
    }
}


- (void) addListener:(id<EmbraceWindowListener>)listener
{
    if (!_listeners) {
        _listeners = [NSHashTable weakObjectsHashTable];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateMain:) name:NSWindowDidBecomeMainNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateMain:) name:NSWindowDidResignMainNotification object:nil];
    }
    
    [_listeners addObject:listener];
    [listener windowDidUpdateMain:self];
}


- (NSArray *) listeners
{
    return [_listeners allObjects];
}




@end
