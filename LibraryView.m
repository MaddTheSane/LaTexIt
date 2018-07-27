//  LibraryView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.

//This the library outline view, with some added methods to manage the selection

#import "LibraryView.h"

#import "AppController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LatexitEquation.h"
#import "LaTeXProcessor.h"
#import "LibraryCell.h"
#import "LibraryController.h"
#import "LibraryWindowController.h"
#import "LibraryEquation.h"
#import "LibraryGroupItem.h"
#import "LibraryItem.h"
#import "LibraryManager.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSMutableArrayExtended.h"
#import "NSObjectTreeNode.h"
#import "NSOutlineViewExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "PreferencesController.h"

@interface LibraryView (PrivateAPI)
-(NSImage*) iconForRepresentedObject:(id)representedObject;
-(void)     activateSelectedItem;
@end

@implementation LibraryView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self->libraryRowType = LIBRARY_ROW_IMAGE_AND_TEXT;
  [self setVerticalMotionCanBeginDrag:YES];
  return self;
}
//end initWithCoder:

-(void) awakeFromNib
{
  self->libraryController = [[LibraryController alloc] init];
  [self setDelegate:self];
  [self setDataSource:self->libraryController];

  [self bind:@"libraryRowType" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:LibraryViewRowTypeKey] options:nil];
  
  [self performSelector:@selector(expandOutlineItems) withObject:nil afterDelay:0.];

  [[self window] setAcceptsMouseMovedEvents:YES]; //to allow library to detect mouse moved events
  [self registerForDraggedTypes:[NSArray arrayWithObjects:LibraryItemsWrappedPboardType, LibraryItemsArchivedPboardType, LatexitEquationsPboardType, NSFilenamesPboardType, NSColorPboardType, nil]];
}
//end awakeFromNib

-(void) dealloc
{
  [self->libraryController release];
  [super dealloc];
}
//end dealloc

-(LibraryController*) libraryController
{
  return self->libraryController;
}
//end libraryController

-(NSImage*) iconForRepresentedObject:(id)representedObject
{
  NSImage* result =
    [representedObject isKindOfClass:[LibraryEquation class]] ? [NSImage imageNamed:@"icon-file.png"] :
    [representedObject isKindOfClass:[LibraryGroupItem   class]] ? 
      (self->libraryRowType == LIBRARY_ROW_IMAGE_LARGE) ?
        [NSImage imageNamed:@"icon-folder-big.tiff"] :
        [NSImage imageNamed:@"icon-folder-small.png"] :
    nil;
  return result;
}
//end iconForRepresentedObject:

-(void) expandOutlineItems
{
  NSManagedObjectContext* managedObjectContext = [self->libraryController managedObjectContext];
  [managedObjectContext disableUndoRegistration];
  int row = 0;
  for (row = 0; row < [self numberOfRows]; ++row)
  {
    id itemAtRow = [self itemAtRow:row];
    if ([self isExpandable:itemAtRow])
    {
      if ([itemAtRow isExpanded])
        [self expandItem:itemAtRow];
    }//end if isExpandable
  }//end for each row
  [managedObjectContext enableUndoRegistration];
}
//end expandOutlineItems

-(library_row_t) libraryRowType
{
  return self->libraryRowType;
}
//end libraryRowType

-(void) setLibraryRowType:(library_row_t)type
{
  [self willChangeValueForKey:@"libraryRowType"];
  self->libraryRowType = type;
  [self reloadData];//force to redraw every item
  [self didChangeValueForKey:@"libraryRowType"];
}
//end setLibraryRowType:

-(BOOL) acceptsFirstMouse:(NSEvent*)theEvent //using the tableview does not need to activate the window first
{
  return YES;
}
//end acceptsFirstMouse:

-(void) rightMouseDown:(NSEvent*)theEvent
{
  NSMenu* popupMenu = [(LibraryWindowController*)[[self window] windowController] actionMenu];
  [NSMenu popUpContextMenu:popupMenu withEvent:theEvent forView:self];
}
//end rightMouseDown:

