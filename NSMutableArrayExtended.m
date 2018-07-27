//  NSMutableArrayExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 3/05/05.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSMutableArray class

#import "NSMutableArrayExtended.h"

@implementation NSMutableArray (Extended)

-(void) safeAddObject:(id)object
{
  if (object)
    [self addObject:object];
}
//end safeAddObject:

//inserts another array's content at a given index
-(void) insertObjectsFromArray:(NSArray *)array atIndex:(int)index
{
  NSEnumerator* enumerator = [array objectEnumerator];
  NSObject* entry = nil;
  while ((entry = [enumerator nextObject]))
    [self insertObject:entry atIndex:index++];
}
//end insertObjectsFromArray:atIndex:

-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(unsigned int)index
{
  NSArray* objectsToMove = [self objectsAtIndexes:indices];
  NSUInteger shift = 0;
  NSUInteger i = [indices firstIndex];
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
