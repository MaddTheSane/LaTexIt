//  NSMutableArrayExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 3/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSMutableArray class

#import "NSMutableArrayExtended.h"

@implementation NSMutableArray (Extended)

//inserts another array's content at a given index
-(void) insertObjectsFromArray:(NSArray *)array atIndex:(int)index
{
  NSEnumerator* enumerator = [array objectEnumerator];
  NSObject* entry = [enumerator nextObject];
  while (entry)
  {
    [self insertObject:entry atIndex:index++];
    entry = [enumerator nextObject];
  }
}

//checks if indexOfObjectIdenticalTo returns a valid index
-(BOOL) containsObjectIdenticalTo:(id)object
{ 
  return ([self indexOfObjectIdenticalTo:object] != NSNotFound);
}

//this method does exist in Tiger
#ifdef PANTHER
-(void) removeObjectsAtIndexes:(NSIndexSet *)indexes
{
  unsigned int index = [indexes lastIndex];
  while(index != NSNotFound)
  {
    [self removeObjectAtIndex:index];
    index = [indexes indexLessThanIndex:index];
  }
}
#endif

-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(unsigned int)index
{
  NSArray* objectsToMove = [self objectsAtIndexes:indices];
  unsigned int shift = 0;
  unsigned int i = [indices firstIndex];
  while((i != NSNotFound) && i<index)
  {
    ++shift;
    i = [indices indexGreaterThanIndex:i];
  }
  [self removeObjectsAtIndexes:indices];
  [self insertObjects:objectsToMove atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index-shift, [objectsToMove count])]];
}
//end moveObjectsAtIndices:toIndex:

@end