-(void) activateSelectedItem
{
  MyDocument* document = (MyDocument*)[AppController currentDocument];
  if (!document)
  {
    [[NSDocumentController sharedDocumentController] newDocument:self];
    document = (MyDocument*)[AppController currentDocument];
  }

  id selectedItem      = !document ? nil : [self selectedItem];
  if (selectedItem)
  {
    LibraryItem* selectedLibraryItem = selectedItem;
    if ([selectedLibraryItem isKindOfClass:[LibraryEquation class]])
    {
      LatexitEquation* previousDocumentState = [document latexitEquationWithCurrentStateTransient:YES];
      NSUndoManager* documentUndoManager = [document undoManager];
      [documentUndoManager beginUndoGrouping];
      [[documentUndoManager prepareWithInvocationTarget:document] applyLatexitEquation:previousDocumentState];
      [document applyLibraryEquation:(LibraryEquation*)selectedLibraryItem];
      [documentUndoManager setActionName:NSLocalizedString(@"Apply Library item", @"Apply Library item")];
      [documentUndoManager endUndoGrouping];
      [[document windowForSheet] makeKeyAndOrderFront:nil];
    }
    else if ([selectedLibraryItem isKindOfClass:[LibraryGroupItem class]])
    {
      if ([self isItemExpanded:selectedItem])
        [self collapseItem:selectedItem];
      else
        [self expandItem:selectedItem];
    }//end if (selectedItem)
  }//end if selected row
}
//end activateSelectedItem

-(void) mouseDown:(NSEvent*)theEvent
{
  self->willEdit = NO;
  if ([theEvent modifierFlags] & NSControlKeyMask)
  {
    NSMenu* popupMenu = [(LibraryWindowController*)[[self window] windowController] actionMenu];
    [NSMenu popUpContextMenu:popupMenu withEvent:theEvent forView:self];
  }
  else if ([theEvent modifierFlags] & (NSCommandKeyMask | NSShiftKeyMask))
    [super mouseDown:theEvent];
  else //if click without relevant modifiers
  {
    NSArray* previousSelectedItems = [self itemsAtRowIndexes:[self selectedRowIndexes]];
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    int row = [self rowAtPoint:point];
    id candidateToSelection = [self itemAtRow:row];
    if (![previousSelectedItems containsObject:candidateToSelection])
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

    if ([theEvent clickCount] == 1)
    {
      [super mouseDown:theEvent];
      NSPoint pointInView = [self convertPoint:[theEvent locationInWindow] fromView:nil];
      int row = [self rowAtPoint:pointInView];
      int column = [self columnAtPoint:pointInView];
      NSRect rect = ((row >= 0) && (column >= 0)) ? [self frameOfCellAtColumn:column row:row] : NSZeroRect;
      NSRect imageFrame = NSZeroRect;
      NSRect titleFrame = NSZeroRect;
      NSDivideRect(rect, &imageFrame, &titleFrame, 8+[self rowHeight], NSMinXEdge);
      self->willEdit &= ([previousSelectedItems count] == 1) &&
                        ([previousSelectedItems lastObject] == candidateToSelection) && NSPointInRect(pointInView, titleFrame);
    }
    else if ([theEvent clickCount] == 2)
      [self activateSelectedItem];
    else if ([theEvent clickCount] == 3)
    {
      [self edit:self];
      [[self window] makeKeyAndOrderFront:self];
    }
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(delayedEdit:) userInfo:nil repeats:NO];
  }//end if click without relevant modifiers
}
//end mouseDown:

-(void) delayedEdit:(NSTimer*)timer
{
  if (self->willEdit && [self selectedItem])
  {
    self->willEdit = NO;
    [self edit:self];
    [[self window] makeKeyAndOrderFront:self];
  }
}
//end delayedEdit:

-(void) scrollWheel:(NSEvent*)event
{
  [super scrollWheel:event];
  [self mouseMoved:event];//to trigger preview display
}
//end scrollWheel:

