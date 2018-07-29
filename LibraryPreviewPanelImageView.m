//
//  LibraryPreviewPanelImageView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/05/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "LibraryPreviewPanelImageView.h"

#import "NSImageExtended.h"

@interface NSImageRep (Bridge10_6)
- (BOOL)drawInRect:(NSRect)dstSpacePortionRect fromRect:(NSRect)srcSpacePortionRect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints;
@end


@implementation LibraryPreviewPanelImageView

-(void) setBackgroundColor:(NSColor*)color
{
  self->backgroundColor = color;
}
//end setBackgroundColor:

-(NSColor*) backgroundColor
{
  return self->backgroundColor;
}
//end backgroundColor

-(void) drawRect:(NSRect)rect
{
  NSImage* image = [self image];
  //[image setBackgroundColor:[NSColor clearColor]];
  [image setBackgroundColor:self->backgroundColor];
  NSSize size = image ? [image size] : NSZeroSize;
  NSRect bounds = [self bounds];
  NSRect reducedBounds = NSMakeRect(bounds.origin.x+5, bounds.origin.y+5, bounds.size.width-10, bounds.size.height-10);
  [self setImage:nil];
  [super drawRect:rect];
  if (self->backgroundColor)
  {
    [self->backgroundColor set];
    NSRectFill(reducedBounds);
  }
  if (![[NSImageRep class] instancesRespondToSelector:@selector(drawInRect:fromRect:operation:fraction:respectFlipped:hints:)])
    [image drawInRect:reducedBounds fromRect:NSMakeRect(0, 0, size.width, size.height) operation:NSCompositeSourceOver fraction:1.0];
  else
    [[image bestImageRepresentationInContext:[NSGraphicsContext currentContext]] drawInRect:reducedBounds fromRect:NSMakeRect(0, 0, size.width, size.height) operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
  [self setImage:image];
}
//end drawRect:

@end
