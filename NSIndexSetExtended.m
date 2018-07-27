//  NSIndexSetExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSIndexSet class

#import "NSIndexSetExtended.h"

@implementation NSIndexSet (Extended)

//returns a representation of the receiver as an array of unsigned NSNumbers
-(NSArray*) array
{
  NSMutableArray* array = [NSMutableArray arrayWithCapacity:[self count]];
  unsigned int index = [self firstIndex];
  while(index != NSNotFound)
  {
    [array addObject:[NSNumber numberWithUnsignedInt:index]];
    index = [self indexGreaterThanIndex:index];
  }
  return array;
}

@end
