//  LibraryDrawer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The libraryDrawer contains the library outline view (hierarchical) and
//the buttons <add folder>, <import current>, <remove>, <refresh>

#import "LibraryDrawer.h"

#import "LibraryFile.h"
#import "LibraryManager.h"
#import "LibraryView.h"
#import "MyDocument.h"

@interface LibraryDrawer (PrivateAPI)
-(void) _selectionDidChange:(NSNotification*)aNotification;
@end

@implementation LibraryDrawer

-(id) initWithCoder:(NSCoder*)coder
{
  self = [super initWithCoder:coder];
  if (self)
  {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_selectionDidChange:)
                                                 name:NSOutlineViewSelectionDidChangeNotification object:nil];
  }
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

//Creates a library item with the current document state
-(IBAction) importCurrent:(id)sender
{
  MyDocument*  document = [[[self parentWindow] windowController] document];
  HistoryItem* historyItem = [document historyItemWithCurrentState];
  LibraryItem* newItem = [[LibraryManager sharedManager] addFile:historyItem outlineView:libraryView];
  [libraryView selectRowIndexes:[NSIndexSet indexSetWithIndex:[libraryView rowForItem:newItem]]
           byExtendingSelection:NO];
}

//Creates a folder library item
-(IBAction) addFolder:(id)sender
{
  LibraryItem* newItem = [[LibraryManager sharedManager] addFolder:libraryView];
  [libraryView selectRowIndexes:[NSIndexSet indexSetWithIndex:[libraryView rowForItem:newItem]]
           byExtendingSelection:NO];
}

//remove selected items
-(IBAction) removeItem:(id)sender
{
  [libraryView removeSelectedItems];
}

//if one LibraryFile item is selected, update it with current document's state
-(IBAction) refreshItem:(id)sender
{
  unsigned int index = [[libraryView selectedRowIndexes] firstIndex];
  LibraryItem* item = [libraryView itemAtRow:index];
  if ([item isKindOfClass:[LibraryFile class]])
  {
    LibraryFile* fileItem = (LibraryFile*) item;
    MyDocument*  document = [[[self parentWindow] windowController] document];
    HistoryItem* newValue = [document historyItemWithCurrentState];
    [[LibraryManager sharedManager] refreshFileItem:fileItem withValue:newValue];
    [libraryView reloadItem:item];
    
    //let's make it blink a little to inform the user that it has change
    BOOL isSelected = YES;
    unsigned int itemIndex   = index;
    NSIndexSet*  itemIndexes = [NSIndexSet indexSetWithIndex:itemIndex];
    int i = 0;
    for(i = 0 ; i<7 ; ++i)
    {
      if (isSelected)
        [libraryView deselectRow:itemIndex];
      else
        [libraryView selectRowIndexes:itemIndexes byExtendingSelection:NO];
      isSelected = !isSelected;
      [libraryView display];
      NSDate* now = [NSDate date];
      NSDate* next = [now addTimeInterval:1./30.];
      [NSThread sleepUntilDate:next];
    }
    [libraryView selectRowIndexes:itemIndexes byExtendingSelection:NO];
    [libraryView display];
  }
}


//updates some buttons state (enabled/disabled for <remove> and <update> buttons) according to selection
-(void) _selectionDidChange:(NSNotification*)aNotification
{
  if ([aNotification object] == libraryView)
  {
    NSIndexSet* selectedRowIndexes = [libraryView selectedRowIndexes];
    BOOL atLeastOneItemSelected = ([selectedRowIndexes count] >= 0);
    BOOL onlyOneItemSelected = ([selectedRowIndexes count] == 1);
    unsigned int firstIndex = [selectedRowIndexes firstIndex];
    [removeItemButton setEnabled:atLeastOneItemSelected];
    [refreshItemButton setEnabled:onlyOneItemSelected && [[libraryView itemAtRow:firstIndex] isKindOfClass:[LibraryFile class]]];
  }
}

@end
