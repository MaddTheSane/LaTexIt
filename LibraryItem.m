//  LibraryItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//A LibraryItem is similar to an XMLNode, in the way that it has parent (weak link to prevent cycling)
//and children (strong link)
//It is an abstract class, its derivations aim at presenting information in the Library outlineview of the library drawer
//Each libraryItem has a name and an icon

//This class is heavily inspired by the TreeData and TreeNode classes of the DragDropOutlineView provided
//by apple in the developer documentation

#import "LibraryItem.h"

#import "LibraryFile.h"
#import "LibraryFolder.h"
#import "NSMutableArrayExtended.h"

@interface LibraryItem (PrivateAPI)
-(void) _removeChildrenIdenticalTo:(NSArray*)children;
@end

@implementation LibraryItem

-(id) init
{
  if (![super init])
    return nil;
  title    = [[NSString alloc] initWithString:NSLocalizedString(@"Untitled", @"Untitled")];
  children = [[NSMutableArray alloc] init];
  return self;
}
//end init

-(void) dealloc
{
  [title    release];
  [children release];
  [super    dealloc];
}
//end dealloc

-(void) setExpanded:(BOOL)expanded
{
  isExpanded = expanded;
}
//end setExpanded:

-(BOOL) isExpanded
{
  return isExpanded;
}
//end isExpanded

-(id) copyWithZone:(NSZone*)zone
{
  LibraryItem* item = [[[self class] alloc] init];
  if (item)
  {
    [item->title release];
    [item->children release];    
    item->parent = parent;
    item->title = [title retain];
    item->children = [children mutableCopy];
    unsigned int i = 0;
    for(i= 0 ; i<[item->children count] ; ++i)
    {
      id object = [item->children objectAtIndex:i];
      [item->children replaceObjectAtIndex:i withObject:[[object copy] autorelease]];
    }
  }
  return item;
}
//end copyWithZone:

-(void) setParent:(LibraryItem*)aParent
{
  parent = aParent; //weak link to prevent cycling
}
//end setParent:

-(LibraryItem*) parent
{
  return parent;
}
//end parent

-(void) setTitle:(NSString*)aTitle
{
  [aTitle retain];
  [title release];
  title = aTitle;
  if ([self isKindOfClass:[LibraryFile class]])
    [[(LibraryFile*)self value] setTitle:title];
}
//end setTitle:

-(NSString*) title
{
  return title;
}
//end title

-(BOOL) updateTitle//try to change the name so that no brother has the same; rretusn YES if it has changed
{
  BOOL hasChangedTitle = NO;
  
  NSMutableArray* brothers = [NSMutableArray arrayWithArray:[parent children]];
  [brothers removeObject:self];
  NSMutableArray* titles = [NSMutableArray arrayWithCapacity:[brothers count]];
  NSEnumerator* enumerator = [brothers objectEnumerator];
  LibraryItem* item = [enumerator nextObject];
  while(item)
  {
    [titles addObject:[item title]];
    item = [enumerator nextObject];
  }
  
  unsigned int indexOfIdenticTitle = [titles indexOfObject:title];
  if (indexOfIdenticTitle != NSNotFound)
  {
    [titles removeObjectAtIndex:indexOfIdenticTitle];
    unsigned int delta = 2;
    NSString* proposition = [[NSString alloc] initWithFormat:@"%@-%d", title, delta++];
    indexOfIdenticTitle = [titles indexOfObject:proposition];
    while(delta && (indexOfIdenticTitle != NSNotFound))
    {
      [titles removeObjectAtIndex:indexOfIdenticTitle];
      [proposition release];
      proposition = [[NSString alloc] initWithFormat:@"%@-%d", title, delta++];
      indexOfIdenticTitle = [titles indexOfObject:proposition];
    }
    [self setTitle:proposition];
    [proposition release];
    hasChangedTitle = YES;
  }
  
  return hasChangedTitle;
}
//end updateTitle

//Structuring methods

-(void) insertChild:(LibraryItem*)child //inserts at the end
{
  [self insertChild:child atIndex:[children count]];
}
//end insertChild:

-(void) insertChild:(LibraryItem*)child atIndex:(int)index
{
  [children insertObject:child atIndex:index];
  [child setParent:self];
}
//end insertChild:atIndex:

