//
//  TextShortcutsTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.

//TextShortcutsTableView presents custom text shortcuts from an text shortcuts manager. I has user friendly capabilities

#import "TextShortcutsTableView.h"

#import "PreferencesController.h"

static NSString* EditionTextShortcutsPboardType = @"EditionTextShortcutsPboardType";

@interface TextShortcutsTableView (PrivateAPI)
-(void) textDidEndEditing:(NSNotification *)aNotification;
@end

@implementation TextShortcutsTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  [self setDelegate:(id)self];
  NSArrayController* editionTextShortcutsController = [[PreferencesController sharedController] editionTextShortcutsController];
  NSArray* tableColumns = [self tableColumns];
  NSEnumerator* enumerator = [tableColumns objectEnumerator];
  NSTableColumn* tableColumn = nil;
  while((tableColumn = [enumerator nextObject]))
    [tableColumn bind:NSValueBinding toObject:editionTextShortcutsController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", [tableColumn identifier]] options:nil];
  [self registerForDraggedTypes:[NSArray arrayWithObject:EditionTextShortcutsPboardType]];
}
//end awakeFromNib

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  int row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}
//end acceptsFirstMouse

-(void) keyDown:(NSEvent*)theEvent
{
  [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
  if (([theEvent keyCode] == 36) || ([theEvent keyCode] == 52) || ([theEvent keyCode] == 49))//Enter, space or ?? What did I do ???
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
  [[[PreferencesController sharedController] editionTextShortcutsController] remove:sender];
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
-(void) textDidEndEditing:(NSNotification *)aNotification
{
  int selectedRow = [self selectedRow];
  [super textDidEndEditing:aNotification];
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

@end
