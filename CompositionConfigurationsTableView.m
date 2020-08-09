//
//  CompositionConfigurationsTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/03/06.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationsTableView.h"

#import "NSArrayControllerExtended.h"
#import "CompositionConfigurationsController.h"
#import "BoolTransformer.h"
#import "PreferencesController.h"

static NSPasteboardType const CompositionConfigurationsPboardType = @"CompositionConfigurationsPboardType";

@interface CompositionConfigurationsTableView ()
-(void) textDidEndEditing:(NSNotification *)aNotification;
@end

@implementation CompositionConfigurationsTableView

-(instancetype) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self.delegate = self;
  self.dataSource = self;
  [[self tableColumnWithIdentifier:@"name"] bind:NSValueBinding toObject:[[PreferencesController sharedController] compositionConfigurationsController]
    withKeyPath:[@"arrangedObjects." stringByAppendingString:CompositionConfigurationNameKey] options:nil];
  [[self tableColumnWithIdentifier:@"name"] bind:NSTextColorBinding toObject:[[PreferencesController sharedController] compositionConfigurationsController]
    withKeyPath:[@"arrangedObjects." stringByAppendingString:CompositionConfigurationIsDefaultKey]
        options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSColor blackColor] trueValue:[NSColor grayColor]]}];
  [self registerForDraggedTypes:@[CompositionConfigurationsPboardType]];
  return self;
}
//end initWithCoder:

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
  NSInteger row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}
//end acceptsFirstMouse:

-(void) keyDown:(NSEvent*)theEvent
{
  [super interpretKeyEvents:@[theEvent]];
  if ((theEvent.keyCode == 36) || (theEvent.keyCode == 52) || (theEvent.keyCode == 49))//Enter, space or ?? What did I do ???
    [self edit:self];
}
//end keyDown:

//edit selected row
-(IBAction) edit:(id)sender
{
  NSInteger selectedRow = self.selectedRow;
  if (selectedRow >= 0)
    [self editColumn:0 row:selectedRow withEvent:nil select:YES];
}
//end edit:

-(IBAction) undo:(id)sender
{
  [[[PreferencesController sharedController] undoManager] undo];
}
//end undo;

-(IBAction) redo:(id)sender
{
  [[[PreferencesController sharedController] undoManager] redo];
}
//end redo:

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  NSUndoManager* undoManager = [[PreferencesController sharedController] undoManager];
  if (sender.action == @selector(undo:))
  {
    ok = undoManager.canUndo;
    [sender setTitleWithMnemonic:undoManager.undoMenuItemTitle];
  }
  else if (sender.action == @selector(redo:))
  {
    ok = undoManager.canRedo;
    [sender setTitleWithMnemonic:undoManager.redoMenuItemTitle];
  }
  return ok;
}
//end validateMenuItem:

-(void) deleteBackward:(id)sender
{
  [[[PreferencesController sharedController] compositionConfigurationsController] remove:sender];
}
//end deleteBackward:

-(void) moveUp:(id)sender
{
  NSInteger selectedRow = self.selectedRow;
  if (selectedRow > 0)
    --selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}
//end moveUp:

-(void) moveDown:(id)sender
{
  NSInteger selectedRow = self.selectedRow;
  if ((selectedRow >= 0) && (selectedRow+1 < self.numberOfRows))
    ++selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}
//end moveDown:

//prevents from selecting next line when finished editing
-(void) textDidEndEditing:(NSNotification *)aNotification
{
  NSInteger selectedRow = self.selectedRow;
  [super textDidEndEditing:aNotification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}
//end textDidEndEditing:

#pragma mark delegate
-(void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSUInteger lastIndex = self.selectedRowIndexes.lastIndex;
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
  CompositionConfigurationsController* compositionConfigurationsController = [[PreferencesController sharedController] compositionConfigurationsController];
  NSArray* compositionConfigurationsSelected = compositionConfigurationsController.selectedObjects;
  [pboard declareTypes:@[CompositionConfigurationsPboardType] owner:self];  
  [pboard setPropertyList:[NSKeyedArchiver archivedDataWithRootObject:compositionConfigurationsSelected] forType:CompositionConfigurationsPboardType];
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
            [pboard availableTypeFromArray:@[CompositionConfigurationsPboardType]] &&
            [pboard propertyListForType:CompositionConfigurationsPboardType] &&
            (operation == NSTableViewDropAbove) &&
            indexSet && (indexSet.firstIndex != (NSUInteger)row) && (indexSet.firstIndex+1 != (NSUInteger)row);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
  NSArrayController* compositionConfigurationsController = [[PreferencesController sharedController] compositionConfigurationsController];
  NSIndexSet* indexSet = [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  [compositionConfigurationsController moveObjectsAtIndices:indexSet toIndex:row];
  self->draggedRowIndexes = nil;
  return YES;
}
//end tableView:acceptDrop:row:dropOperation:

@end
