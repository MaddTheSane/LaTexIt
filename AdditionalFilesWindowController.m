//
//  AdditionalFilesWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "AdditionalFilesWindowController.h"

#import "AdditionalFilesTableView.h"
#import "AppController.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "PreferencesWindowController.h"

@interface AdditionalFilesWindowController ()
-(IBAction) additionalFilesOpenDefaults:(id)sender;
-(IBAction) additionalFilesSetAsDefaults:(id)sender;
@end

@implementation AdditionalFilesWindowController

-(instancetype) init
{
  if ((!(self = [super initWithWindowNibName:@"AdditionalFilesWindowController"])))
    return nil;
  return self;
}
//end init

-(void) awakeFromNib
{
  [self->additionalFilesTableView setIsDefaultTableView:NO];
  self->additionalFilesAddButton.target = self->additionalFilesTableView;
  self->additionalFilesAddButton.action = @selector(addFiles:);
  [self->additionalFilesAddButton bind:NSEnabledBinding toObject:self->additionalFilesTableView withKeyPath:@"canAdd" options:nil];
  self->additionalFilesRemoveButton.target = self->additionalFilesTableView;
  self->additionalFilesRemoveButton.action = @selector(remove:);
  [self->additionalFilesRemoveButton bind:NSEnabledBinding toObject:self->additionalFilesTableView withKeyPath:@"canRemove" options:nil];
  [self->additionalFilesMenuButton setImage:[NSImage imageNamed:@"button-menu"]];
  [self->additionalFilesMenuButton setAlternateImage:[NSImage imageNamed:@"button-menu"]];
  NSMenu* menu = [[NSMenu alloc] init];
  [[menu addItemWithTitle:@"" action:nil keyEquivalent:@""] setTarget:nil];//dummy item
  [[menu addItemWithTitle:NSLocalizedString(@"Open defaults", @"")
    action:@selector(additionalFilesOpenDefaults:) keyEquivalent:@""] setTarget:self];
  [[menu addItemWithTitle:NSLocalizedString(@"Save as defaults", @"")
    action:@selector(additionalFilesSetAsDefaults:) keyEquivalent:@""] setTarget:self];
  [self->additionalFilesMenuButton setMenu:menu];
}
//end awakeFromNib

-(void) windowDidLoad
{
  NSPanel* window = (NSPanel*)self.window;
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"AdditionalFiles"];
  [window setTitle:NSLocalizedString(@"Additional files", @"")];
}
//end windowDidLoad

-(NSArray*) additionalFilesPaths
{
  NSArray* result = [NSArray arrayWithArray:[self->additionalFilesTableView additionalFilesPaths]];
  return result;
}
//end additionalFilesPaths

-(IBAction) additionalFilesOpenDefaults:(id)sender
{
  [[AppController appController] showPreferencesPaneWithItemIdentifier:AdvancedToolbarItemIdentifier options:nil];
}
//end additionalFilesOpenDefaults:

-(IBAction) additionalFilesSetAsDefaults:(id)sender
{
  [PreferencesController sharedController].additionalFilesPaths = [self->additionalFilesTableView additionalFilesPaths];
}
//end additionalFilesOpenDefaults:

@end
