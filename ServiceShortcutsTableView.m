//
//  ServiceShortcutsTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/12/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.


//The ServiceShortcutsTableView is the class used to display the application service shortcut preferences.
//It has been sub-classed to tune a little the behaviour

#import "ServiceShortcutsTableView.h"

@implementation ServiceShortcutsTableView

//prevents from selecting next line when finished editing
-(void) textDidEndEditing:(NSNotification *)aNotification
{
  int selectedRow = [self selectedRow];
  [super textDidEndEditing:aNotification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}

@end
