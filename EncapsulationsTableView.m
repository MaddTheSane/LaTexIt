//
//  EncapsulationsTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.

//EncapsulationsTableView presents custom encapsulations from an encapsulation manager. I has user friendly capabilities

#import "EncapsulationsTableView.h"

#import "EncapsulationsController.h"
#import "IndexToIndexesTransformer.h"
#import "NSArrayControllerExtended.h"
#import "PreferencesController.h"

static NSString* EncapsulationsPboardType = @"EncapsulationsPboardType";

@interface EncapsulationsTableView (PrivateAPI)
-(NSIndexSet*) _draggedRowIndexes; //utility method to access draggedItems when working with pasteboard sender
@end

@implementation EncapsulationsTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  [self setDelegate:(id)self];
  [self setDataSource:(id)self];
  [[self tableColumnWithIdentifier:@"encapsulations"] bind:NSValueBinding toObject:[[PreferencesController sharedController] encapsulationsController] withKeyPath:@"arrangedObjects.string" options:nil];

  [self registerForDraggedTypes:[NSArray arrayWithObject:EncapsulationsPboardType]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [super dealloc];
}
//end dealloc

#pragma mark events

-(BOOL) acceptsFirstMouse:(NSEvent*)event //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
  int row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}
//end acceptsFirstMouse:

-(void) keyDown:(NSEvent*)event
{
  [super interpretKeyEvents:[NSArray arrayWithObject:event]];
  if (([event keyCode] == 36) || ([event keyCode] == 52) || ([event keyCode] == 49))//Enter, space or ?? What did I do ???
    [self edit:self];
}
//end keyDown:

//edit selected row
-(IBAction) edit:(id)sender
{
  int selectedRow = [self selectedRow];
  if (selectedRow >= 0)
    [self editColumn:0 row:selectedRow withEvent:nil select:YES];
}
//end edit:

-(IBAction) undo:(id)sender
{
  [[[PreferencesController sharedController] undoManager] undo];
}
//end undo:

-(IBAction) redo:(id)sender
{
  [[[PreferencesController sharedController] undoManager] redo];
}
//end redo:

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  NSUndoManager* undoManager = [[PreferencesController sharedController] undoManager];
  if ([sender action] == @selector(undo:))
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

-(void) deleteBackward:(id)sender
{
  [[[PreferencesController sharedController] encapsulationsController] remove:sender];
}
//end deleteBackward:

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

//prevents from selecting next line when finished editing
-(void) textDidEndEditing:(NSNotification*)notification
{
  int selectedRow = [self selectedRow];
  [super textDidEndEditing:notification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}
//end textDidEndEditing:

//delegate methods
-(void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
  unsigned int lastIndex = [[self selectedRowIndexes] lastIndex];
  [self scrollRowToVisible:lastIndex];
}
//end tableViewSelectionDidChange:

#pragma mark dummy datasource (real datasource is a binding, just avoid warnings)

-(NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView {return 0;}
-(id)        tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex {return nil;}
-(void)      tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex {}

#pragma mark drag'n drop
//drag'n drop for moving rows

-(NSIndexSet*) _draggedRowIndexes //utility method to access draggedItems when working with pasteboard sender
{
  return self->draggedRowIndexes;
}
//end _draggedRowIndexes

-(BOOL) tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
  //we put the moving rows in pasteboard
  self->draggedRowIndexes = rowIndexes;
  EncapsulationsController* encapsulationsController = [[PreferencesController sharedController] encapsulationsController];
  NSArray* encapsulationsSelected = [encapsulationsController selectedObjects];
  [pboard declareTypes:[NSArray arrayWithObject:EncapsulationsPboardType] owner:self];  
  [pboard setPropertyList:[NSKeyedArchiver archivedDataWithRootObject:encapsulationsSelected] forType:EncapsulationsPboardType];
  return YES;
}
//end tableView:writeRowsWithIndexes:toPasteboard:

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  //we only accept moving inside the table (not between different ones)
  NSPasteboard* pboard = [info draggingPasteboard];
  NSIndexSet* indexSet =  [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  BOOL ok = (tableView == [info draggingSource]) && pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:EncapsulationsPboardType]] &&
            [pboard propertyListForType:EncapsulationsPboardType] &&
            (operation == NSTableViewDropAbove) &&
            indexSet && ([indexSet firstIndex] != (unsigned int)row) && ([indexSet firstIndex]+1 != (unsigned int)row);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
  NSArrayController* encapsulationsController = [[PreferencesController sharedController] encapsulationsController];
  NSIndexSet* indexSet = [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  [encapsulationsController moveObjectsAtIndices:indexSet toIndex:row];
  self->draggedRowIndexes = nil;
  return YES;
}
//end tableView:acceptDrop:row:dropOperation:

@end
