//
//  EncapsulationsWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//this class is the "encapsulation palette", see encaspulationManager for more details

#import "EncapsulationsWindowController.h"

#import "AppController.h"
#import "EncapsulationsTableView.h"
#import "PreferencesController.h"
#import "PreferencesWindowController.h"

@implementation EncapsulationsWindowController

-(instancetype) init
{
  if ((!(self = [super initWithWindowNibName:@"EncapsulationsWindowController"])))
    return nil;
  return self;
}
//end init

-(void) windowDidLoad
{
  [self.window setFrameAutosaveName:@"encapsulations"];
  [self.window setTitle:NSLocalizedString(@"Encapsulations", @"Encapsulations")];
  EncapsulationsController* encapsulationsController = [[PreferencesController sharedController] encapsulationsController];
  [self->addButton bind:NSEnabledBinding toObject:encapsulationsController withKeyPath:@"canAdd" options:nil];
  self->addButton.target = encapsulationsController;
  self->addButton.action = @selector(add:);
  [self->removeButton bind:NSEnabledBinding toObject:encapsulationsController withKeyPath:@"canRemove" options:nil];
  self->removeButton.target = encapsulationsController;
  self->removeButton.action = @selector(remove:);
}
//end windowDidLoad:

//the help button opens the "Advanced" pane of the preferences controller
-(IBAction) openHelp:(id)sender
{
  [[AppController appController] showPreferencesPaneWithItemIdentifier:AdvancedToolbarItemIdentifier options:nil];
}
//end openHelp:

@end
