//
//  NSArrayControllerExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/05/09.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.
//

#import "NSArrayControllerExtended.h"


@implementation NSArrayController (Extended)

-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(unsigned int)index
{
  NSArray* objectsToMove = [[self arrangedObjects] objectsAtIndexes:indices];
  NSUInteger shift = 0;
  NSUInteger i = [indices firstIndex];
  while((i != NSNotFound) && i<index)
  {
    ++shift;
    i = [indices indexGreaterThanIndex:i];
  }
  NSArray* selectedObjects = ![self preservesSelection] ? nil : [self selectedObjects];
  [self removeObjectsAtArrangedObjectIndexes:indices];
  [self insertObjects:objectsToMove atArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index-shift, [objectsToMove count])]];
  if (selectedObjects)
    [self setSelectedObjects:selectedObjects];
}
//end moveObjectsAtIndices:toIndex:

@end
