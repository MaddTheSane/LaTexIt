//
//  NSOutlineViewExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSOutlineViewExtended.h"

@implementation NSOutlineView (Extended)

-(NSArray*) itemsAtRowIndexes:(NSIndexSet*)rowIndexes
{
  NSMutableArray* result = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
  NSUInteger row = [rowIndexes firstIndex];
  while(row != NSNotFound)
  {
    [result addObject:[self itemAtRow:row]];
    row = [rowIndexes indexGreaterThanIndex:row];
  }//end for each row index
  return result;
}
//end itemsAtRowIndexes:

-(id) selectedItem
{
  id result = [self itemAtRow:[self selectedRow]];
  return result;
}
//end selectedItem

-(NSArray*) selectedItems
{
  NSArray* result = [self itemsAtRowIndexes:[self selectedRowIndexes]];
  return result;
}
//end selectedItems

-(void) selectItem:(id)item byExtendingSelection:(BOOL)extend
{
  if (!item)
    [self selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:extend];
  else
  {
    NSInteger row = [self rowForItem:item];
    [self selectRowIndexes:(row<0) ? [NSIndexSet indexSet] : [NSIndexSet indexSetWithIndex:(unsigned)row]
      byExtendingSelection:extend];
  }
}
//end selectItem:byExtendingSelection:

-(void) selectItems:(NSArray*)items byExtendingSelection:(BOOL)extend
{
  NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
  NSEnumerator* enumerator = [items objectEnumerator];
  id item = nil;
  while((item = [enumerator nextObject]))
  {
    NSInteger row = [self rowForItem:item];
    if (row>=0)
      [indexSet addIndex:(unsigned)row];
  }
  [self selectRowIndexes:indexSet byExtendingSelection:extend];
}
//end selectItems:byExtendingSelection:

@end
