//
//  ServiceRegularExpressionFiltersTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/01/13.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "ServiceRegularExpressionFiltersTableView.h"

#import "NSArrayControllerExtended.h"
#import "PreferencesController.h"
#import "ServiceRegularExpressionFiltersController.h"

static NSString* RegularExpressionFilterPboardType = @"RegularExpressionFilterPboardType";

@interface ServiceRegularExpressionFiltersTableView (PrivateAPI)
-(ServiceRegularExpressionFiltersController*) serviceRegularExpressionFiltersController;
@end

@implementation ServiceRegularExpressionFiltersTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  [self setDelegate:(id)self];
  [self setDataSource:(id)self];
  NSArrayController* serviceRegularExpressionFiltersController = [self serviceRegularExpressionFiltersController];
  [[self tableColumnWithIdentifier:@"enabled"] bind:NSValueBinding toObject:serviceRegularExpressionFiltersController withKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterEnabledKey] options:nil];
  [[self tableColumnWithIdentifier:@"inputPattern"] bind:NSValueBinding toObject:serviceRegularExpressionFiltersController withKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterInputPatternKey] options:nil];
  [[self tableColumnWithIdentifier:@"outputPattern"] bind:NSValueBinding toObject:serviceRegularExpressionFiltersController withKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterOutputPatternKey] options:nil];

  [self registerForDraggedTypes:[NSArray arrayWithObject:RegularExpressionFilterPboardType]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [[self tableColumnWithIdentifier:@"enabled"] unbind:NSValueBinding];
  [[self tableColumnWithIdentifier:@"inputPattern"] unbind:NSValueBinding];
  [[self tableColumnWithIdentifier:@"outputPattern"] unbind:NSValueBinding];
  [super dealloc];
}
//end dealloc

-(ServiceRegularExpressionFiltersController*) serviceRegularExpressionFiltersController
{
  ServiceRegularExpressionFiltersController* result = [[PreferencesController sharedController] serviceRegularExpressionFiltersController];
  return result;
}
//end serviceRegularExpressionsController

-(NSArray*) regularExpressionFilters
{
  NSArray* result = [[self serviceRegularExpressionFiltersController] arrangedObjects];
  return result;
}
//end regularExpressionFilters

#pragma mark observer

#pragma mark events

-(BOOL) acceptsFirstMouse:(NSEvent*)event //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
  NSInteger row = [self rowAtPoint:point];
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
  NSInteger selectedRow = [self selectedRow];
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
    [sender setTitle:[undoManager undoMenuItemTitle]];
  }//end if ([sender action] == @selector(undo:))
  else if ([sender action] == @selector(redo:))
  {
    ok = [undoManager canRedo];
    [sender setTitle:[undoManager redoMenuItemTitle]];
  }//end if ([sender action] == @selector(redo:))
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
  NSInteger selectedRow = [self selectedRow];
  if (selectedRow > 0)
    --selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}
//end moveUp:

-(void) moveDown:(id)sender
{
  NSInteger selectedRow = [self selectedRow];
  if ((selectedRow >= 0) && (selectedRow+1 < [self numberOfRows]))
    ++selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}
//end moveDown:

//prevents from selecting next line when finished editing
-(void) textDidEndEditing:(NSNotification*)notification
{
  NSInteger selectedRow = [self selectedRow];
  [super textDidEndEditing:notification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}
//end textDidEndEditing:

#pragma mark add files

-(IBAction) addRegularExpressionFilter:(id)sender
{
  NSArray* regularExpressionFilters = [NSArray array];
  [[self serviceRegularExpressionFiltersController] addObjects:regularExpressionFilters];
}
//end addRegularExpressionFilter:

#pragma mark delegate

-(void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSUInteger lastIndex = [[self selectedRowIndexes] lastIndex];
  [self scrollRowToVisible:lastIndex];
}
//end tableViewSelectionDidChange:

-(void) tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
}
//end tableView:willDisplayCell:forTableColumn:row:

#pragma mark dummy datasource (real datasource is a binding, just avoid warnings)

-(NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView {return 0;}
-(id)        tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex {return nil;}
-(void)      tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex {}

#pragma mark drag'n drop

-(NSIndexSet*) _draggedRowIndexes //utility method to access draggedItems when working with pasteboard sender
{
  return self->draggedRowIndexes;
}
//end _draggedRowIndexes

-(BOOL) tableView:(NSTableView*)aTableView writeRowsWithIndexes:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
  //we put the moving rows in pasteboard
  self->draggedRowIndexes = rowIndexes;
  NSArrayController* serviceRegularExpressionsController = [self serviceRegularExpressionFiltersController];
  NSArray* serviceRegularExpressionsControllerSelected = [serviceRegularExpressionsController selectedObjects];
  [pboard declareTypes:[NSArray arrayWithObject:RegularExpressionFilterPboardType] owner:self];  
  [pboard setPropertyList:serviceRegularExpressionsControllerSelected forType:RegularExpressionFilterPboardType];
  return YES;
}
//end tableView:writeRowsWithIndexes:toPasteboard:

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard* pboard = [info draggingPasteboard];
  NSIndexSet* indexSet =  [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  BOOL ok = pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:RegularExpressionFilterPboardType]] &&
            [pboard propertyListForType:RegularExpressionFilterPboardType] &&
            (operation == NSTableViewDropAbove) &&
            (!indexSet || (indexSet && ([indexSet firstIndex] != (NSUInteger)row) && ([indexSet firstIndex]+1 != (NSUInteger)row)));
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
  NSArrayController* serviceRegularExpressionFiltersController = [self serviceRegularExpressionFiltersController];
  NSIndexSet* indexSet = [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  if (indexSet)
    [serviceRegularExpressionFiltersController moveObjectsAtIndices:indexSet toIndex:row];
  else
  {
    NSPasteboard* pasteboard = [info draggingPasteboard];
    [serviceRegularExpressionFiltersController addObjects:[pasteboard propertyListForType:RegularExpressionFilterPboardType]];
  }
  self->draggedRowIndexes = nil;
  return YES;
}
//end tableView:acceptDrop:row:dropOperation:

@end