-(void) insertChildren:(NSArray*)someChildren atIndex:(int)index
{
  [children insertObjectsFromArray:someChildren atIndex:index];
  [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
}
//end insertChildren:atIndex:

-(void) _removeChildrenIdenticalTo:(NSArray*)someChildren
{
  [someChildren makeObjectsPerformSelector:@selector(setParent:) withObject:nil];
  NSEnumerator* childEnumerator = [someChildren objectEnumerator];
  LibraryItem* child = [childEnumerator nextObject];
  while (child)
  {
    [children removeObjectIdenticalTo:child];
    child = [childEnumerator nextObject];
  }
}
//end _removeChildrenIdenticalTo:

-(void) removeChild:(LibraryItem*)child
{
  int index = [self indexOfChild:child];
  if (index != NSNotFound)
    [self _removeChildrenIdenticalTo:[NSArray arrayWithObject:[self childAtIndex:index]]];
}
//end removeChild:

-(void) removeChildren:(NSArray*)someChildren
{
  NSEnumerator* enumerator = [someChildren objectEnumerator];
  LibraryItem* child = [enumerator nextObject];
  while(child)
  {
    [self removeChild:child];
    child = [enumerator nextObject];
  }
}
//end removeChildren:

-(void) removeFromParent
{
  [[self parent] removeChild:self];
}

-(int) indexOfChild:(LibraryItem*)child
{
  return [children indexOfObject:child];
}
//end indexOfChild:

-(int) numberOfChildren
{
  return [children count];
}
//end numberOfChildren

-(NSArray*) children
{
  return [NSArray arrayWithArray:children];
}
//end children

-(LibraryItem*) childAtIndex:(int)index
{
  return [children objectAtIndex:index];
}

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:title    forKey:@"title"];
  [coder encodeObject:children forKey:@"children"];
  [coder encodeBool:isExpanded forKey:@"isExpanded"];
  //we do not encode the parent, it is useless
}
//end encodeWithCoder:

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super init])
    return nil;
  title      = [[coder decodeObjectForKey:@"title"] retain];
  children   = [[coder decodeObjectForKey:@"children"] retain];
  isExpanded = [coder decodeBoolForKey:@"isExpanded"];
  //the parent is not encoded, so we must ensure to set it manually in the children
  [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
  return self;
}
//end initWithCoder:

-(NSImage*) icon
{
  return nil;
}
//end icon

// returns YES if 'item' is an ancestor.
// Walk up the tree, to see if any of our ancestors is 'item'.
-(BOOL) isDescendantOfItem:(LibraryItem*)item
{
  BOOL isDescendant = NO;
  LibraryItem* tmpParent = self;
  while(tmpParent && !isDescendant)
  {
    isDescendant |= (tmpParent == item);
    tmpParent = [tmpParent parent];
  }
  return isDescendant;
}
//end isDescendantOfItem:

// returns YES if any 'item' in the array 'items' is an ancestor of ours.
// For each item in items, if item is an ancestor return YES.  If none is an
// ancestor, return NO
-(BOOL) isDescendantOfItemInArray:(NSArray*)items
{
  BOOL isDescendant  = NO;
  NSEnumerator* enumerator = [items objectEnumerator];
  LibraryItem*  item = [enumerator nextObject];
  while(item && !isDescendant)
  {
    isDescendant |= [self isDescendantOfItem:item];
    item = [enumerator nextObject];
  }
  return isDescendant;
}
//end isDescendantOfItemInArray:

-(LibraryItem*) nextSibling
{
  LibraryItem* cur = self;
  LibraryItem* nextSibling = nil;
  LibraryItem* tmpParent = parent;
  while(tmpParent && !nextSibling)
  {
    int index = [tmpParent indexOfChild:cur];
    if ((index != NSNotFound) && (index+1 < [tmpParent numberOfChildren]))
      nextSibling = [tmpParent childAtIndex:index+1];
    else
    {
      cur = parent;
      tmpParent = [tmpParent parent];
    }
  }
  return nextSibling;
}
//end nextSibling

//Difficult method : returns a simplified array, to be sure that no item of the array has an ancestor
//in this array. This is useful, when several items are selected, to factorize the work in a common
//ancestor. It solves many problems.

// Returns the minimum nodes from 'allNodes' required to cover the nodes in 'allNodes'.
// This methods returns an array containing nodes from 'allNodes' such that no node in
// the returned array has an ancestor in the returned array.

// There are better ways to compute this, but this implementation should be efficient for our app.
+(NSArray*) minimumNodeCoverFromItemsInArray:(NSArray*)allItems
{
  NSMutableArray* minimumCover = [NSMutableArray array];
  NSMutableArray* itemQueue = [NSMutableArray arrayWithArray:allItems];
  LibraryItem *item = nil;
  while ([itemQueue count])
  {
    item = [itemQueue objectAtIndex:0];
    [itemQueue removeObjectAtIndex:0];
    while ([item parent] && [itemQueue containsObjectIdenticalTo:[item parent]])
    {
      [itemQueue removeObjectIdenticalTo:item];
      item = [item parent];
    }
    if (![item isDescendantOfItemInArray:minimumCover])
      [minimumCover addObject:item];
    [itemQueue removeObjectIdenticalTo:item];
  }
  return minimumCover;
}
//end minimumNodeCoverFromItemsInArray:

//for readable export
-(id) plistDescription
{
  NSMutableArray* childDescriptions = [NSMutableArray arrayWithCapacity:[children count]];
  NSEnumerator* enumerator = [children objectEnumerator];
  LibraryItem* child = nil;
  while((child = [enumerator nextObject]))
    [childDescriptions addObject:[child plistDescription]];
  
  return [NSDictionary dictionaryWithObjectsAndKeys:
    @"1.14.4", @"version",
    [self title], @"title",
    childDescriptions, @"content",
    nil];
}
//end plistDescription

@end