-(void) mouseMoved:(NSEvent*)event
{
  LibraryWindowController* libraryWindowController = (LibraryWindowController*)[[self window] windowController];
  NSClipView*   clipView   = (NSClipView*)   [self superview];
  NSPoint location = [clipView convertPoint:[event locationInWindow] fromView:nil];
  if (!NSPointInRect(location, [clipView bounds]))
    [libraryWindowController displayPreviewImage:nil backgroundColor:nil];
  else//if (NSPointInRect(location, [clipView bounds]))
  {
    location = [self convertPoint:location fromView:clipView];
    int row = [self rowAtPoint:location];
    id libraryItem = (row >= 0) && (row < [self numberOfRows]) ? [self itemAtRow:row] : nil;
    NSImage* image = nil;
    NSColor* backgroundColor = nil;
    if ([libraryItem isKindOfClass:[LibraryEquation class]])
    {
      LatexitEquation* equation = [(LibraryEquation*)libraryItem equation];
      image = [equation pdfCachedImage];
      backgroundColor = [equation backgroundColor];
    }//end if ([item isKindOfClass:[LibraryEquation class]])
    [libraryWindowController displayPreviewImage:image backgroundColor:backgroundColor];
  }//end if (NSPointInRect(location, [clipView bounds]))
  [super mouseMoved:event];
}
//end mouseMoved:

-(void) cancelOperation:(id)sender
{
  int editedRow = [self editedRow];
  if (editedRow >= 0)
  {
    LibraryItem* libraryItem = [self itemAtRow:editedRow];
    NSCell* cell = [[self tableColumnWithIdentifier:@"library"] dataCellForRow:editedRow];
    NSText* fieldEditor = [[self window] fieldEditor:NO forObject:cell];
    [fieldEditor setString:[libraryItem title]];
    [[self window] endEditingFor:cell];
    [[self window] makeFirstResponder:self];
  }
}
//end cancelOperation:

