//
//  EncapsulationManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//the EncapsulationManager is dataSource and delegate of the EncapsulationView
//encapsulations are customizable exports of library items, when drag'n dropping to destinations that are text-only
//you may export the item title, latex source code, with some decorations...

#import "EncapsulationManager.h"

#import "EncapsulationView.h"
#import "NSArrayExtended.h"
#import "NSMutableArrayExtended.h"
#import "PreferencesController.h"

NSString* EncapsulationPboardType = @"EncapsulationPboardType"; //pboard type for drag'n drop of tableviews rows

@interface EncapsulationManager (PrivateAPI)
-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification;
-(void) _updateButtonStates;//when no selection, "remove" button is disabled
-(NSIndexSet*) _draggedRowIndexes; //utility method to access draggedItems when working with pasteboard sender
-(BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
-(BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;
@end

@implementation EncapsulationManager

-(id) init
{
  self = [super init];
  if (self)
  {
    //reads encaspulations and current one in user defaults
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    encapsulations = [[NSMutableArray alloc] initWithArray:[userDefaults objectForKey:EncapsulationsKey]];
    unsigned int    currentIndex = [[userDefaults objectForKey:CurrentEncapsulationIndexKey] unsignedIntValue];
    if (currentIndex >= [encapsulations count])//should not happen, but we handle it
      currentIndex = [encapsulations count] ? [encapsulations count]-1 : NSNotFound;
    [userDefaults setObject:[NSNumber numberWithUnsignedInt:currentIndex] forKey:CurrentEncapsulationIndexKey];

    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(_userDefaultsDidChangeNotification:)
                                                 name:NSUserDefaultsDidChangeNotification object:nil];
  }
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [encapsulations release];
  [super dealloc];
}

-(void) awakeFromNib
{
  [encapsulationTableView setDataSource:self];
  [encapsulationTableView setDelegate:self];

  //selects the good line of tableview
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  unsigned int    currentIndex = [[userDefaults objectForKey:CurrentEncapsulationIndexKey] unsignedIntValue];
  [encapsulationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:currentIndex] byExtendingSelection:NO];
}

-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  
  //another encaspualtionManager may have changed the user defaults
  NSArray* newEncapsulations = [userDefaults objectForKey:EncapsulationsKey];
  if (![encapsulations isEqualToArray:newEncapsulations])
  {
    [encapsulations setArray:newEncapsulations];
    [encapsulationTableView reloadData];
  }
  
  unsigned int index = [[userDefaults objectForKey:CurrentEncapsulationIndexKey] unsignedIntValue];
  if (index != (unsigned int) [encapsulationTableView selectedRow])
    [encapsulationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
}

  //if no selection, disable "remove" button
-(void) _updateButtonStates
{
  NSIndexSet* selectedRowIndexes = [encapsulationTableView selectedRowIndexes];
  BOOL atLeastOneItemSelected = [selectedRowIndexes count];
  [removeEncapsulationButton setEnabled:atLeastOneItemSelected];
}

-(IBAction) addEncapsulation:(id)sender
{
  [encapsulations addObject:@"@"];
  [[NSUserDefaults standardUserDefaults] setObject:encapsulations forKey:EncapsulationsKey];
  [encapsulationTableView reloadData];
  [encapsulationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[encapsulations count]-1] byExtendingSelection:NO];
}

-(IBAction) removeEncapsulations:(id)sender
{
  [self removeSelectedItemsInTableView:encapsulationTableView];
}

-(void) removeSelectedItemsInTableView:(NSTableView*)tableView
{
  if (tableView == encapsulationTableView)
  {
    NSIndexSet* indexSet = [tableView selectedRowIndexes];
    [encapsulations removeObjectsAtIndexes:indexSet];
    [[NSUserDefaults standardUserDefaults] setObject:encapsulations forKey:EncapsulationsKey];
    [encapsulationTableView noteNumberOfRowsChanged];
    unsigned int newIndex = [indexSet firstIndex];
    if ((newIndex != NSNotFound) && (newIndex < [encapsulations count]))
      [encapsulationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newIndex] byExtendingSelection:NO];
    else if ([encapsulations count])
      [encapsulationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[encapsulations count]-1] byExtendingSelection:NO];
    else
      [encapsulationTableView deselectAll:self];
  }
}

//encapsulation datasource
-(int) numberOfRowsInTableView:(NSTableView*)aTableView
{
  int nb = 0;
  if (aTableView == encapsulationTableView)
    nb = [encapsulations count];
  return nb;
}

-(id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  id value = nil;
  if (aTableView == encapsulationTableView)
    value = [encapsulations objectAtIndex:rowIndex];
  return value;
}

-(void) tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  if (aTableView == encapsulationTableView)
  {
    [encapsulations replaceObjectAtIndex:rowIndex withObject:anObject];
    [[NSUserDefaults standardUserDefaults] setObject:encapsulations forKey:EncapsulationsKey];
  }
}

//delegate methods
-(void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
  //at each selection change, synchronize user defaults
  if ([aNotification object] == encapsulationTableView)
  {
    [self _updateButtonStates];
    unsigned int lastIndex = [[encapsulationTableView selectedRowIndexes] lastIndex];
    [encapsulationTableView scrollRowToVisible:lastIndex];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:lastIndex] forKey:CurrentEncapsulationIndexKey];
  }
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
  BOOL ok = (tableView == encapsulationTableView) && pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:EncapsulationPboardType]] &&
            [pboard propertyListForType:EncapsulationPboardType] &&
            (operation == NSTableViewDropAbove);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  NSIndexSet* indexSet = [[[info draggingSource] dataSource] _draggedRowIndexes];
  if (indexSet)
  {
    NSArray* objectsToMove = [encapsulations objectsAtIndexes:indexSet];
    [encapsulations removeObjectsAtIndexes:indexSet];

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
    NSEnumerator* enumerator = [objectsToMove objectEnumerator];
    NSString* string = [enumerator nextObject];
    while(string)
    {
      [encapsulations insertObject:string atIndex:destination++];
      string = [enumerator nextObject];
    }

    //synchronize user defaults
    [[NSUserDefaults standardUserDefaults] setObject:encapsulations forKey:EncapsulationsKey];
    [tableView reloadData];
    [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:whereToInsert] byExtendingSelection:NO];
  }
  return YES;
}               

@end
