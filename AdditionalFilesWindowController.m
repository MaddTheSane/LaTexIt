//
//  AdditionalFilesWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
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
  self->additionalFilesMenuButton.image = [NSImage imageNamed:@"button-menu"];
  NSMenu* menu = [[NSMenu alloc] init];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:NSLocalizedString(@"Open defaults", @"Open defaults")
    action:@selector(additionalFilesOpenDefaults:) keyEquivalent:@""].target = self;
  [menu addItemWithTitle:NSLocalizedString(@"Save as defaults", @"Save as defaults")
    action:@selector(additionalFilesSetAsDefaults:) keyEquivalent:@""].target = self;
  self->additionalFilesMenuButton.menu = menu;
}
//end awakeFromNib

-(void) windowDidLoad
{
  NSPanel* window = (NSPanel*)self.window;
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"AdditionalFiles"];
  [window setTitle:NSLocalizedString(@"Additional files", @"Additional files")];
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