-(void) keyDown:(NSEvent*)theEvent
{
  unsigned short keyCode = [theEvent keyCode];
  if ((keyCode == 36) || (keyCode == 76))//enter or return
  {
    if ([self editedRow] < 0)
      [self edit:self];
  }
  else if (keyCode == 49) //space
    [self activateSelectedItem];
  else
    [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}
//end keyDown:

-(void) edit:(id)sender
{
  int selectedRow = [self selectedRow];
  if (selectedRow >= 0)
    [self editColumn:0 row:selectedRow withEvent:nil select:YES];
}
//end edit:

-(void) moveLeft:(id)sender
{
  id item = [self itemAtRow:[self selectedRow]];
  if (item)
  {
    if (![item isKindOfClass:[LibraryGroupItem class]] || ![self isItemExpanded:item])
      item = [item parent];
    else if ([self isItemExpanded:item])
      [self collapseItem:item];
  }
  [self selectItem:item byExtendingSelection:NO];
}
//end moveLeft:

-(void) moveRight:(id)sender
{
  id item = [self selectedItem];
  if (item && [item isKindOfClass:[LibraryGroupItem class]])
    [self expandItem:item];
}
//end moveRight:

-(void) moveDownAndModifySelection:(id)sender
{
  //selection to down
  NSUInteger lastSelectedRow   = [self selectedRow];
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
//end moveDownAndModifySelection:

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
//end moveUpAndModifySelection:

-(void) moveUp:(id)sender
{
  int selectedRow = [self selectedRow];
  if (selectedRow > 0)
    --selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}
//end moveUp:

-(void) moveDown:(id)sender
{
  int selectedRow = [self selectedRow];
  if ((selectedRow >= 0) && (selectedRow+1 < [self numberOfRows]))
    ++selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}
//end moveDown:

-(void) deleteBackward:(id)sender
{
  [self removeSelection:sender];
}
//end deleteBackward:

-(IBAction) removeSelection:(id)sender
{
  NSUndoManager* undoManager = [self->libraryController undoManager];
  [undoManager beginUndoGrouping];
  NSArray* selectedItems = [LibraryItem minimumNodeCoverFromItemsInArray:[self selectedItems] parentSelector:@selector(parent)];
  id nextSelectedItem = [[selectedItems lastObject] nextBrotherWithParentSelector:@selector(parent) childrenSelector:@selector(childrenOrdered) rootNodes:[self->libraryController rootItems]];
  nextSelectedItem = nextSelectedItem ? nextSelectedItem :
    [[selectedItems lastObject] prevBrotherWithParentSelector:@selector(parent) childrenSelector:@selector(childrenOrdered) rootNodes:[self->libraryController rootItems]];
  nextSelectedItem = nextSelectedItem ? nextSelectedItem : [[selectedItems lastObject] parent];
  unsigned int nbSelectedItems = [selectedItems count];
  NSMutableSet* parentOfSelectedItems = [NSMutableSet setWithCapacity:[selectedItems count]];
  NSEnumerator* enumerator = [selectedItems objectEnumerator];
  LibraryItem* libraryItem = nil;
  while((libraryItem = [enumerator nextObject]))
  {
    id parent = [libraryItem parent];
    [parentOfSelectedItems addObject:!parent ? [NSNull null] : parent];
  }
  [self->libraryController removeItems:selectedItems];
  enumerator = [parentOfSelectedItems objectEnumerator];
  id parent = nil;
  while((parent = [enumerator nextObject]))
  {
    if (parent == [NSNull null])
      [self->libraryController fixChildrenSortIndexesForParent:nil recursively:NO];
    else
      [self->libraryController fixChildrenSortIndexesForParent:(LibraryGroupItem*)libraryItem recursively:NO];
  }
  if (nbSelectedItems > 1)
    [undoManager setActionName:NSLocalizedString(@"Delete Library items", @"Delete Library items")];
  else if (nbSelectedItems)
    [undoManager setActionName:NSLocalizedString(@"Delete Library item", @"Delete Library item")];
  [undoManager endUndoGrouping];
  [[self->libraryController managedObjectContext] processPendingChanges];
  [self reloadData];
  [self sizeLastColumnToFit];
  [self selectItem:nextSelectedItem byExtendingSelection:NO];
}
//end removeSelection:

//prevents from selecting next line when finished editing
-(void)textDidEndEditing:(NSNotification*)notification
{
  id newTitle = [[[[notification object] string] copy] autorelease];
  LibraryItem* selectedItem = [self selectedItem];
  NSString* oldTitle = [selectedItem title];
  if (selectedItem && ![newTitle isEqualToString:oldTitle])
  {
    [selectedItem setTitle:newTitle];
    [[self->libraryController undoManager]
      setActionName:NSLocalizedString(@"Change Library item name", @"Change Library item name")];
  }//end if (![newTitle isEqualToString:oldTitle])
  [super textDidEndEditing:notification];
  if (selectedItem)
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:[self rowForItem:selectedItem]] byExtendingSelection:NO];
}
//end textDidEndEditing:

//we cannot end editing if a brother has the same name
-(BOOL) textShouldEndEditing:(NSText*)textObject
{
  LibraryItem* libraryItem = [self selectedItem];
  NSString* newTitle = [[[textObject string] copy] autorelease];
  [libraryItem setTitle:newTitle];
  return YES;
}
//end textShouldEndEditing:

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  NSUndoManager* undoManager = [self->libraryController undoManager];
  if ([sender action] == @selector(copy:))
    ok = ([self selectedRow] >= 0);
  else if ([sender action] == @selector(paste:))
    ok = ([[NSPasteboard generalPasteboard] availableTypeFromArray:
            [NSArray arrayWithObjects:LibraryItemsWrappedPboardType, LibraryItemsArchivedPboardType, LatexitEquationsPboardType, NSPDFPboardType, nil]] != nil);
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
//end validateMenuItem:

#pragma mark undo/redo

-(IBAction) undo:(id)sender
{
  NSManagedObjectContext* managedObjectContext = [self->libraryController managedObjectContext];
  NSUndoManager* undoManager = [self->libraryController undoManager];
  if ([undoManager canUndo])
  {
    [managedObjectContext undo];
    [managedObjectContext processPendingChanges];
    [self reloadData];
    [self sizeLastColumnToFit];
  }
}
//end undo:

