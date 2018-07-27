//
//  TextShortcutsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

#import "TextShortcutsController.h"

#import "AppController.h"
#import "TextShortcutsManager.h"
#import "TextShortcutsTableView.h"
#import "PreferencesController.h"

@interface TextShortcutsController (PrivateAPI)
-(void) _updateButtonStates:(NSNotification*)notification;
@end

@implementation TextShortcutsController

-(id) init
{
  if (![super initWithWindowNibName:@"TextShortcuts"])
    return nil;
  return self;
}

-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"textShortcutss"];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateButtonStates:)
                                               name:NSTableViewSelectionDidChangeNotification object:textShortcutsTableView];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(IBAction) newTextShortcut:(id)sender
{
  [[TextShortcutsManager sharedManager] newTextShortcut];
  [textShortcutsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[textShortcutsTableView numberOfRows]-1]
                      byExtendingSelection:NO];
}

-(IBAction) removeSelectedTextShortcuts:(id)sender
{
  [[TextShortcutsManager sharedManager] removeTextShortcutsIndexes:[textShortcutsTableView selectedRowIndexes]];
}

-(void) _updateButtonStates:(NSNotification*)notification
{
  //only registered for textShortcutsTableView
  [removeButton setEnabled:([textShortcutsTableView selectedRow] >= 0)];
}

@end
