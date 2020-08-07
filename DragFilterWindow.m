//
//  DragFilterWindow.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/10.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "DragFilterWindow.h"

@implementation DragFilterWindow

-(id) initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
  windowStyle = NSBorderlessWindowMask;
  if (!(self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation]))
    return nil;
  [self setBackgroundColor:[NSColor clearColor]];
  [self setLevel:NSFloatingWindowLevel];
  return self;
}
//end initWithContentRect:styleMask:backing:defer

-(id) initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation screen:(NSScreen*)screen
{
  windowStyle = NSBorderlessWindowMask;
  if (!(self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation screen:screen]))
    return nil;
  [self setBackgroundColor:[NSColor clearColor]];
  [self setLevel:NSFloatingWindowLevel];
  return self;
}
//end initWithContentRect:styleMask:backing:defer:screen:

-(BOOL) isOpaque
{
  return NO;
}
//end isOpaque

@end
