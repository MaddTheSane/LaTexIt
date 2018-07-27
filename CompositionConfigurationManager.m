//
//  CompositionConfigurationManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationManager.h"

#import "NSArrayExtended.h"
#import "NSMutableArrayExtended.h"
#import "PreferencesController.h"

NSString* CompositionConfigurationPboardType = @"CompositionConfigurationPboardType";
NSString* CompositionConfigurationsDidChangeNotification = @"CompositionConfigurationsDidChangeNotification";

@interface CompositionConfigurationManager (PrivateAPI)
-(void) _removeItemsAtIndexes:(NSIndexSet*)indexes;
-(void) _insertItems:(NSArray*)items atIndexes:(NSIndexSet*)indexes;
-(NSIndexSet*) _draggedRowIndexes; //utility method to access draggedItems when working with pasteboard sender

//table source protocole
-(BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
-(BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;
@end

@implementation CompositionConfigurationManager

static CompositionConfigurationManager* sharedManagerInstance = nil; //the (private) singleton

+(CompositionConfigurationManager*) sharedManager //access the unique instance of CompositionConfigurationManager
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
    //reads compositionConfigurations and current one in user defaults
    undoManager = [[NSUndoManager alloc] init];
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    configurations = [[NSMutableArray alloc] initWithArray:[userDefaults objectForKey:CompositionConfigurationsKey]];
    unsigned int currentIndex = [[userDefaults objectForKey:CurrentCompositionConfigurationIndexKey] unsignedIntValue];
    if (currentIndex >= [configurations count])//should not happen, but we handle it
      currentIndex = [configurations count] ? [configurations count]-1 : NSNotFound;
    [userDefaults setObject:[NSNumber numberWithUnsignedInt:currentIndex] forKey:CurrentCompositionConfigurationIndexKey];
  }
  return self;
}

-(void) dealloc
{
  [undoManager release];
  [configurations release];
  [super dealloc];
}

-(NSUndoManager*) undoManager
{
  return undoManager;
}

-(void) newCompositionConfiguration
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
  NSDictionary* currentCompositionConfiguration =
    [compositionConfigurations objectAtIndex:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
  NSMutableDictionary* newConfiguration = [NSMutableDictionary dictionaryWithDictionary:currentCompositionConfiguration];
  [newConfiguration setObject:[NSNumber numberWithBool:NO] forKey:CompositionConfigurationIsDefaultKey];
  [newConfiguration setObject:NSLocalizedString(@"Untitled", @"Untitled") forKey:CompositionConfigurationNameKey];
  [self _insertItems:[NSArray arrayWithObject:newConfiguration] atIndexes:[NSIndexSet indexSetWithIndex:[configurations count]]];
  if (![undoManager isUndoing])
    [undoManager setActionName:NSLocalizedString(@"New configuration", @"New configuration")];
}

-(void) removeCompositionConfigurationIndexes:(NSIndexSet*)indexes
{
  [self _removeItemsAtIndexes:indexes];
  if (![undoManager isUndoing])
  {
    if ([indexes count] > 1)
      [undoManager setActionName:NSLocalizedString(@"Remove configuration items", @"Remove configuration items")];
    else
      [undoManager setActionName:NSLocalizedString(@"Remove configuration item", @"Remove configuration item")];
  }
  unsigned int newIndex = MIN([configurations count] ? [configurations count]-1 : NSNotFound, [indexes firstIndex]);
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:newIndex] forKey:CurrentCompositionConfigurationIndexKey];
  [[PreferencesController sharedController] changeCompositionSelection:nil];//updates popup button
}

-(void) _removeItemsAtIndexes:(NSIndexSet*)indexes_
{
  NSMutableIndexSet* indexes = [NSMutableIndexSet indexSet];
  unsigned int index = [indexes_ firstIndex];
  while(index != NSNotFound)
  {
    if (![[[configurations objectAtIndex:index] objectForKey:CompositionConfigurationIsDefaultKey] boolValue])
      [indexes addIndex:index];
    index = [indexes_ indexGreaterThanIndex:index];
  }
  NSArray* items = [configurations objectsAtIndexes:indexes];
  [configurations removeObjectsAtIndexes:indexes];
  [[undoManager prepareWithInvocationTarget:self] _insertItems:items atIndexes:indexes];
  [[NSUserDefaults standardUserDefaults] setObject:configurations forKey:CompositionConfigurationsKey];
  [[NSNotificationCenter defaultCenter] postNotificationName:CompositionConfigurationsDidChangeNotification object:nil];
}

