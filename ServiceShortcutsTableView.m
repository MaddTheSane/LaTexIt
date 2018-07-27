//
//  ServiceShortcutsTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/12/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.


//The ServiceShortcutsTableView is the class used to display the application service shortcut preferences.
//It has been sub-classed to tune a little the behaviour

#import "ServiceShortcutsTableView.h"

@interface ServiceShortcutsTableView (PrivateAPI)
-(void) notified:(NSNotification*)notification;
@end

@implementation ServiceShortcutsTableView

-(id) initWithCoder:(NSCoder*)coder
{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notified:) name:NSUserDefaultsDidChangeNotification object:nil];
  return [super initWithCoder:coder];
}
//end initWithCoder:

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}
//end dealloc

//prevents from selecting next line when finished editing
-(void) textDidEndEditing:(NSNotification *)aNotification
{
  int selectedRow = [self selectedRow];
  [super textDidEndEditing:aNotification];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}
//end textDidEndEditing:

-(void) notified:(NSNotification*)notification
{
  [self reloadData];
}
//end notified:

@end
