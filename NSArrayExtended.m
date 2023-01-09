//  NSArrayExtended.m
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.

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

-(NSArray*) arrayByAddingObject:(id)object atIndex:(NSUInteger)index
{
  NSMutableArray* result = AUTORELEASEOBJ([self mutableCopy]);
  [result insertObject:object atIndex:index];
  return result;
}
//end arrayByAddingObject:atIndex:

-(NSArray*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index
{
  NSMutableArray* result = AUTORELEASEOBJ([self mutableCopy]);
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
  result = AUTORELEASEOBJ([result copy]);
  return result;
}
//end filteredArrayWithItemsOfClass:exactClass:

-(id) copyDeep {return [self copyDeepWithZone:nil];}
-(id) copyDeepWithZone:(NSZone*)zone
{
  NSMutableArray* clone = [[NSMutableArray allocWithZone:zone] initWithCapacity:[self count]];
  NSEnumerator* enumerator = [self objectEnumerator];
  id object = nil;
  while((object = [enumerator nextObject]))
  {
    id copyOfObject =
      [object respondsToSelector:@selector(copyDeepWithZone:)] ? [object copyDeepWithZone:zone] : [object copyWithZone:zone];
    [clone addObject:copyOfObject];
    RELEASEOBJ(copyOfObject);
  }//end for each object
  NSArray* immutableClone = [[NSArray allocWithZone:zone] initWithArray:clone];
  RELEASEOBJ(clone);
  return immutableClone;
}
//end copyDeepWithZone:

-(id) mutableCopyDeep {return [self mutableCopyDeepWithZone:nil];}
-(id) mutableCopyDeepWithZone:(NSZone*)zone
{
  NSMutableArray* clone = [[NSMutableArray allocWithZone:zone] initWithCapacity:[self count]];
  NSEnumerator* enumerator = [self objectEnumerator];
  id object = nil;
  while((object = [enumerator nextObject]))
  {
    id copyOfObject =
      [object respondsToSelector:@selector(mutableCopyDeepWithZone:)]
         ? [object mutableCopyDeepWithZone:zone]
         : ([object respondsToSelector:@selector(mutableCopyWithZone:)] ? [object mutableCopyWithZone:zone] : [object copyWithZone:zone]);
    [clone addObject:copyOfObject];
    RELEASEOBJ(copyOfObject);
  }//end for each object
  return clone;
}
//end mutableCopyDeepWithZone:

@end
