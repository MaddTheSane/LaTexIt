//
//  ButtonNotClickThrough.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 07/08/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "ButtonNotClickThrough.h"


@implementation ButtonNotClickThrough

//a non-click-thoughable button does not accept mouse events unless its window is already key window
-(BOOL) acceptsFirstMouse:(NSEvent*)theEvent
{
  return NO;
}

@end
