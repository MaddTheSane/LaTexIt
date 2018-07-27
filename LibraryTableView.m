//  LibraryTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This the library outline view, with some added methods to manage the selection

#import "LibraryTableView.h"

#import "AppController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LibraryCell.h"
#import "LibraryController.h"
#import "LibraryFile.h"
#import "LibraryItem.h"
#import "LibraryManager.h"
#import "MyImageView.h"
#import "NSColorExtended.h"

@interface LibraryTableView (PrivateAPI)
-(void) _libraryDidChange:(NSNotification*)aNotification;
@end

@implementation LibraryTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  libraryRowType = LIBRARY_ROW_IMAGE_AND_TEXT;
  return self;
}

-(void) awakeFromNib
{
  [[self window] setAcceptsMouseMovedEvents:YES]; //to allow library to detect mouse moved events
  [self registerForDraggedTypes:[NSArray arrayWithObjects:LibraryItemsPboardType, HistoryItemsPboardType, NSColorPboardType, nil]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_libraryDidChange:)
                                               name:LibraryDidChangeNotification object:nil];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(library_row_t) libraryRowType
{
  return libraryRowType;
}

-(void) setLibraryRowType:(library_row_t)type
{
  libraryRowType = type;
  //Tiger will use outlineView:heightOfRowByItem:
  #ifdef PANTHER
  switch(libraryRowType)
  {
    case LIBRARY_ROW_IMAGE_AND_TEXT:
      [self setRowHeight:17];
      [self setIndentationPerLevel:16];
      break;
    case LIBRARY_ROW_IMAGE_LARGE:
      [self setRowHeight:34];
      [self setIndentationPerLevel:34];
      break;
  }
  #endif
  [self reloadData];
  [self setNeedsDisplay:YES];
}

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  int row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}

-(void) rightMouseDown:(NSEvent*)theEvent
{
  NSMenu* popupMenu = [(LibraryController*)[[self window] windowController] actionMenu];
  [NSMenu popUpContextMenu:popupMenu withEvent:theEvent forView:self];
}

-(void) mouseDown:(NSEvent*)theEvent
{
  if ([theEvent modifierFlags] & NSControlKeyMask)
  {
    NSMenu* popupMenu = [(LibraryController*)[[self window] windowController] actionMenu];
    [NSMenu popUpContextMenu:popupMenu withEvent:theEvent forView:self];
  }
  else
    [super mouseDown:theEvent];
}

-(void) scrollWheel:(NSEvent*)event
{
  [super scrollWheel:event];
  [self mouseMoved:event];//to trigger preview display
}

-(void) mouseMoved:(NSEvent*)event
{
  LibraryController* libraryController = (LibraryController*)[[self window] windowController];
  NSClipView*   clipView   = (NSClipView*)   [self superview];
  NSPoint location = [clipView convertPoint:[event locationInWindow] fromView:nil];
  if (!NSPointInRect(location, [clipView bounds]))
    [libraryController displayPreviewImage:nil backgroundColor:nil];
  else
  {
    location = [self convertPoint:location fromView:clipView];
    int row = [self rowAtPoint:location];
    id item = (row >= 0) && (row < [self numberOfRows]) ? [self itemAtRow:row] : nil;
    NSImage* image = nil;
    NSColor* backgroundColor = nil;
    if ([item isKindOfClass:[LibraryFile class]])
    {
      HistoryItem* historyItem = [(LibraryFile*)item value];
      image = [historyItem pdfImage];
      backgroundColor = [historyItem backgroundColor];
    }
    [libraryController displayPreviewImage:image backgroundColor:backgroundColor];
  }
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
  if (([theEvent keyCode] == 36) || ([theEvent keyCode] == 52) || ([theEvent keyCode] == 49))//Enter, space or ?? What did I do ???
    [self edit:self];
}

-(void) edit:(id)sender
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
  LibraryController* libraryController = (LibraryController*)[[self window] windowController];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [libraryController setEnablePreviewImage:[userDefaults boolForKey:LibraryDisplayPreviewPanelKey]];
}

//we cannot end editing if a brother has the same name
-(BOOL) textShouldEndEditing:(NSText *)textObject
{
  LibraryItem* item = [self itemAtRow:[self selectedRow]];
  NSString* oldTitle = [item title];
  [item setTitle:[textObject string]];
  BOOL shouldChange = [item updateTitle];
  [item setTitle:oldTitle];
  return !shouldChange;
}

//drag'n drop
-(NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  return isLocal ? NSDragOperationEvery : NSDragOperationCopy;
}

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  NSUndoManager* undoManager = [[LibraryManager sharedManager] undoManager];
  if ([sender action] == @selector(copy:))
    ok = ([self selectedRow] >= 0);
  else if ([sender action] == @selector(paste:))
    ok = ([[NSPasteboard generalPasteboard] availableTypeFromArray:
            [NSArray arrayWithObjects:LibraryItemsPboardType, HistoryItemsPboardType, NSPDFPboardType, nil]] != nil);
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

-(IBAction) undo:(id)sender
{
  [[[LibraryManager sharedManager] undoManager] undo];
}

-(IBAction) redo:(id)sender
{
  [[[LibraryManager sharedManager] undoManager] redo];
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
  MyDocument* document = (MyDocument*) [AppController currentDocument];
  if (!document)
    document = [[AppController appController] dummyDocument];
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
    LibraryItem* lastItem = [libraryItems lastObject];
    if (lastItem)
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowForItem:lastItem]] byExtendingSelection:NO];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:HistoryItemsPboardType]])
  {
    NSArray* historyItems = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:HistoryItemsPboardType]];
    NSEnumerator* enumerator = [historyItems objectEnumerator];
    HistoryItem* historyItem = [enumerator nextObject];
    LibraryItem* libraryLastItem = nil;
    while(historyItem)
    {
      libraryLastItem = [[LibraryManager sharedManager] newFile:historyItem outlineView:self];
      historyItem = [enumerator nextObject];
    }
    if (libraryLastItem)
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowForItem:libraryLastItem]] byExtendingSelection:NO];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
  {
    NSData* pdfData = [pboard dataForType:NSPDFPboardType];
    if (pdfData)
    {
      [document applyPdfData:pdfData];
      HistoryItem* item = [document historyItemWithCurrentState];
      LibraryItem* libraryItem = [[LibraryManager sharedManager] newFile:item outlineView:self];
      if (libraryItem)
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowForItem:libraryItem]] byExtendingSelection:NO];
    }
  }
}

/*
-(NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
  BOOL ok = NO;
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
  {
    NSPoint locationInWindow = [sender draggingLocation];
    id item = [self itemAtRow:[self rowAtPoint:[self convertPoint:locationInWindow fromView:nil]]];
    ok = [item isKindOfClass:[LibraryFile class]];
  }
  return ok ? NSDragOperationCopy : NSDragOperationNone;
}

-(BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
  {
    NSPoint locationInWindow = [sender draggingLocation];
    id item = [self itemAtRow:[self rowAtPoint:[self convertPoint:locationInWindow fromView:nil]]];
    HistoryItem* historyItem = [item isKindOfClass:[LibraryFile class]] ? [(LibraryFile*)item value] : nil;
    NSColor* backgroundColor = [NSColor colorWithData:[pboard dataForType:NSColorPboardType]];
    [historyItem setBackgroundColor:backgroundColor];
  }
  return YES;
}
*/

@end
