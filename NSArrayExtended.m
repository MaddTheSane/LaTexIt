//  NSArrayExtended.m
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import "NSArrayExtended.h"

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

@end
