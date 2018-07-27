//  NSArrayExtended.m
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import "NSArrayExtended.h"
#import "NSMutableArrayExtended.h"

@implementation NSArray (Extended)

-(id) firstObject
{
  id result = [self count] ? [self objectAtIndex:0] : nil;
  return result;
}
//end firstObject

//checks if the array contains an object, based on adress comparison, not isEqual:
-(BOOL) containsObjectIdenticalTo:(id)object
{ 
  BOOL result = ([self indexOfObjectIdenticalTo:object] != NSNotFound);
  return result;
}
//end containsObjectIdenticalTo:

//returns a copy of the receiver in the reversed order
-(NSArray*) reversed
{
  NSMutableArray* result = [NSMutableArray arrayWithCapacity:[self count]];
  NSEnumerator* enumerator = [self reverseObjectEnumerator];
  id object = [enumerator nextObject];
  while(object)
  {
    [result addObject:object];
    object = [enumerator nextObject];
  }
  return result;
}
//end reversed

-(NSArray*) arrayByAddingObject:(id)object atIndex:(unsigned int)index
{
  NSMutableArray* result = [[self mutableCopy] autorelease];
  [result insertObject:object atIndex:index];
  return result;
}
//end arrayByAddingObject:atIndex:

-(NSArray*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(unsigned int)index
{
  NSMutableArray* result = [[self mutableCopy] autorelease];
  [result moveObjectsAtIndices:indices toIndex:index];
  return result;
}
//end arrayByMovingObjectsAtIndices:toIndex:

-(NSArray*) filteredArrayWithItemsOfClass:(Class)aClass exactClass:(BOOL)exactClass
{
  NSMutableArray* result = [NSMutableArray arrayWithCapacity:[self count]];
  NSEnumerator* enumerator = [self objectEnumerator];
  id object = nil;
  if (exactClass)
  {
    while((object = [enumerator nextObject]))
    {
      if ([object isMemberOfClass:aClass])
        [result addObject:object];
    }
  }//end if (exactClass)
  else//if (!exactClass)
  {
    while((object = [enumerator nextObject]))
    {
      if ([object isKindOfClass:aClass])
        [result addObject:object];
    }
  }//end if (!exactClass)
  return [[result copy] autorelease];
}
//end filteredArrayWithItemsOfClass:exactClass:

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
