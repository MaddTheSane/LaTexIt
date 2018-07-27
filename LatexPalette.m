//  LatexPalette.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

// Since the palette is in its own NIB file (to accelerate start up by lazily loading it),
// the simplest way to tune it a little was a subclassing

#import "LatexPalette.h"

@implementation LatexPalette

-(id) initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask
                  backing:(NSBackingStoreType)backingType defer:(BOOL)flag
{
  self = [super initWithContentRect:contentRect styleMask:styleMask backing:backingType defer:flag];
  if (self)
  {
    [self setFloatingPanel:YES];
  }
  return self;
}

@end
