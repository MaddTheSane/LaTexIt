//  LibraryView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This the library outline view, with some added methods to manage the selection

#import "LibraryView.h"

#import "AppController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LibraryCell.h"
#import "LibraryFile.h"
#import "LibraryItem.h"
#import "LibraryManager.h"
#import "MyImageView.h"
@interface LibraryView (PrivateAPI)
-(void) _libraryDidChange:(NSNotification*)aNotification;
-(void) _edit:(id)sender;
@end

@implementation LibraryView

-(id) initWithCoder:(NSCoder*)coder
{
  self = [super initWithCoder:coder];
  if (self)
  {
    [self setDataSource:[LibraryManager sharedManager]];
    [self setDelegate:[LibraryManager sharedManager]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_libraryDidChange:)
                                                 name:LibraryDidChangeNotification object:nil];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:LibraryItemsPboardType, HistoryItemsPboardType, nil]];
  }
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(MyDocument*) document
{
  return document;
}

//when the library changes, the userinfo of the notification may contain some directives to
//expand some items, select some items and scroll to some item
-(void) _libraryDidChange:(NSNotification*)aNotification
{
  [self reloadData];
  NSDictionary* dict = [aNotification userInfo];
  if (dict)
  {
    NSArray* array = [dict objectForKey:@"expand"]; //info of some items to expand
    if (array)
    {
      NSEnumerator* enumerator = [array objectEnumerator];
      id item = [enumerator nextObject];
      while(item)
      {
        [self expandItem:item];
        item = [enumerator nextObject];
      }
    }
    array = [dict objectForKey:@"select"]; //info of some items to select
    if (array)
    {
      NSMutableIndexSet* indexesToSelect = [NSMutableIndexSet indexSet];
      NSEnumerator* enumerator = [array objectEnumerator];
      id item = [enumerator nextObject];
      while(item)
      {
        [indexesToSelect addIndex:[self rowForItem:item]];
        item = [enumerator nextObject];
      }
      [self selectRowIndexes:indexesToSelect byExtendingSelection:NO];
    }
    id scrollObject = dict ? [dict objectForKey:@"scroll"] : nil; //info of some item to scroll to
    if (scrollObject)
      [self scrollRowToVisible:[self rowForItem:scrollObject]];
  }
}

-(void) keyDown:(NSEvent*)theEvent
{
  [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
  if (([theEvent keyCode] == 36) || ([theEvent keyCode] == 52) || ([theEvent keyCode] == 49))
    [self _edit:self];
}

-(void) _edit:(id)sender
{
  int selectedRow = [self selectedRow];
  if (selectedRow >= 0)
    [self editColumn:0 row:selectedRow withEvent:nil select:YES];
}

-(void) moveLeft:(id)sender
{
  id item = [self itemAtRow:[self selectedRow]];
  if ([item isKindOfClass:[LibraryFile class]])
    item = [item parent];
  [self collapseItem:item];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowForItem:item]] byExtendingSelection:NO];
}

-(void) moveRight:(id)sender
{
  id item = [self itemAtRow:[self selectedRow]];
  [self expandItem:item];
}

-(void) moveDownAndModifySelection:(id)sender
{
  //selection to down
  unsigned int lastSelectedRow   = [self selectedRow];
  NSIndexSet* selectedRowIndexes = [self selectedRowIndexes];
  if (lastSelectedRow == [selectedRowIndexes lastIndex]) //if the selection is going down, and down, increase it
  {
    if (lastSelectedRow != NSNotFound)
      ++lastSelectedRow;
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:lastSelectedRow] byExtendingSelection:YES];
  }
  else //if we are going down after an upwards selection, deselect last selected item
  {
    unsigned int firstIndex = [selectedRowIndexes firstIndex];
    [self deselectRow:firstIndex];
  }
}

-(void) moveUpAndModifySelection:(id)sender
{
  //selection to up
  unsigned int lastSelectedRow   = [self selectedRow];
  NSIndexSet* selectedRowIndexes = [self selectedRowIndexes];
  if (lastSelectedRow == [selectedRowIndexes firstIndex]) //if the selection is going up, and up, increase it
  {
    if (lastSelectedRow > 0)
      --lastSelectedRow;
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:lastSelectedRow] byExtendingSelection:YES];
  }
  else //if we are going up after an downwards selection, deselect last selected item
  {
    unsigned int lastIndex = [selectedRowIndexes lastIndex];
    [self deselectRow:lastIndex];
  }
}

-(void) moveUp:(id)sender
{
  int selectedRow = [self selectedRow];
  if (selectedRow > 0)
    --selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}

-(void) moveDown:(id)sender
{
  int selectedRow = [self selectedRow];
  if ((selectedRow >= 0) && (selectedRow+1 < [self numberOfRows]))
    ++selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}

-(void) deleteBackward:(id)sender
{
  [self removeSelectedItems];
}

