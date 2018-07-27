//
//  NSDictionaryExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/10/07.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.
//

#import "NSDictionaryExtended.h"


@implementation NSDictionary (Extended)

-(NSDictionary*) subDictionaryWithKeys:(NSArray*)keys
{
  NSDictionary* result = nil;
  NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] initWithCapacity:[keys count]];
  NSEnumerator* enumerator = [keys objectEnumerator];
  id key = nil;
  while((key = [enumerator nextObject]))
    [dictionary setObject:[self objectForKey:key] forKey:key];
  result = [NSDictionary dictionaryWithDictionary:dictionary];
  [dictionary release];
  return result;
}
//end subDictionaryWithKeys:

-(id) deepCopy {return [self deepCopyWithZone:nil];}
-(id) deepCopyWithZone:(NSZone*)zone
{
  NSMutableDictionary* clone = [[NSMutableDictionary allocWithZone:zone] initWithCapacity:[self count]];
  NSEnumerator* keyEnumerator = [self keyEnumerator];
  id key = nil;
  while((key = [keyEnumerator nextObject]))
  {
    id object = [self valueForKey:key];
    id copyOfObject =
      [object respondsToSelector:@selector(deepCopyWithZone:)] ? [object deepCopyWithZone:zone] : [object copyWithZone:zone];
    [clone setObject:copyOfObject forKey:key];
    [copyOfObject release];
  }//end for each object
  NSDictionary* immutableClone = [[NSDictionary allocWithZone:zone] initWithDictionary:clone];
  [clone release];
  return immutableClone;
}
//end deepCopyWithZone:

-(id) deepMutableCopy {return [self deepMutableCopyWithZone:nil];}
-(id) deepMutableCopyWithZone:(NSZone*)zone
{
  NSMutableDictionary* clone = [[NSMutableDictionary allocWithZone:zone] initWithCapacity:[self count]];
  NSEnumerator* keyEnumerator = [self keyEnumerator];
  id key = nil;
  while((key = [keyEnumerator nextObject]))
  {
    id object = [self valueForKey:key];
    id copyOfObject =
      [object respondsToSelector:@selector(deepMutableCopyWithZone:)]
         ? [object deepMutableCopyWithZone:zone]
         : ([object respondsToSelector:@selector(mutableCopyWithZone:)] ? [object mutableCopyWithZone:zone] : [object copyWithZone:zone]);
    [clone setObject:copyOfObject forKey:key];
    [copyOfObject release];
  }//end for each object
  return clone;
}
//end deepMutableCopyWithZone:


@end
