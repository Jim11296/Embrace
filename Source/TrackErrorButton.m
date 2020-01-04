// (c) 2014-2020 Ricci Adams.  All rights reserved.

#import "TrackErrorButton.h"
#import "NoDropImageView.h"


@implementation TrackErrorButton


- (id) initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect])) {
        [self _commonTrackErrorButtonInit];
    }

    return self;
}


- (id) initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self _commonTrackErrorButtonInit];
    }

    return self;
}


- (void) _commonTrackErrorButtonInit
{
    [self setButtonType:NSButtonTypeMomentaryChange];
}


- (void) drawRect:(NSRect)dirtyRect
{
    NSImage *image = [NSImage imageNamed:@"TrackErrorTemplate"];

    CGRect bounds = [self bounds];

    NSRect rect = NSZeroRect;
    rect.size = [image size];
    rect.origin.x = 0;
    rect.origin.y = round((bounds.size.height - rect.size.height) / 2);
    
    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    
    if ([self isHighlighted]) {
        [_pressedColor set];
    } else {
        [_normalColor set];
    }

    NSRectFillUsingOperation(bounds, NSCompositingOperationSourceIn);
}


- (void) setNormalColor:(NSColor *)normalColor
{
    if (_normalColor != normalColor) {
        _normalColor = normalColor;
        [self setNeedsDisplay:YES];
    }
}


- (void) setPressedColor:(NSColor *)pressedColor
{
    if (_pressedColor != pressedColor) {
        _pressedColor = pressedColor;
        [self setNeedsDisplay:YES];
    }
}


@end