-(IBAction) redo:(id)sender
{
  NSManagedObjectContext* managedObjectContext = [self->libraryController managedObjectContext];
  NSUndoManager* undoManager = [self->libraryController undoManager];
  if ([undoManager canRedo])
  {
    [managedObjectContext redo];
    [managedObjectContext processPendingChanges];
    [self reloadData];
    [self sizeLastColumnToFit];
  }
}
//end redo:

#pragma mark copy/paste

-(IBAction) copy:(id)sender
{
  NSPasteboard* pasteBoard = [NSPasteboard generalPasteboard];
  NSArray* selectedItems = [self selectedItems];
  if ([selectedItems count])
  {
    [[self dataSource] outlineView:self writeItems:selectedItems toPasteboard:pasteBoard];
    [pasteBoard setPropertyList:nil forType:LibraryItemsWrappedPboardType];//this pboard must be persistent
  }//end if ([selectedItems count])
}
//end copy:

-(IBAction) cut:(id)sender
{
  NSArray* selectedItems = [self selectedItems];
  if ([selectedItems count])
  {
    NSPasteboard* pasteBoard = [NSPasteboard generalPasteboard];
    [[self dataSource] outlineView:self writeItems:selectedItems toPasteboard:pasteBoard];
    [pasteBoard setPropertyList:nil forType:LibraryItemsWrappedPboardType];
    [self->libraryController removeItems:selectedItems];
    [[self->libraryController managedObjectContext] processPendingChanges];
    [self reloadData];
    [[self->libraryController undoManager] setActionName:NSLocalizedString(@"Delete Library items", @"Delete Library items")];
  }//end if ([selectedItems count])
}
//end cut:

//may paste data in the document
-(IBAction) paste:(id)sender
{
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  LibraryItem* selectedItem = [self selectedItem];
  LibraryGroupItem* parentOfSelectedItem = (LibraryGroupItem*)[selectedItem parent];
  NSArray* brothers = !parentOfSelectedItem ? [self->libraryController rootItems] : [parentOfSelectedItem childrenOrdered];
  int childIndex = !selectedItem ? [[self dataSource] outlineView:self numberOfChildrenOfItem:nil] :
                   ((int)[brothers indexOfObject:selectedItem]+1);
  [self pasteContentOfPasteboard:pasteboard onItem:parentOfSelectedItem childIndex:childIndex];
}
//end paste:

