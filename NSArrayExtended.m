//  NSArrayExtended.m
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import "NSArrayExtended.h"
#import "NSMutableArrayExtended.h"

@implementation NSArray (Extended)

//returns a copy of the receiver in the reversed order
-(NSArray*) reversed
{
  NSMutableArray* reversed = [NSMutableArray arrayWithCapacity:[self count]];
  NSEnumerator* enumerator = [self reverseObjectEnumerator];
  id object = [enumerator nextObject];
  while(object)
  {
    [reversed addObject:object];
    object = [enumerator nextObject];
  }
  return reversed;
}

#ifdef PANTHER
-(NSArray*) objectsAtIndexes:(NSIndexSet *)indexes //does exist in Tiger
{
  NSMutableArray* subArray = [NSMutableArray arrayWithCapacity:[indexes count]];
  unsigned int index = [indexes firstIndex];
  while(index != NSNotFound)
  {
    [subArray addObject:[self objectAtIndex:index]];
    index = [indexes indexGreaterThanIndex:index];
  }
  return subArray;
}
#endif

-(NSArray*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(unsigned int)index
{
  NSMutableArray* array = [[self mutableCopy] autorelease];
  [array moveObjectsAtIndices:indices toIndex:index];
  return array;
}
//end arrayByMovingObjectsAtIndices:toIndex:

-(id) deepCopy {return [self deepCopyWithZone:nil];}
-(id) deepCopyWithZone:(NSZone*)zone
{
  NSMutableArray* clone = [[NSMutableArray allocWithZone:zone] initWithCapacity:[self count]];
  NSEnumerator* enumerator = [self objectEnumerator];
  id object = nil;
  while((object = [enumerator nextObject]))
  {
    id copyOfObject =
      [object respondsToSelector:@selector(deepCopyWithZone:)] ? [object deepCopyWithZone:zone] : [object copyWithZone:zone];
    [clone addObject:copyOfObject];
    [copyOfObject release];
  }//end for each object
  NSArray* immutableClone = [[NSArray allocWithZone:zone] initWithArray:clone];
  [clone release];
  return immutableClone;
}
//end deepCopyWithZone:

-(id) deepMutableCopy {return [self deepMutableCopyWithZone:nil];}
-(id) deepMutableCopyWithZone:(NSZone*)zone
{
  NSMutableArray* clone = [[NSMutableArray allocWithZone:zone] initWithCapacity:[self count]];
  NSEnumerator* enumerator = [self objectEnumerator];
  id object = nil;
  while((object = [enumerator nextObject]))
  {
    id copyOfObject =
      [object respondsToSelector:@selector(deepMutableCopyWithZone:)]
         ? [object deepMutableCopyWithZone:zone]
         : ([object respondsToSelector:@selector(mutableCopyWithZone:)] ? [object mutableCopyWithZone:zone] : [object copyWithZone:zone]);
    [clone addObject:copyOfObject];
    [copyOfObject release];
  }//end for each object
  return clone;
}
//end deepMutableCopyWithZone:

@end
