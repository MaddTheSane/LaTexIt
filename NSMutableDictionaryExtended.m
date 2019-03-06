//
//  NSMutableDictionaryExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/07/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "NSMutableDictionaryExtended.h"


@implementation NSMutableDictionary (Extended)

-(void) replaceKey:(id)oldKey withKey:(id)newKey
{
  if (oldKey && ![oldKey isEqual:newKey])
  {
    #ifdef ARC_ENABLED
    id value = !oldKey ? nil : [self objectForKey:oldKey];
    #else
    id value = !oldKey ? nil : [[self objectForKey:oldKey] retain];
    #endif
    if (oldKey)
      [self removeObjectForKey:oldKey];
    if (value && newKey)
      [self setObject:value forKey:newKey];
    #ifdef ARC_ENABLED
    #else
    [value release];
    #endif
  }//end if (oldKey && ![oldKey isEqual:newKey])
}
//end replaceKey:withKey:

@end
