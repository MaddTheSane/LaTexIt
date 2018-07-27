//
//  TextShortcutsManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//the TextShortcutsManager is dataSource and delegate of the TextShortcutsView
//textShortcuts are customizable exports of library items, when drag'n dropping to destinations that are text-only
//you may export the item title, latex source code, with some decorations...

#import "TextShortcutsManager.h"

#import "NSArrayExtended.h"
#import "NSMutableArrayExtended.h"
#import "PreferencesController.h"

NSString* TextShortcutsPboardType = @"TextShortcutsPboardType"; //pboard type for drag'n drop of tableviews rows

@interface TextShortcutsManager (PrivateAPI)
-(void) _removeItemsAtIndexes:(NSIndexSet*)indexes;
-(void) _insertItems:(NSArray*)items atIndexes:(NSIndexSet*)indexes;
-(NSIndexSet*) _draggedRowIndexes; //utility method to access draggedItems when working with pasteboard sender

//table source protocole
-(BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
-(BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;
@end

@implementation TextShortcutsManager

static TextShortcutsManager* sharedManagerInstance = nil; //the (private) singleton

+(TextShortcutsManager*) sharedManager //access the unique instance of TextShortcutsManager
{
  @synchronized(self)
  {
    //creates the unique instance of TextShortcutsManager
    if (!sharedManagerInstance)
      sharedManagerInstance = [[self  alloc] init];
  }
  return sharedManagerInstance;
}

+(id) allocWithZone:(NSZone *)zone
{
  @synchronized(self)
  {
    if (!sharedManagerInstance)
       return [super allocWithZone:zone];
  }
  return sharedManagerInstance;
}

-(id) copyWithZone:(NSZone *)zone
{
  return self;
}

-(id) retain
{
  return self;
}

-(unsigned) retainCount
{
  return UINT_MAX;  //denotes an object that cannot be released
}

-(void) release
{
}

-(id) autorelease
{
  return self;
}

-(id) init
{
  if (self && (self != sharedManagerInstance))  //do not recreate an instance
  {
    if (![super init])
      return nil;
    sharedManagerInstance = self;
    //reads encaspulations and current one in user defaults
    undoManager = [[NSUndoManager alloc] init];
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    textShortcuts = [[NSMutableArray alloc] initWithArray:[userDefaults objectForKey:TextShortcutsKey]];
  }
  return self;
}

-(void) dealloc
{
  [undoManager release];
  [textShortcuts release];
  [super dealloc];
}

-(NSUndoManager*) undoManager
{
  return undoManager;
}

-(void) newTextShortcut
{
  const unichar ouml = 0x00F6;
  NSString* oumlString = [NSString stringWithCharacters:&ouml length:1];
  NSDictionary* defaultShortcut = [NSDictionary dictionaryWithObjectsAndKeys:oumlString, @"input", @"\\", @"left", @"", @"right",
                                                                             [NSNumber numberWithBool:NO], @"enabled", nil];
  [self _insertItems:[NSArray arrayWithObject:defaultShortcut] atIndexes:[NSIndexSet indexSetWithIndex:[textShortcuts count]]];
  if (![undoManager isUndoing])
    [undoManager setActionName:NSLocalizedString(@"New text shortcut", @"New text shortcut")];
}

-(void) removeTextShortcutsIndexes:(NSIndexSet*)indexes
{
  [self _removeItemsAtIndexes:indexes];
  if (![undoManager isUndoing])
  {
    if ([indexes count] > 1)
      [undoManager setActionName:NSLocalizedString(@"Remove text shortcuts", @"Remove text shortcuts")];
    else
      [undoManager setActionName:NSLocalizedString(@"Remove text shortcut", @"Remove text shortcut")];
  }
}

-(void) _removeItemsAtIndexes:(NSIndexSet*)indexes
{
  NSArray* items = [textShortcuts objectsAtIndexes:indexes];
  [textShortcuts removeObjectsAtIndexes:indexes];
  [[undoManager prepareWithInvocationTarget:self] _insertItems:items atIndexes:indexes];
  [[NSUserDefaults standardUserDefaults] setObject:textShortcuts forKey:TextShortcutsKey];
}

-(void) _insertItems:(NSArray*)items atIndexes:(NSIndexSet*)indexes
{
  unsigned int index = [indexes lastIndex];
  NSEnumerator* enumerator = [items reverseObjectEnumerator];
  id object = [enumerator nextObject];
  while(object)
  {
    [textShortcuts insertObject:object atIndex:index];
    index = [indexes indexLessThanIndex:index];
    object = [enumerator nextObject];
  }
  [[undoManager prepareWithInvocationTarget:self] _removeItemsAtIndexes:indexes];
  [[NSUserDefaults standardUserDefaults] setObject:textShortcuts forKey:TextShortcutsKey];
}

//textShortcuts datasource
-(int) numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [textShortcuts count];
}

-(id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  return [[textShortcuts objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

-(void) tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  NSString* identifier = [aTableColumn identifier];
  id oldValue = [[textShortcuts objectAtIndex:rowIndex] objectForKey:identifier];
  [[undoManager prepareWithInvocationTarget:self] tableView:aTableView setObjectValue:oldValue forTableColumn:aTableColumn row:rowIndex];
  if (![undoManager isUndoing])
    [undoManager setActionName:NSLocalizedString(@"Change the text shortcut", @"Change the text shortcut")];
  NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary:[textShortcuts objectAtIndex:rowIndex]];
  if ([identifier isEqualToString:@"input"])
  {
    NSString* s = anObject;
    if ([s length] < 1)
      s = oldValue;
    else
      s = [s substringWithRange:NSMakeRange(0, 1)];
    anObject = s;
  }
  [dict setValue:anObject forKey:identifier];
  [textShortcuts replaceObjectAtIndex:rowIndex withObject:dict];
  [[NSUserDefaults standardUserDefaults] setObject:textShortcuts forKey:TextShortcutsKey];
}

//drag'n drop for moving rows

-(NSIndexSet*) _draggedRowIndexes //utility method to access draggedItems when working with pasteboard sender
{
  return draggedRowIndexes;
}

//this one is deprecated in OS 10.4, calls writeRowsWithIndexes
-(BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
  NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
  NSEnumerator* enumerator = [rows objectEnumerator];
  NSNumber* row = [enumerator nextObject];
  while(row)
  {
    [indexSet addIndex:[row unsignedIntValue]];
    row = [enumerator nextObject];
  }
  return [self tableView:tableView writeRowsWithIndexes:indexSet toPasteboard:pboard];
}

//this one is for OS 10.4
-(BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
  //we put the moving rows in pasteboard
  draggedRowIndexes = rowIndexes;
  [pboard declareTypes:[NSArray arrayWithObject:TextShortcutsPboardType] owner:self];
  [pboard setPropertyList:[textShortcuts objectsAtIndexes:rowIndexes] forType:TextShortcutsPboardType];
  return YES;
}

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  //we only accept moving inside the table (not between different ones)
  NSPasteboard* pboard = [info draggingPasteboard];
  NSIndexSet* indexSet =  [[[info draggingSource] dataSource] _draggedRowIndexes];
  BOOL ok = (tableView == [info draggingSource]) && pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:TextShortcutsPboardType]] &&
            [pboard propertyListForType:TextShortcutsPboardType] &&
            (operation == NSTableViewDropAbove) &&
            indexSet && ([indexSet firstIndex] != (unsigned int)row) && ([indexSet firstIndex]+1 != (unsigned int)row);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  NSIndexSet* indexSet = [[[info draggingSource] dataSource] _draggedRowIndexes];
  NSArray* objectsToMove = [textShortcuts objectsAtIndexes:indexSet];
  [self _removeItemsAtIndexes:indexSet];

  //difficult : we must compute the row of insertion when the objects have been removed from their previous location
  unsigned int whereToInsert = row;
  unsigned int index = [indexSet firstIndex];
  while((index != NSNotFound) && (index < (unsigned int) row))
  {
    --whereToInsert;
    index = [indexSet indexGreaterThanIndex:index];
  }

  //now insert the objects at increasing destination row
  unsigned int destination = whereToInsert;
  NSMutableIndexSet* destinationIndexes = [NSMutableIndexSet indexSet];
  NSEnumerator* enumerator = [objectsToMove objectEnumerator];
  NSString* string = [enumerator nextObject];
  while(string)
  {
    [destinationIndexes addIndex:destination];
    ++destination;
    string = [enumerator nextObject];
  }
  [self _insertItems:objectsToMove atIndexes:destinationIndexes];

  if ([objectsToMove count] > 1)
    [undoManager setActionName:NSLocalizedString(@"Move text shortcuts", @"Move text shortcuts")];
  else
    [undoManager setActionName:NSLocalizedString(@"Move the text shortcut", @"Move the text shortcut")];

  [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:whereToInsert] byExtendingSelection:NO];

  return YES;
}               

@end