-(BOOL) pasteContentOfPasteboard:(NSPasteboard*)pasteboard onItem:(id)item childIndex:(int)index
{
  BOOL result = NO;
  
  NSUndoManager* undoManager = [self->libraryController undoManager];
  [undoManager beginUndoGrouping];
  
  NSMutableArray* libraryItems = nil;
  NSArray* wrappedItems = ![pasteboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsWrappedPboardType]] ? nil :
    [pasteboard propertyListForType:LibraryItemsWrappedPboardType];  
  if (wrappedItems)
  {
    NSArray* wrappedItems = [pasteboard propertyListForType:LibraryItemsWrappedPboardType];
    libraryItems = [NSMutableArray arrayWithCapacity:[wrappedItems count]];
    NSEnumerator* enumerator = [wrappedItems objectEnumerator];
    NSString* objectIDAsString = nil;
    while((objectIDAsString = [enumerator nextObject]))
    {
      NSManagedObject* libraryItem = [[libraryController managedObjectContext] managedObjectForURIRepresentation:[NSURL URLWithString:objectIDAsString]];
      if (libraryItem)
        [libraryItems addObject:libraryItem];
    }
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsArchivedPboardType]])
  {
    [LatexitEquation pushManagedObjectContext:[self->libraryController managedObjectContext]];
    NSArray* unarchivedLibraryItems = [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:LibraryItemsArchivedPboardType]];
    libraryItems = [NSMutableArray arrayWithArray:
      [LibraryItem minimumNodeCoverFromItemsInArray:unarchivedLibraryItems parentSelector:@selector(parent)]];
    [LatexitEquation popManagedObjectContext];
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:LatexitEquationsPboardType]])
  {
    NSArray* latexitEquations = [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:LatexitEquationsPboardType]];
    libraryItems = [NSMutableArray arrayWithCapacity:[latexitEquations count]];
    NSEnumerator* enumerator = [latexitEquations objectEnumerator];
    LatexitEquation* latexitEquation = nil;
    while((latexitEquation = [enumerator nextObject]))
    {
      LibraryEquation* libraryEquation =
        [[LibraryEquation alloc] initWithParent:nil equation:latexitEquation insertIntoManagedObjectContext:[self->libraryController managedObjectContext]];
      if (libraryEquation)
      {
        [libraryItems addObject:libraryEquation];
        [libraryEquation release];
      }//end if (libraryEquation)
    }//end for each latexitEquation
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObjects:NSPDFPboardType, @"com.adobe.pdf", nil]])
  {
    NSData* pdfData = [pasteboard dataForType:NSPDFPboardType];
    if (!pdfData)
      pdfData = [pasteboard dataForType:@"com.adobe.pdf"];
    if (pdfData)
    {
      LatexitEquation* latexitEquation = [[LatexitEquation alloc] initWithPDFData:pdfData useDefaults:YES];
      LibraryEquation* libraryEquation =
        [[LibraryEquation alloc] initWithParent:nil equation:latexitEquation insertIntoManagedObjectContext:[self->libraryController managedObjectContext]];
      if (libraryEquation)
      {
        libraryItems = [NSArray arrayWithObject:libraryEquation];
        [libraryEquation release];
      }//end if (libraryEquation)
      [latexitEquation release];
    }//end if (pdfData)
  }//end if NSPDFPboardType

  NSUInteger count = [libraryItems count];
  if (count)
  {
    NSMutableArray* brothers = [NSMutableArray arrayWithArray:
      !item ? [self->libraryController rootItems] : [item childrenOrdered]];
    NSEnumerator* enumerator = [libraryItems objectEnumerator];
    LibraryItem* libraryItem = nil;
    while((libraryItem = [enumerator nextObject]))
    {
      NSUInteger found = [brothers indexOfObject:libraryItem];
      if (found != NSNotFound)
      {
        [brothers removeObjectAtIndex:found];
        if (wrappedItems && (index != NSOutlineViewDropOnItemIndex) && (found<(unsigned)index))//for a move, take care of indices
          --index;
      }
    }//end for each "new" libraryItem
    [brothers insertObjectsFromArray:libraryItems atIndex:(index == NSOutlineViewDropOnItemIndex) ?
      [brothers count] : (unsigned)index];
    NSUInteger nbBrothers = [brothers count];
    while(nbBrothers--)
      [[brothers objectAtIndex:nbBrothers] setSortIndex:nbBrothers];
    enumerator = [libraryItems objectEnumerator];
    while((libraryItem = [enumerator nextObject]))
    {
      [libraryItem setParent:item];
      if (item)
        [self expandItem:item];
      if (!wrappedItems)//wrapped items are a move : do not change name !
        [libraryItem setBestTitle];
    }
    [[self->libraryController managedObjectContext] processPendingChanges];
    [self reloadData];
    [self sizeLastColumnToFit];
    [undoManager setActionName:(count > 1) ?
      NSLocalizedString(@"Add Library items", @"Add Library items") :
      NSLocalizedString(@"Add Library item", @"Add Library item")];
    [self selectItems:libraryItems byExtendingSelection:NO];
    result = YES;
  }//end if (count)
  
  [undoManager endUndoGrouping];
  
  return result;
}
//end pasteContentOfPasteboard:

#pragma mark drag'n drop

-(NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  NSDragOperation result = isLocal ? NSDragOperationEvery : NSDragOperationCopy;
  return result;
}
//end draggingSourceOperationMaskForLocal:

#pragma mark delegate

