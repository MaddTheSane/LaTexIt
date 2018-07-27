//
//  CompositionConfigurationTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationTableView.h"

#import "CompositionConfigurationManager.h"
#import "PreferencesController.h"

@interface CompositionConfigurationTableView (PrivateAPI)
-(void) textDidEndEditing:(NSNotification *)aNotification;
-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification;
@end

@implementation CompositionConfigurationTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  cachedConfigurations = [[NSMutableArray alloc] init];
  return self;
}

-(void) awakeFromNib
{
  [self setDelegate:self];
  [self setDataSource:[CompositionConfigurationManager sharedManager]];
  [self registerForDraggedTypes:[NSArray arrayWithObject:CompositionConfigurationPboardType]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDefaultsDidChangeNotification:)
                                               name:NSUserDefaultsDidChangeNotification object:nil];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [cachedConfigurations release];
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
  [[[CompositionConfigurationManager sharedManager] undoManager] undo];
}

-(IBAction) redo:(id)sender
{
  [[[CompositionConfigurationManager sharedManager] undoManager] redo];
}

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  NSUndoManager* undoManager = [[CompositionConfigurationManager sharedManager] undoManager];
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
  [[CompositionConfigurationManager sharedManager] removeCompositionConfigurationIndexes:[self selectedRowIndexes]];
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

-(void)tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSArray* configurations = [userDefaults objectForKey:CompositionConfigurationsKey];
  BOOL isDefault = [[[configurations objectAtIndex:rowIndex] objectForKey:CompositionConfigurationIsDefaultKey] boolValue];
  [aCell setTextColor:isDefault ? [NSColor grayColor] : [NSColor blackColor]];
}

-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  //we keep a cache to avoid reloading data at each user defaults change notification
  NSArray* configurations = [userDefaults objectForKey:CompositionConfigurationsKey];
  if (![cachedConfigurations isEqualToArray:configurations])
  {
    [cachedConfigurations setArray:configurations];
    [self reloadData];
  }

  unsigned int index = [[userDefaults objectForKey:CurrentCompositionConfigurationIndexKey] unsignedIntValue];
  if (index == NSNotFound)
    [self deselectAll:self];
  else if (index != (unsigned int) [self selectedRow])
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
}

@end
