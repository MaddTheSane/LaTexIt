//  HistoryTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/03/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//This is the table view displaying the history in the history drawer
//Its delegate and datasource are the HistoryManager, the history being shared by all documents

#import "HistoryTableView.h"

#import "HistoryCell.h"
#import "HistoryController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LibraryManager.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSColorExtended.h"

@interface HistoryTableView (PrivateAPI)
-(void) _historyDidChange:(NSNotification*)aNotification;
@end

@implementation HistoryTableView

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(void) awakeFromNib
{
  [[self window] setAcceptsMouseMovedEvents:YES]; //to allow history to detect mouse moved events
  [self registerForDraggedTypes:[NSArray arrayWithObject:NSColorPboardType]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_historyDidChange:)
                                               name:HistoryDidChangeNotification object:nil];
}

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  int row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}

-(IBAction) undo:(id)sender
{
  [[[HistoryManager sharedManager] undoManager] undo];
}

-(IBAction) redo:(id)sender
{
  [[[HistoryManager sharedManager] undoManager] redo];
}

-(IBAction) paste:(id)sender
{
}

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  NSUndoManager* undoManager = [[HistoryManager sharedManager] undoManager];
  if ([sender action] == @selector(copy:))
    ok = ([self selectedRow] >= 0);
  else if ([sender action] == @selector(paste:))
    ok = NO;
  else if ([sender action] == @selector(undo:))
  {
    ok = [undoManager canUndo];
    [sender setTitleWithMnemonic:[undoManager undoMenuItemTitle]];
  }
  else if ([sender action] == @selector(redo:))
  {
    ok = [undoManager canRedo];
    [sender setTitleWithMnemonic:[undoManager redoMenuItemTitle]];
  }
  return ok;
}

-(NSUndoManager*) undoManager
{
  return [[HistoryManager sharedManager] undoManager];
}


-(void) _historyDidChange:(NSNotification*)aNotification
{
  [self reloadData];
}

//events management, particularly cursor moving and selection

-(void) applyItem
{
  MyDocument* document = (MyDocument*)[AppController currentDocument];
  if (document)
  {
    int selectedRow = [self selectedRow];
    if (selectedRow >= 0)
    {
      HistoryItem* historyItem = [[HistoryManager sharedManager] itemAtIndex:selectedRow tableView:self];
      [document applyHistoryItem:historyItem];
    }
    [[document windowForSheet] makeKeyWindow];
  }
}

-(void) keyDown:(NSEvent*)theEvent
{
  unsigned short keyCode = [theEvent keyCode];
  if ((keyCode == 36) || (keyCode == 76) || (keyCode == 49)) //enter or return or space
    [self applyItem];
  else
    [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

-(void) mouseDown:(NSEvent*)theEvent
{
  if ([theEvent clickCount] == 1)
    [super mouseDown:theEvent];
  else if ([theEvent clickCount] == 2)
    [self applyItem];
}
//end mouseDown

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
    [self scrollRowToVisible:lastSelectedRow-1];
  }
  else //if we are going down after an upwards selection, deselect last selected item
  {
    unsigned int firstIndex = [selectedRowIndexes firstIndex];
    [self deselectRow:firstIndex];
    [self scrollRowToVisible:firstIndex+1];
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
    [self scrollRowToVisible:lastSelectedRow];
  }
  else //if we are going up after an downwards selection, deselect last selected item
  {
    unsigned int lastIndex = [selectedRowIndexes lastIndex];
    [self deselectRow:lastIndex];
    [self scrollRowToVisible:lastIndex-1];
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

/*
//paste data in the document
-(IBAction) paste:(id)sender
{
  NSPasteboard* pboard = [NSPasteboard generalPasteboard];
  MyDocument* document = (MyDocument*) [AppController currentDocument];
  if (document)
  {
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
}
*/

-(void) scrollWheel:(NSEvent*)event
{
  [super scrollWheel:event];
  [self mouseMoved:event];//to trigger preview display
}

-(void) mouseMoved:(NSEvent*)event
{
  HistoryController* historyController = (HistoryController*)[[self window] windowController];
  NSClipView*        clipView = (NSClipView*)   [self superview];
  NSPoint location = [clipView convertPoint:[event locationInWindow] fromView:nil];
  if (!NSPointInRect(location, [clipView bounds]))
    [historyController displayPreviewImage:nil backgroundColor:nil];
  else
  {
    location = [self convertPoint:location fromView:clipView];
    int row = [self rowAtPoint:location];
    id item = (row >= 0) && (row < [self numberOfRows]) ? [[HistoryManager sharedManager] itemAtIndex:row tableView:self] : nil;
    NSImage* image = nil;
    NSColor* backgroundColor = nil;
    image = [item pdfImage];
    backgroundColor = [item backgroundColor];
    [historyController displayPreviewImage:image backgroundColor:backgroundColor];
  }
}

@end
