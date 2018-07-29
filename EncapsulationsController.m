//
//  EncapsulationsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/05/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "EncapsulationsController.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation EncapsulationsController

-(id) newObject
{
  id result = nil;
  NSArray* objects = self.arrangedObjects;
  NSArray* selectedObjects = self.selectedObjects;
  id modelObject = (selectedObjects && selectedObjects.count) ? selectedObjects[0] :
                   (objects && objects.count) ? objects[0] : nil;
  result = !modelObject ? @"" : [modelObject mutableCopy];
  return result;
}
//end newObject

-(void) add:(id)sender
{
  id newObject = [self newObject];
  [self addObject:newObject];
  [self setSelectedObjects:@[newObject]];
}
//end add:

@end
