//
//  NSDictionaryExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/10/07.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSDictionaryExtended.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSDictionary (Extended)

-(NSDictionary*) dictionaryByAddingDictionary:(NSDictionary*)dictionary
{
  NSMutableDictionary* result = [self mutableCopy];
  for(id key in dictionary.allKeys)
    result[key] = dictionary[key];
  return result;
}
//end dictionaryByAddingDictionary:

-(NSDictionary*) dictionaryByAddingObjectsAndKeys:(id)firstObject, ...
{
  NSMutableDictionary* result = [self mutableCopy];
  va_list argumentList;
  id object = firstObject;
  if (object)
  {
    va_start(argumentList, firstObject);
    id key =  va_arg(argumentList, id);
    while(key)
    {
      result[key] = object;
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
  NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] initWithCapacity:keys.count];
  for(id key in keys)
  {
    id object = self[key];
    if (object)
      dictionary[key] = object;
  }
  result = [NSDictionary dictionaryWithDictionary:dictionary];
  return result;
}
//end subDictionaryWithKeys:

-(id) copyDeep {return [self copyDeepWithZone:nil];}
-(id) copyDeepWithZone:(NSZone*)zone
{
  NSMutableDictionary* clone = [[NSMutableDictionary allocWithZone:zone] initWithCapacity:self.count];
  for(id key in self)
  {
    id object = [self valueForKey:key];
    id copyOfObject =
      [object respondsToSelector:@selector(copyDeepWithZone:)] ? [object copyDeepWithZone:zone] : [object copyWithZone:zone];
    clone[key] = copyOfObject;
    #ifdef ARC_ENABLED
    #else
    [copyOfObject release];
    #endif
  }//end for each object
  NSDictionary* immutableClone = [[NSDictionary allocWithZone:zone] initWithDictionary:clone];
  return immutableClone;
}
//end copyDeepWithZone:

-(id) mutableCopyDeep {return [self mutableCopyDeepWithZone:nil];}
-(id) mutableCopyDeepWithZone:(NSZone*)zone
{
  NSMutableDictionary* clone = [[NSMutableDictionary allocWithZone:zone] initWithCapacity:self.count];
  NSEnumerator* keyEnumerator = [self keyEnumerator];
  for(id key in keyEnumerator)
  {
    id object = [self valueForKey:key];
    id copyOfObject =
      [object respondsToSelector:@selector(mutableCopyDeepWithZone:)] ? [object mutableCopyDeepWithZone:zone] :
      [object respondsToSelector:@selector(mutableCopyWithZone:)] ? [object mutableCopyWithZone:zone] :
      [object respondsToSelector:@selector(copyWithZone:)] ? [object copyWithZone:zone] : object;
    clone[key] = copyOfObject;
  }//end for each object
  return clone;
}
//end mutableCopyDeepWithZone:

-(id) objectForKey:(id)key withClass:(Class)class
{
  id result = self[key];
  if (![result isKindOfClass:class])
    result = nil;
  return result;
}
//end objectForKey:withClass:

@end
