//
//  ButtonNotClickThrough.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 07/08/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import "ButtonNotClickThrough.h"


@implementation ButtonNotClickThrough

//a non-click-thoughable button does not accept mouse events unless its window is already key window
-(BOOL) acceptsFirstMouse:(NSEvent*)theEvent
{
  return NO;
}

@end