-(void) removeSelectedItems
{
  NSIndexSet* selectedRowIndexes = [self selectedRowIndexes];
  if ([selectedRowIndexes count])
  {
    id nextItemToSelect = [[self itemAtRow:[selectedRowIndexes lastIndex]] nextSibling];
    NSMutableArray* itemsToRemove = [NSMutableArray arrayWithCapacity:[selectedRowIndexes count]];
    unsigned int index = [selectedRowIndexes firstIndex];
    while(index != NSNotFound)
    {
      [itemsToRemove addObject:[self itemAtRow:index]];
      index = [selectedRowIndexes indexGreaterThanIndex:index];
    }
    [[LibraryManager sharedManager] removeItems:itemsToRemove];
    [self deselectAll:self];
    if (nextItemToSelect)
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowForItem:nextItemToSelect]] byExtendingSelection:NO];
    else if ([self numberOfRows] > 0)
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self numberOfRows]-1] byExtendingSelection:NO];
  }
}

-(NSArray*) selectedItems
{
  NSIndexSet* selectedRowIndexes = [self selectedRowIndexes];
  NSMutableArray* selectedItems = [NSMutableArray arrayWithCapacity:[selectedRowIndexes count]];
  unsigned int index = [selectedRowIndexes firstIndex];
  while(index != NSNotFound)
  {
    [selectedItems addObject:[self itemAtRow:index]];
    index = [selectedRowIndexes indexGreaterThanIndex:index];
  }
  return selectedItems;
}

//selected items which are only LibraryFiles
-(NSArray*) selectedFileItems
{
  NSIndexSet* selectedRowIndexes = [self selectedRowIndexes];
  NSMutableArray* selectedFileItems = [NSMutableArray arrayWithCapacity:[selectedRowIndexes count]];
  unsigned int index = [selectedRowIndexes firstIndex];
  while(index != NSNotFound)
  {
    LibraryItem* libraryItem = [self itemAtRow:index];
    if ([libraryItem isKindOfClass:[LibraryFile class]])
      [selectedFileItems addObject:libraryItem];
    index = [selectedRowIndexes indexGreaterThanIndex:index];
  }
  return selectedFileItems;
}

//prevents from selecting next line when finished editing
-(void)textDidEndEditing:(NSNotification *)aNotification
{
  int selectedRow = [self selectedRow];
  [super textDidEndEditing:aNotification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}

//drag'n drop
-(NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return isLocal ? NSDragOperationEvery : NSDragOperationCopy;
}

//copy current document state
-(IBAction) copy:(id)sender
{
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray array] owner:self];
  
  //LibraryItemsPboardType
  NSArray* libraryItems = [LibraryItem minimumNodeCoverFromItemsInArray:[self selectedItems]];
  [pasteboard addTypes:[NSArray arrayWithObject:LibraryItemsPboardType] owner:self];
  [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:libraryItems] forType:LibraryItemsPboardType];
  
  //HistoryItemsPboardType
  NSArray* selectedFileItems = [self selectedFileItems];
  NSMutableArray* historyItems = [NSMutableArray arrayWithCapacity:[selectedFileItems count]];
  NSEnumerator* enumerator = [selectedFileItems objectEnumerator];
  LibraryFile* libraryFileItem = [enumerator nextObject];
  while(libraryFileItem)
  {
    [historyItems addObject:[libraryFileItem value]];
    libraryFileItem = [enumerator nextObject];
  }
  [pasteboard addTypes:[NSArray arrayWithObject:HistoryItemsPboardType] owner:self];
  [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:historyItems] forType:HistoryItemsPboardType];

  //NSPDFPboardType
  HistoryItem* lastItem = [historyItems lastObject];  
  if (lastItem)
  {
    [pasteboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:self];
    [pasteboard setData:[lastItem pdfData] forType:NSPDFPboardType];
  }
}

//may paste data in the document
-(IBAction) paste:(id)sender
{
  NSPasteboard* pboard = [NSPasteboard generalPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsPboardType]])
  {
    NSArray* libraryItems = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:LibraryItemsPboardType]];
    NSEnumerator* enumerator = [libraryItems objectEnumerator];
    LibraryItem* libraryItem = [enumerator nextObject];
    while (libraryItem)
    {
      [[LibraryManager sharedManager] addItem:libraryItem outlineView:self];
      libraryItem = [enumerator nextObject];
    }
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:HistoryItemsPboardType]])
  {
    NSArray* historyItems = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:HistoryItemsPboardType]];
    NSEnumerator* enumerator = [historyItems objectEnumerator];
    HistoryItem* historyItem = [enumerator nextObject];
    while(historyItem)
    {
      [[LibraryManager sharedManager] newFile:historyItem outlineView:self];
      historyItem = [enumerator nextObject];
    }
    HistoryItem* lastItem = [historyItems lastObject];
    if (lastItem)
    {
      [document applyHistoryItem:lastItem];
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowForItem:lastItem]] byExtendingSelection:NO];
    }
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
  {
    NSData* pdfData = [pboard dataForType:NSPDFPboardType];
    if (pdfData)
    {
      [document applyPdfData:pdfData];
      HistoryItem* item = [document historyItemWithCurrentState];
      LibraryItem* libraryItem = [[LibraryManager sharedManager] newFile:item outlineView:self];
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowForItem:libraryItem]] byExtendingSelection:NO];
    }
  }
}

@end
