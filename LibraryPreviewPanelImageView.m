//
//  LibraryPreviewPanelImageView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/05/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "LibraryPreviewPanelImageView.h"

@implementation LibraryPreviewPanelImageView

-(void) dealloc
{
  [self->backgroundColor release];
  [super dealloc];
}
//end dealloc

-(void) setBackgroundColor:(NSColor*)color
{
  [color retain];
  [self->backgroundColor release];
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
  NSImage* image = [[self image] retain];
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
  [image drawInRect:reducedBounds fromRect:NSMakeRect(0, 0, size.width, size.height) operation:NSCompositeSourceOver fraction:1.0];
  [self setImage:image];
  [image release];
}
//end drawRect:

@end
