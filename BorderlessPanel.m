//
//  BorderlessPanel.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "BorderlessPanel.h"


@implementation BorderlessPanel

-(id) initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)deferCreation
{
  if ((!(self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:bufferingType defer:deferCreation])))
    return nil;
  return self;
}
//end initWithContentRect:styleMask:backing:defer:

@end