-(CGFloat) outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
  CGFloat height = 16;
  if (item && ([(LibraryView*)outlineView libraryRowType] == LIBRARY_ROW_IMAGE_LARGE) &&
      ![item isKindOfClass:[LibraryGroupItem class]])
    height = 34;
  return height;
}
//end outlineView:heightOfRowByItem:

-(BOOL) outlineView:(NSOutlineView*)outlineView shouldEditTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
  BOOL result = NO;
  //disables preview image while editing. See in textDidEndEditing of LibraryView to re-enable it
  LibraryWindowController* libraryWindowController = (LibraryWindowController*)[[outlineView window] windowController];
  [libraryWindowController displayPreviewImage:nil backgroundColor:nil];
  result = (self->libraryRowType != LIBRARY_ROW_IMAGE_LARGE) || [item isKindOfClass:[LibraryGroupItem class]];
  self->willEdit = result;
  return result;
}
//end outlineView:shouldEditTableColumn:item:

-(BOOL) outlineView:(NSOutlineView*)outlineView shouldCollapseItem:(id)item
{
  NSManagedObjectContext* managedObjectContext = [self->libraryController managedObjectContext];
  [managedObjectContext disableUndoRegistration];
  [item setExpanded:NO];
  [managedObjectContext enableUndoRegistration];
  return YES;
}
//end outlineView:shouldCollapseItem:

-(BOOL) outlineView:(NSOutlineView*)outlineView shouldExpandItem:(id)item
{
  NSManagedObjectContext* managedObjectContext = [self->libraryController managedObjectContext];
  [managedObjectContext disableUndoRegistration];
  [item setExpanded:YES];
  [managedObjectContext enableUndoRegistration];
  return YES;
}
//end outlineView:shouldExpandItem:

-(void) outlineViewSelectionDidChange:(NSNotification*)notification
{
  NSOutlineView* outlineView = [notification object];
  [outlineView scrollRowToVisible:[[outlineView selectedRowIndexes] firstIndex]];
}
//end outlineViewSelectionDidChange:

-(void) outlineView:(NSOutlineView*)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
  LibraryView* libraryTableView = (LibraryView*)outlineView;
  id representedObject = item;
  library_row_t currentLibraryRowType = [libraryTableView libraryRowType];
  NSImage* cellImage           = nil;
  NSColor* cellTextBackgroundColor = nil;
  BOOL     cellDrawsBackground = NO;
  NSColor* cellTextColor = nil;
  if (currentLibraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
  {
    NSString* title = [representedObject title];
    [cell setStringValue:!title ? @"" : title];
    cellImage = [self iconForRepresentedObject:representedObject];
    cellDrawsBackground = YES;
  }
  else if (![representedObject isKindOfClass:[LibraryGroupItem class]])
  {
    [cell setStringValue:@""];
    cellDrawsBackground = NO;
  }
  if ([representedObject isKindOfClass:[LibraryEquation class]])
  {
    LatexitEquation* latexitEquation = [(LibraryEquation*)representedObject equation];
    cellImage = (currentLibraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT) ? nil : [latexitEquation pdfCachedImage];
    cellTextBackgroundColor = [latexitEquation backgroundColor];
    NSColor* greyLevelColor  = [cellTextBackgroundColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
    cellDrawsBackground = (cellTextBackgroundColor != nil) && ([greyLevelColor whiteComponent] != 1.0f);
    if ((currentLibraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT) && ![cell isHighlighted])
      cellTextColor = [latexitEquation color];
  }
  else if ([representedObject isKindOfClass:[LibraryGroupItem class]])
    cellImage = [self iconForRepresentedObject:representedObject];
  else
    cellImage = [self iconForRepresentedObject:representedObject];
  [cell setImage:cellImage];
  [cell setImageBackgroundColor:cellTextBackgroundColor];
  [cell setTextBackgroundColor:cellTextBackgroundColor];
  //[cell setTextColor:!cellTextColor ? [NSColor textColor] : cellTextColor];
  [cell setDrawsBackground:cellDrawsBackground && cellTextBackgroundColor];
}
//end outlineView:willDisplayCell:forTableColumn:item:

@end
