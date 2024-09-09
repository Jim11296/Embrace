// (c) 2014-2024 Ricci Adams
// MIT License (or) 1-clause BSD License

#import "NoDropImageView.h"

@implementation NoDropImageView

- (id) initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self unregisterDraggedTypes];
    }
    
    return self;
}



- (void) drawRect:(NSRect)dirtyRect
{
    if (!_tintColor) {
        [super drawRect:dirtyRect];
        return;
    }

    NSImage *image = [self image];
    NSSize size = [image size];
    NSRect rect = NSZeroRect;
    rect.size = size;

    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];

    
    [_tintColor set];
    NSRectFillUsingOperation(rect, NSCompositingOperationSourceIn);
}


- (void) setTintColor:(NSColor *)tintColor
{
    if (_tintColor != tintColor) {
        _tintColor = tintColor;
        [self setNeedsDisplay:YES];
    }
}

@end
