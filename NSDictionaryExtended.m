//
//  NSDictionaryExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/10/07.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import "NSDictionaryExtended.h"


@implementation NSDictionary (Extended)

-(NSDictionary*) dictionaryByAddingDictionary:(NSDictionary*)dictionary
{
  #ifdef ARC_ENABLED
  NSMutableDictionary* result = [self mutableCopy];
  #else
  NSMutableDictionary* result = [[self mutableCopy] autorelease];
  #endif
  NSEnumerator* enumerator = [[dictionary allKeys] objectEnumerator];
  id key = nil;
  while((key = [enumerator nextObject]))
    [result setObject:[dictionary objectForKey:key] forKey:key];
  return result;
}
//end dictionaryByAddingDictionary:

-(NSDictionary*) dictionaryByAddingObjectsAndKeys:(id)firstObject, ...
{
  #ifdef ARC_ENABLED
  NSMutableDictionary* result = [self mutableCopy];
  #else
  NSMutableDictionary* result = [[self mutableCopy] autorelease];
  #endif
  va_list argumentList;
  id object = firstObject;
  if (object)
  {
    va_start(argumentList, firstObject);
    id key =  va_arg(argumentList, id);
    while(key)
    {
      [result setObject:object forKey:key];
      object = va_arg(argumentList, id);
      key = !object ? nil : va_arg(argumentList, id);
    }//end while(key)
    va_end(argumentList);
  }//end if (object)
  return result;
}//end dictionaryByAddingObjectsAndKeys:

-(NSDictionary*) subDictionaryWithKeys:(NSArray*)keys
{
  NSDictionary* result = nil;
  NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] initWithCapacity:[keys count]];
  NSEnumerator* enumerator = [keys objectEnumerator];
  id key = nil;
  while((key = [enumerator nextObject]))
  {
    id object = [self objectForKey:key];
    if (object)
      [dictionary setObject:object forKey:key];
  }
  result = [NSDictionary dictionaryWithDictionary:dictionary];
  #ifdef ARC_ENABLED
  #else
  [dictionary release];
  #endif
  return result;
}
//end subDictionaryWithKeys:

-(id) deepCopy {return [self deepCopyWithZone:nil];}
-(id) deepCopyWithZone:(NSZone*)zone
{
  NSMutableDictionary* clone = [[NSMutableDictionary allocWithZone:zone] initWithCapacity:[self count]];
  for(id key in self)
  {
    id object = [self valueForKey:key];
    id copyOfObject =
      [object respondsToSelector:@selector(deepCopyWithZone:)] ? [object deepCopyWithZone:zone] : [object copyWithZone:zone];
    [clone setObject:copyOfObject forKey:key];
    #ifdef ARC_ENABLED
    #else
    [copyOfObject release];
    #endif
  }//end for each object
  NSDictionary* immutableClone = [[NSDictionary allocWithZone:zone] initWithDictionary:clone];
  #ifdef ARC_ENABLED
  #else
  [clone release];
  #endif
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
      [object respondsToSelector:@selector(deepMutableCopyWithZone:)] ? [object deepMutableCopyWithZone:zone] :
      [object respondsToSelector:@selector(mutableCopyWithZone:)] ? [object mutableCopyWithZone:zone] :
      #ifdef ARC_ENABLED
      [object respondsToSelector:@selector(copyWithZone:)] ? [object copyWithZone:zone] : object;
      #else
      [object respondsToSelector:@selector(copyWithZone:)] ? [object copyWithZone:zone] : [object retain];
      #endif
    [clone setObject:copyOfObject forKey:key];
    #ifdef ARC_ENABLED
    #else
    [copyOfObject release];
    #endif
  }//end for each object
  return clone;
}
//end deepMutableCopyWithZone:

-(id) objectForKey:(id)key withClass:(Class)class
{
  id result = [self objectForKey:key];
  if (![result isKindOfClass:class])
    result = nil;
  return result;
}
//end objectForKey:withClass:

@end