-(void) _insertItems:(NSArray*)items atIndexes:(NSIndexSet*)indexes
{
  unsigned int index = [indexes lastIndex];
  NSEnumerator* enumerator = [items reverseObjectEnumerator];
  id object = [enumerator nextObject];
  while(object)
  {
    [configurations insertObject:object atIndex:index];
    index = [indexes indexLessThanIndex:index];
    object = [enumerator nextObject];
  }
  [[undoManager prepareWithInvocationTarget:self] _removeItemsAtIndexes:indexes];
  [[NSUserDefaults standardUserDefaults] setObject:configurations forKey:CompositionConfigurationsKey];
  unsigned int newIndex = MIN([configurations count] ? [configurations count]-1 : NSNotFound, [indexes firstIndex]);
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:newIndex] forKey:CurrentCompositionConfigurationIndexKey];
  [[NSNotificationCenter defaultCenter] postNotificationName:CompositionConfigurationsDidChangeNotification object:nil];
}

//encapsulation datasource
-(int) numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [configurations count];
}

-(id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  return [[configurations objectAtIndex:rowIndex] objectForKey:CompositionConfigurationNameKey];
}

-(void) tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  id oldValue = [configurations objectAtIndex:rowIndex];
  [[undoManager prepareWithInvocationTarget:self]
    tableView:aTableView setObjectValue:[oldValue objectForKey:CompositionConfigurationNameKey]
                         forTableColumn:aTableColumn row:rowIndex];
  if (![undoManager isUndoing])
    [undoManager setActionName:NSLocalizedString(@"Change the configuration", @"Change the configuration")];
  NSMutableDictionary* newConfiguration = [NSMutableDictionary dictionaryWithDictionary:oldValue];
  [newConfiguration setObject:anObject forKey:CompositionConfigurationNameKey];
  [configurations replaceObjectAtIndex:rowIndex withObject:newConfiguration];
  [[NSUserDefaults standardUserDefaults] setObject:configurations forKey:CompositionConfigurationsKey];
  [[NSNotificationCenter defaultCenter] postNotificationName:CompositionConfigurationsDidChangeNotification object:nil];
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
  //we put the moving rows in pasteboard, except the one of the "default" unmovable items
  NSMutableIndexSet* filteredIndexSet = [NSMutableIndexSet indexSet];
  unsigned int rowIndex = [rowIndexes firstIndex];
  while(rowIndex != NSNotFound)
  {
    if ((rowIndex < [configurations count]) &&
        ![[[configurations objectAtIndex:rowIndex] objectForKey:CompositionConfigurationIsDefaultKey] boolValue])
      [filteredIndexSet addIndex:rowIndex];
    rowIndex = [rowIndexes indexGreaterThanIndex:rowIndex];
  }
  draggedRowIndexes = filteredIndexSet;
  [pboard declareTypes:[NSArray arrayWithObject:CompositionConfigurationPboardType] owner:self];
  [pboard setPropertyList:[configurations objectsAtIndexes:draggedRowIndexes] forType:CompositionConfigurationPboardType];
  return ([draggedRowIndexes count] != 0);
}

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  //we only accept moving inside the table (not between different ones)
  NSPasteboard* pboard = [info draggingPasteboard];
  NSIndexSet* indexSet =  [[[info draggingSource] dataSource] _draggedRowIndexes];
  BOOL ok = (tableView == [info draggingSource]) && pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:CompositionConfigurationPboardType]] &&
            [pboard propertyListForType:CompositionConfigurationPboardType] &&
            (operation == NSTableViewDropAbove) &&
            indexSet && ([indexSet firstIndex] != (unsigned int)row) && ([indexSet firstIndex]+1 != (unsigned int)row);

  if (row < (int)[configurations count])
    ok &= ![[[configurations objectAtIndex:row] objectForKey:CompositionConfigurationIsDefaultKey] boolValue];

  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  NSIndexSet* indexSet = [[[info draggingSource] dataSource] _draggedRowIndexes];
  
  BOOL droppingOnUnmovableItem = 
    (row < (int)[configurations count]) &&
    [[[configurations objectAtIndex:row] objectForKey:CompositionConfigurationIsDefaultKey] boolValue];
  if (droppingOnUnmovableItem)
    return NO;
  
  NSArray* objectsToMove = [configurations objectsAtIndexes:indexSet];
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
