//
//  LibraryPreviewPanelImageView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/05/06.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import "LibraryPreviewPanelImageView.h"

#import "NSImageExtended.h"
#import "NSObjectExtended.h"


@implementation LibraryPreviewPanelImageView

-(void) dealloc
{
  [self->backgroundColor release];
  [super dealloc];
}
//end dealloc

@synthesize backgroundColor;

-(void) drawRect:(NSRect)rect
{
  NSRect bounds = [self bounds];

  if ([self isDarkMode])
  {
//    CGFloat gray[4] = {0.5f, 0.5f, 0.5f, 1.f};
    [[NSColor colorWithCalibratedWhite:0.5 alpha:1.0] set];
//    [[NSColor colorWithCalibratedRed:gray[0] green:gray[1] blue:gray[2] alpha:gray[3]] set];
    NSRectFill(bounds);
  }//end if ([self isDarkMode])

  NSImage* image = [[self image] retain];
  //[image setBackgroundColor:[NSColor clearColor]];
  [image setBackgroundColor:self->backgroundColor];

  NSSize size = image ? [image size] : NSZeroSize;
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
  [image release];
}
//end drawRect:

@end
