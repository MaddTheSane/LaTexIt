//
//  ImagePopupButton.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "ImagePopupButton.h"


@implementation ImagePopupButton

-(void) awakeFromNib
{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_menuDidEndTrackingNotification:)
                                               name:NSMenuDidEndTrackingNotification object:[self menu]];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(void) setImage:(NSImage*)anImage
{
  [anImage retain];
  [image release];
  image = anImage;
}

-(NSImage*) image
{
  return image;
}

-(void) _menuDidEndTrackingNotification:(NSNotification*)notification
{
  //registered only for [self menu]
  isDown = NO;
  [self setNeedsDisplay:YES];
}

-(void)mouseDown:(NSEvent*)event
{
  isDown = YES;
  [self setNeedsDisplay:YES];
  [super mouseDown:event];
}


-(BOOL) isFlipped
{
  return NO;
}

-(void) drawRect:(NSRect)aRect
{
  [super drawRect:aRect];
  NSImage* imageToDisplay = isDown ? [self alternateImage] : [self image];
  NSSize size = [imageToDisplay size];
  [imageToDisplay drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, size.width, size.height) operation:NSCompositeSourceOver fraction:1.0];
}

@end
