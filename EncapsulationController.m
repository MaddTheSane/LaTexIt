//
//  EncapsulationController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//this class is the "encapsulation palette", see encaspulationManager for more details

#import "EncapsulationController.h"

#import "AppController.h"
#import "EncapsulationManager.h"
#import "EncapsulationTableView.h"
#import "PreferencesController.h"

@interface EncapsulationController (PrivateAPI)
-(void) _updateButtonStates:(NSNotification*)notification;
@end

@implementation EncapsulationController

-(id) init
{
  if (![super initWithWindowNibName:@"Encapsulation"])
    return nil;
  return self;
}

-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"encapsulations"];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateButtonStates:)
                                               name:NSTableViewSelectionDidChangeNotification object:encapsulationTableView];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(IBAction) newEncapsulation:(id)sender
{
  [[EncapsulationManager sharedManager] newEncapsulation];
  [encapsulationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[encapsulationTableView numberOfRows]-1]
                      byExtendingSelection:NO];
  //[encapsulationTableView edit:self];
}

-(IBAction) removeSelectedEncapsulations:(id)sender
{
  [[EncapsulationManager sharedManager] removeEncapsulationIndexes:[encapsulationTableView selectedRowIndexes]];
}

//the help button opens the "Advanced" pane of the preferences controller
-(IBAction) openHelp:(id)sender
{
  [[AppController appController] showPreferencesPaneWithIdentifier:@"advanced"];
}

-(void) _updateButtonStates:(NSNotification*)notification
{
  //only registered for encapsulationTableView
  [removeButton setEnabled:([encapsulationTableView selectedRow] >= 0)];
}

@end
