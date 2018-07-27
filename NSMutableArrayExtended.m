//  NSMutableArrayExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 3/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSMutableArray class

#import "NSMutableArrayExtended.h"

@implementation NSMutableArray (Extended)

//inserts another array's content at a given index
-(void) insertObjectsFromArray:(NSArray *)array atIndex:(int)index
{
  NSEnumerator* enumerator = [array objectEnumerator];
  NSObject* entry = [enumerator nextObject];
  while (entry)
  {
    [self insertObject:entry atIndex:index++];
    entry = [enumerator nextObject];
  }
}

//checks if indexOfObjectIdenticalTo returns a valid index
-(BOOL) containsObjectIdenticalTo:(id)object
{ 
  return ([self indexOfObjectIdenticalTo:object] != NSNotFound);
}

@end
