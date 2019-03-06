//  NSArrayExtended.m
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import "NSArrayExtended.h"
#import "NSMutableArrayExtended.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSArray (Extended)


-(id) firstObjectIdenticalTo:(id)object
{
  id result = nil;
  if (object)
  {
    id current = nil;
    NSEnumerator* enumerator = [self objectEnumerator];
    while(!result && ((current = [enumerator nextObject])))
    {
      if ([current isEqual:object])
        result = current;
    }//end while(!result && ((current = [enumerator nextObject])))
  }//end if (object)
  return result;
}
//end firstObjectIdenticalTo:

-(id) firstObjectNotIdenticalTo:(id)object
{
  id result = nil;
  id current = nil;
  NSEnumerator* enumerator = [self objectEnumerator];
  while(!result && ((current = [enumerator nextObject])))
  {
    if (!object || ![current isEqual:object])
      result = current;
  }//end while(!result && ((current = [enumerator nextObject])))
  return result;
}
//end firstObjectNotIdenticalTo:

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
  NSEnumerator* enumerator = [self reverseObjectEnumerator];
  return enumerator.allObjects;
}
//end reversed

-(NSArray*) arrayByAddingObject:(id)object atIndex:(NSUInteger)index
{
  NSMutableArray* result = [self mutableCopy];
  [result insertObject:object atIndex:index];
  return [result copy];
}
//end arrayByAddingObject:atIndex:

-(NSArray*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index
{
  NSMutableArray* result = [self mutableCopy];
  [result moveObjectsAtIndices:indices toIndex:index];
  return [result copy];
}
//end arrayByMovingObjectsAtIndices:toIndex:

-(NSArray*) filteredArrayWithItemsOfClass:(Class)aClass exactClass:(BOOL)exactClass
{
  NSMutableArray* result = [NSMutableArray arrayWithCapacity:self.count];
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
  result = [result copy];
  return result;
}
//end filteredArrayWithItemsOfClass:exactClass:

-(id) deepCopy {return [self deepCopyWithZone:nil];}
-(id) deepCopyWithZone:(NSZone*)zone
{
  NSMutableArray* clone = [[NSMutableArray allocWithZone:zone] initWithCapacity:self.count];
  NSEnumerator* enumerator = [self objectEnumerator];
  for(id object in enumerator)
  {
    id copyOfObject =
      [object respondsToSelector:@selector(deepCopyWithZone:)] ? [object deepCopyWithZone:zone] : [object copyWithZone:zone];
    [clone addObject:copyOfObject];
  }//end for each object
  NSArray* immutableClone = [[NSArray allocWithZone:zone] initWithArray:clone];
  return immutableClone;
}
//end deepCopyWithZone:

-(id) deepMutableCopy {return [self deepMutableCopyWithZone:nil];}
-(id) deepMutableCopyWithZone:(NSZone*)zone
{
  NSMutableArray* clone = [[NSMutableArray allocWithZone:zone] initWithCapacity:self.count];
  NSEnumerator* enumerator = [self objectEnumerator];
  for(id object in enumerator)
  {
    id copyOfObject =
      [object respondsToSelector:@selector(deepMutableCopyWithZone:)]
         ? [object deepMutableCopyWithZone:zone]
         : ([object respondsToSelector:@selector(mutableCopyWithZone:)] ? [object mutableCopyWithZone:zone] : [object copyWithZone:zone]);
    [clone addObject:copyOfObject];
  }//end for each object
  return clone;
}
//end deepMutableCopyWithZone:

@end
