//
//  EncapsulationsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/05/09.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import "EncapsulationsController.h"


@implementation EncapsulationsController

-(id) newObject
{
  id result = nil;
  NSArray* objects = [self arrangedObjects];
  NSArray* selectedObjects = [self selectedObjects];
  id modelObject = (selectedObjects && [selectedObjects count]) ? [selectedObjects objectAtIndex:0] :
                   (objects && [objects count]) ? [objects objectAtIndex:0] : nil;
  result = !modelObject ? @"" : [modelObject mutableCopy];
  return result;
}
//end newObject

-(void) add:(id)sender
{
  id newObject = [self newObject];
  [self addObject:newObject];
  [self setSelectedObjects:[NSArray arrayWithObjects:newObject, nil]];
  [newObject release];
}
//end add:

@end
