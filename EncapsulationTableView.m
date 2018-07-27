//
//  EncapsulationTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//EncapsulationTableView presents custom encapsulations from an encaspulation manager. I has user friendly capabilities

#import "EncapsulationTableView.h"
#import "EncapsulationManager.h"
#import "PreferencesController.h"

@interface EncapsulationTableView (PrivateAPI)
-(void) textDidEndEditing:(NSNotification *)aNotification;
-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification;
@end

@implementation EncapsulationTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  cachedEncapsulations = [[NSMutableArray alloc] init];
  return self;
}

-(void) awakeFromNib
{
  [self setDelegate:self];
  [self setDataSource:[EncapsulationManager sharedManager]];
  [self registerForDraggedTypes:[NSArray arrayWithObject:EncapsulationPboardType]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDefaultsDidChangeNotification:)
                                               name:NSUserDefaultsDidChangeNotification object:nil];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [cachedEncapsulations release];
  [super dealloc];
}

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  int row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}


-(void) keyDown:(NSEvent*)theEvent
{
  [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
  if (([theEvent keyCode] == 36) || ([theEvent keyCode] == 52) || ([theEvent keyCode] == 49))//Enter, space or ?? What did I do ???
    [self edit:self];
}

//edit selected row
-(IBAction) edit:(id)sender
{
  int selectedRow = [self selectedRow];
  if (selectedRow >= 0)
    [self editColumn:0 row:selectedRow withEvent:nil select:YES];
}

-(IBAction) undo:(id)sender
{
  [[[EncapsulationManager sharedManager] undoManager] undo];
}

-(IBAction) redo:(id)sender
{
  [[[EncapsulationManager sharedManager] undoManager] redo];
}

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  NSUndoManager* undoManager = [[EncapsulationManager sharedManager] undoManager];
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

-(void) deleteBackward:(id)sender
{
  [[EncapsulationManager sharedManager] removeEncapsulationIndexes:[self selectedRowIndexes]];
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

//prevents from selecting next line when finished editing
-(void) textDidEndEditing:(NSNotification *)aNotification
{
  int selectedRow = [self selectedRow];
  [super textDidEndEditing:aNotification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}

//delegate methods
-(void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
  unsigned int lastIndex = [[self selectedRowIndexes] lastIndex];
  [self scrollRowToVisible:lastIndex];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:lastIndex] forKey:CurrentEncapsulationIndexKey];
}

-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  //we keep a cache to avoid reloading data at each user defaults change notification
  NSArray* encapsulations = [userDefaults objectForKey:EncapsulationsKey];
  if (![cachedEncapsulations isEqualToArray:encapsulations])
  {
    [cachedEncapsulations setArray:encapsulations];
    [self reloadData];
  }

  unsigned int index = [[userDefaults objectForKey:CurrentEncapsulationIndexKey] unsignedIntValue];
  if (index == NSNotFound)
    [self deselectAll:self];
  else if (index != (unsigned int) [self selectedRow])
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
}

@end
