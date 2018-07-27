//
//  EncapsulationManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//the EncapsulationManager is dataSource and delegate of the EncapsulationView
//encapsulations are customizable exports of library items, when drag'n dropping to destinations that are text-only
//you may export the item title, latex source code, with some decorations...

#import "EncapsulationManager.h"

#import "NSArrayExtended.h"
#import "NSMutableArrayExtended.h"
#import "PreferencesController.h"

NSString* EncapsulationPboardType = @"EncapsulationPboardType"; //pboard type for drag'n drop of tableviews rows

@interface EncapsulationManager (PrivateAPI)
-(void) _removeItemsAtIndexes:(NSIndexSet*)indexes;
-(void) _insertItems:(NSArray*)items atIndexes:(NSIndexSet*)indexes;
-(NSIndexSet*) _draggedRowIndexes; //utility method to access draggedItems when working with pasteboard sender

//table source protocole
-(BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
-(BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;
@end

@implementation EncapsulationManager

static EncapsulationManager* sharedManagerInstance = nil; //the (private) singleton

+(EncapsulationManager*) sharedManager //access the unique instance of EncapsulationManager
{
  @synchronized(self)
  {
    //creates the unique instance of EncapsulationManager
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
    encapsulations = [[NSMutableArray alloc] initWithArray:[userDefaults objectForKey:EncapsulationsKey]];
    unsigned int currentIndex = [[userDefaults objectForKey:CurrentEncapsulationIndexKey] unsignedIntValue];
    if (currentIndex >= [encapsulations count])//should not happen, but we handle it
      currentIndex = [encapsulations count] ? [encapsulations count]-1 : NSNotFound;
    [userDefaults setObject:[NSNumber numberWithUnsignedInt:currentIndex] forKey:CurrentEncapsulationIndexKey];
  }
  return self;
}

-(void) dealloc
{
  [undoManager release];
  [encapsulations release];
  [super dealloc];
}

-(NSUndoManager*) undoManager
{
  return undoManager;
}

-(void) newEncapsulation
{
  [self _insertItems:[NSArray arrayWithObject:@"@"] atIndexes:[NSIndexSet indexSetWithIndex:[encapsulations count]]];
  if (![undoManager isUndoing])
    [undoManager setActionName:NSLocalizedString(@"New encapsulation", @"New encapsulation")];
}

-(void) removeEncapsulationIndexes:(NSIndexSet*)indexes
{
  [self _removeItemsAtIndexes:indexes];
  if (![undoManager isUndoing])
  {
    if ([indexes count] > 1)
      [undoManager setActionName:NSLocalizedString(@"Remove encapsulation items", @"Remove encapsulation items")];
    else
      [undoManager setActionName:NSLocalizedString(@"Remove encapsulation item", @"Remove encapsulation item")];
  }
  unsigned int newIndex = MIN([encapsulations count] ? [encapsulations count]-1 : NSNotFound, [indexes firstIndex]);
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:newIndex] forKey:CurrentEncapsulationIndexKey];
}

-(void) _removeItemsAtIndexes:(NSIndexSet*)indexes
{
  NSArray* items = [encapsulations objectsAtIndexes:indexes];
  [encapsulations removeObjectsAtIndexes:indexes];
  [[undoManager prepareWithInvocationTarget:self] _insertItems:items atIndexes:indexes];
  [[NSUserDefaults standardUserDefaults] setObject:encapsulations forKey:EncapsulationsKey];
}

-(void) _insertItems:(NSArray*)items atIndexes:(NSIndexSet*)indexes
{
  unsigned int index = [indexes lastIndex];
  NSEnumerator* enumerator = [items reverseObjectEnumerator];
  id object = [enumerator nextObject];
  while(object)
  {
    [encapsulations insertObject:object atIndex:index];
    index = [indexes indexLessThanIndex:index];
    object = [enumerator nextObject];
  }
  [[undoManager prepareWithInvocationTarget:self] _removeItemsAtIndexes:indexes];
  [[NSUserDefaults standardUserDefaults] setObject:encapsulations forKey:EncapsulationsKey];
  unsigned int newIndex = MIN([encapsulations count] ? [encapsulations count]-1 : NSNotFound, [indexes firstIndex]);
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:newIndex] forKey:CurrentEncapsulationIndexKey];
}

//encapsulation datasource
-(int) numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [encapsulations count];
}

-(id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  return [encapsulations objectAtIndex:rowIndex];
}

-(void) tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  id oldValue = [encapsulations objectAtIndex:rowIndex];
  [[undoManager prepareWithInvocationTarget:self] tableView:aTableView setObjectValue:oldValue forTableColumn:aTableColumn row:rowIndex];
  if (![undoManager isUndoing])
    [undoManager setActionName:NSLocalizedString(@"Change the encapsulation", @"Change the encapsulation")];
  [encapsulations replaceObjectAtIndex:rowIndex withObject:anObject];
  [[NSUserDefaults standardUserDefaults] setObject:encapsulations forKey:EncapsulationsKey];
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
  [pboard declareTypes:[NSArray arrayWithObject:EncapsulationPboardType] owner:self];
  [pboard setPropertyList:[encapsulations objectsAtIndexes:rowIndexes] forType:EncapsulationPboardType];
  return YES;
}

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  //we only accept moving inside the table (not between different ones)
  NSPasteboard* pboard = [info draggingPasteboard];
  NSIndexSet* indexSet =  [[[info draggingSource] dataSource] _draggedRowIndexes];
  BOOL ok = (tableView == [info draggingSource]) && pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:EncapsulationPboardType]] &&
            [pboard propertyListForType:EncapsulationPboardType] &&
            (operation == NSTableViewDropAbove) &&
            indexSet && ([indexSet firstIndex] != (unsigned int)row) && ([indexSet firstIndex]+1 != (unsigned int)row);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  NSIndexSet* indexSet = [[[info draggingSource] dataSource] _draggedRowIndexes];
  NSArray* objectsToMove = [encapsulations objectsAtIndexes:indexSet];
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
    [undoManager setActionName:NSLocalizedString(@"Move encapsulations", @"Move encapsulations")];
  else
    [undoManager setActionName:NSLocalizedString(@"Move the encapsulation", @"Move the encapsulation")];

  [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:whereToInsert] byExtendingSelection:NO];

  return YES;
}               

@end
