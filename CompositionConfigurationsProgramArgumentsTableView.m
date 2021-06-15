//
//  CompositionConfigurationsProgramArgumentsTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/03/06.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationsProgramArgumentsTableView.h"

#import "CompositionConfigurationsProgramArgumentsController.h"
#import "NSArrayControllerExtended.h"
#import "PreferencesController.h"

static NSString* CompositionConfigurationsProgramArgumentsPboardType = @"CompositionConfigurationsProgramArgumentsPboardType";

@interface CompositionConfigurationsProgramArgumentsTableView (PrivateAPI)
-(void) textDidEndEditing:(NSNotification *)aNotification;
@end

@implementation CompositionConfigurationsProgramArgumentsTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  [self setDelegate:(id)self];
  [self setDataSource:(id)self];
  [self registerForDraggedTypes:[NSArray arrayWithObject:CompositionConfigurationsProgramArgumentsPboardType]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [self->controller release];
  [super dealloc];
}
//end dealloc

-(void) setController:(CompositionConfigurationsProgramArgumentsController*)aController
{
  [aController retain];
  [self->controller release];
  self->controller = aController;
  [self bind:NSContentBinding toObject:self->controller withKeyPath:@"arrangedObjects" options:nil];
  [self bind:NSSelectionIndexesBinding toObject:self->controller withKeyPath:NSSelectionIndexesBinding options:nil];
  [[self tableColumnWithIdentifier:@"arguments"] bind:NSValueBinding toObject:self->controller withKeyPath:@"arrangedObjects.string" options:nil];
}
//end setController:

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  NSInteger row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}
//end acceptsFirstMouse:

-(void) keyDown:(NSEvent*)theEvent
{
  [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
  if (([theEvent keyCode] == 36) || ([theEvent keyCode] == 52) || ([theEvent keyCode] == 49))//Enter, space or ?? What did I do ???
    [self edit:self];
}
//end keyDown:

-(IBAction) add:(id)sender
{
  NSMutableString* newArgument = [NSMutableString string];
  [self->controller addObject:newArgument];
  [self->controller setSelectedObjects:[NSArray arrayWithObjects:newArgument, nil]];
  [self performSelector:@selector(edit:) withObject:self afterDelay:0];
}
//end add:

-(IBAction) remove:(id)sender
{
  [self->controller remove:sender];
}
//end remove:

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
  [self->controller remove:sender];
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
-(void) textDidEndEditing:(NSNotification *)aNotification
{
  NSInteger selectedRow = [self selectedRow];
  [super textDidEndEditing:aNotification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}
//end textDidEndEditing:

#pragma mark delegate
-(void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSUInteger lastIndex = [[self selectedRowIndexes] lastIndex];
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
  NSArray* selection = [self->controller selectedObjects];
  [pboard declareTypes:[NSArray arrayWithObject:CompositionConfigurationsProgramArgumentsPboardType] owner:self];  
  [pboard setPropertyList:[NSKeyedArchiver archivedDataWithRootObject:selection]
                  forType:CompositionConfigurationsProgramArgumentsPboardType];
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
            [pboard availableTypeFromArray:[NSArray arrayWithObject:CompositionConfigurationsProgramArgumentsPboardType]] &&
            [pboard propertyListForType:CompositionConfigurationsProgramArgumentsPboardType] &&
            (operation == NSTableViewDropAbove) &&
            indexSet && ([indexSet firstIndex] != (NSUInteger)row) && ([indexSet firstIndex]+1 != (NSUInteger)row);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
  NSIndexSet* indexSet = [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  [self->controller moveObjectsAtIndices:indexSet toIndex:row];
  self->draggedRowIndexes = nil;
  return YES;
}
//end tableView:acceptDrop:row:dropOperation:

@end
