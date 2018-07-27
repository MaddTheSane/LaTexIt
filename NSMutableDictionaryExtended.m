//
//  NSMutableDictionaryExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/07/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSMutableDictionaryExtended.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSMutableDictionary (Extended)

-(void) replaceKey:(id)oldKey withKey:(id)newKey
{
  if (oldKey && ![oldKey isEqual:newKey])
  {
    id value = !oldKey ? nil : [self objectForKey:oldKey];
    if (oldKey)
      [self removeObjectForKey:oldKey];
    if (value && newKey)
      [self setObject:value forKey:newKey];
  }//end if (oldKey && ![oldKey isEqual:newKey])
}
//end replaceKey:withKey:

@end
