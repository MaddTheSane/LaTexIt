//
//  NSObjectTreeNode.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSObjectTreeNode.h"

#import "NSArrayExtended.h"

@implementation NSObject (TreeNode)

-(BOOL) isDescendantOfItemInArray:(NSArray*)items parentSelector:(SEL)parentSelector
{
  BOOL result = NO;
  id parent = [self performSelector:parentSelector];
  result = [items containsObject:parent] || (parent && [parent isDescendantOfItemInArray:items parentSelector:parentSelector]);
  return result;
}
//end isDescendantOfItemInArray:

-(BOOL) isDescendantOfNode:(id)node strictly:(BOOL)strictly parentSelector:(SEL)parentSelector
{
  BOOL result = NO;
  result = node && !strictly && (self == node);
  if (node && !result)
  {
    id parent = [self performSelector:parentSelector];
    result = (parent == node) || (parent && [parent isDescendantOfNode:node strictly:strictly parentSelector:parentSelector]);
  }
  return result;
}
//end isDescendantOfNode:strictly:parentSelector:

-(id) nextBrotherWithParentSelector:(SEL)parentSelector childrenSelector:(SEL)childrenSelector withObject:(id)childrenSelectorArg rootNodes:(NSArray*)rootNodes
{
  id result = nil;
  id parent = [self performSelector:parentSelector];
  NSArray* brothers = !parent ? rootNodes : [parent performSelector:childrenSelector withObject:childrenSelectorArg];
  NSUInteger index = [brothers indexOfObject:self];
  if (index+1 < brothers.count)
    result = brothers[index+1];
  return result;
}
//end nextBrotherWithParentSelector:childrenSelector:withPredicate:rootNodes:

-(id) prevBrotherWithParentSelector:(SEL)parentSelector childrenSelector:(SEL)childrenSelector withObject:(id)childrenSelectorArg rootNodes:(NSArray*)rootNodes
{
  id result = nil;
  id parent = [self performSelector:parentSelector];
  NSArray* brothers = !parent ? rootNodes : [parent performSelector:childrenSelector withObject:childrenSelectorArg];
  NSUInteger index = [brothers indexOfObject:self];
  if (index > 0)
    result = brothers[index-1];
  return result;
}
//end prevBrotherWithParentSelector:childrenSelector:withPredicate:rootNodes:

//Returns a simplified array, to be sure that no item of the array has an ancestor
//in this array. This is useful, when several items are selected, to factorize the work in a common
//ancestor. It solves many problems.

// Returns the minimum nodes from 'allNodes' required to cover the nodes in 'allNodes'.
// This methods returns an array containing nodes from 'allNodes' such that no node in
// the returned array has an ancestor in the returned array.

// There are better ways to compute this, but this implementation should be efficient for our app.
+(NSArray*) minimumNodeCoverFromItemsInArray:(NSArray*)allItems parentSelector:(SEL)parentSelector
{
  NSMutableArray* minimumCover = [NSMutableArray array];
  NSMutableArray* itemQueue    = [NSMutableArray arrayWithArray:allItems];
  id              item         = nil;
  while (itemQueue.count)
  {
    item = itemQueue[0];
    [itemQueue removeObjectAtIndex:0];
    id parent = [item performSelector:parentSelector];
    while (parent && [itemQueue containsObjectIdenticalTo:parent])
    {
      [itemQueue removeObjectIdenticalTo:item];
      item = parent;
    }
    if (![item isDescendantOfItemInArray:minimumCover parentSelector:parentSelector])
      [minimumCover addObject:item];
    [itemQueue removeObjectIdenticalTo:item];
  }//end while ([itemQueue count])
  return minimumCover;
}
//end minimumNodeCoverFromItemsInArray:

@end
