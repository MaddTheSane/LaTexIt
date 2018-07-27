//  HistoryView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This is the table view displaying the history in the history drawer
//Its delegate and datasource are the HistoryManager, the history being shared by all documents

#import "HistoryView.h"

#import "HistoryCell.h"
#import "HistoryManager.h"
#import "LibraryManager.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSColorExtended.h"

@interface HistoryView (PrivateAPI)
-(void) _historyDidChange:(NSNotification*)aNotification;
@end

@implementation HistoryView

-(id) initWithCoder:(NSCoder*)coder
{
  self = [super initWithCoder:coder];
  if (self)
  {
    [self setDataSource:[HistoryManager sharedManager]];
    [self setDelegate:[HistoryManager sharedManager]];
    
    [self registerForDraggedTypes:[NSArray arrayWithObject:NSColorPboardType]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_historyDidChange:)
                                                 name:HistoryDidChangeNotification object:nil];
    [self _historyDidChange:nil];
  }
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(void) _historyDidChange:(NSNotification*)aNotification
{
  [self reloadData];
  int numberOfRows = [self numberOfRows];
  NSString* title = [NSString stringWithFormat:@"%@ (%d %@)",
                     NSLocalizedString(@"History", @"History"),
                     numberOfRows,
                     [NSLocalizedString(@"item", @"item") stringByAppendingString:((numberOfRows>1) ? @"s": @"")]];
  [[[self tableColumnWithIdentifier:@"history"] headerCell] setStringValue:title];
}

-(MyDocument*) document
{
  return document;
}

//events management, particularly cursor moving and selection

-(void) keyDown:(NSEvent*)theEvent
{
  [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

-(void) cancelOperation:(id)sender
{
  [self deselectAll:self];
}

-(void) deleteBackward:(id)sender
{
  [[HistoryManager sharedManager] removeItemsAtIndexes:[self selectedRowIndexes] tableView:self];
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

//get the currently selected items
-(NSArray*) selectedItems
{
  return [[HistoryManager sharedManager] itemsAtIndexes:[self selectedRowIndexes] tableView:self];
}

//drag'n drop
-(NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return isLocal ? NSDragOperationEvery : NSDragOperationCopy;
}

//copy current document stata
-(IBAction) copy:(id)sender
{
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray array] owner:self];
  
  //HistoryItemsPboardType
  NSArray* selectedItems = [self selectedItems];
  [pasteboard addTypes:[NSArray arrayWithObject:HistoryItemsPboardType] owner:self];
  [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:selectedItems] forType:HistoryItemsPboardType];

  //NSPDFPboardType
  HistoryItem* lastItem = [selectedItems lastObject];  
  if (lastItem)
  {
    [pasteboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:self];
    [pasteboard setData:[lastItem pdfData] forType:NSPDFPboardType];
  }
}

//paste data in the document
-(IBAction) paste:(id)sender
{
  NSPasteboard* pboard = [NSPasteboard generalPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsPboardType]])
  {
    NSArray* libraryItems = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:LibraryItemsPboardType]];
    LibraryItem* item = [libraryItems lastObject];
    if (item && [item isKindOfClass:[LibraryFile class]])
      [document applyHistoryItem:(HistoryItem*)[item value]];
  }
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:HistoryItemsPboardType]])
  {
    HistoryItem* item = [[NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:HistoryItemsPboardType]] lastObject];
    if (item)
      [document applyHistoryItem:item];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
  {
    NSData* pdfData = [pboard dataForType:NSPDFPboardType];
    if (pdfData)
      [document applyPdfData:pdfData];
  }
}

@end
