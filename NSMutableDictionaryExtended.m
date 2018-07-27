//
//  NSMutableDictionaryExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/07/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import "NSMutableDictionaryExtended.h"


@implementation NSMutableDictionary (Extended)

-(void) replaceKey:(id)oldKey withKey:(id)newKey
{
  if (oldKey && ![oldKey isEqual:newKey])
  {
    id value = !oldKey ? nil : [[self objectForKey:oldKey] retain];
    if (oldKey)
      [self removeObjectForKey:oldKey];
    if (value && newKey)
      [self setObject:value forKey:newKey];
    [value release];
  }//end if (oldKey && ![oldKey isEqual:newKey])
}
//end replaceKey:withKey:

@end
