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

@interface AdditionalFilesWindowController (PrivateAPI)
-(IBAction) additionalFilesOpenDefaults:(id)sender;
-(IBAction) additionalFilesSetAsDefaults:(id)sender;
-(void) removeFilePaths:(NSArray*)filePaths;
@end

@implementation AdditionalFilesWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"AdditionalFilesWindowController"])))
    return nil;
  return self;
}
//end init

-(void) dealloc
{
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  [self->additionalFilesTableView setIsDefaultTableView:NO];
  [self->additionalFilesAddButton setTarget:self->additionalFilesTableView];
  [self->additionalFilesAddButton setAction:@selector(addFiles:)];
  [self->additionalFilesAddButton bind:NSEnabledBinding toObject:self->additionalFilesTableView withKeyPath:@"canAdd" options:nil];
  [self->additionalFilesRemoveButton setTarget:self->additionalFilesTableView];
  [self->additionalFilesRemoveButton setAction:@selector(remove:)];
  [self->additionalFilesRemoveButton bind:NSEnabledBinding toObject:self->additionalFilesTableView withKeyPath:@"canRemove" options:nil];
  [self->additionalFilesMenuButton setImage:[NSImage imageNamed:@"button-menu"]];
  [self->additionalFilesMenuButton setAlternateImage:[NSImage imageNamed:@"button-menu"]];
  NSMenu* menu = [[NSMenu alloc] init];
  [[menu addItemWithTitle:@"" action:nil keyEquivalent:@""] setTarget:nil];//dummy item
  [[menu addItemWithTitle:NSLocalizedString(@"Open defaults", @"Open defaults")
    action:@selector(additionalFilesOpenDefaults:) keyEquivalent:@""] setTarget:self];
  [[menu addItemWithTitle:NSLocalizedString(@"Save as defaults", @"Save as defaults")
    action:@selector(additionalFilesSetAsDefaults:) keyEquivalent:@""] setTarget:self];
  [self->additionalFilesMenuButton setMenu:menu];
  [menu release];
}
//end awakeFromNib

-(void) windowDidLoad
{
  NSPanel* window = (NSPanel*)[self window];
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
  [[PreferencesController sharedController] setAdditionalFilesPaths:[self->additionalFilesTableView additionalFilesPaths]];
}
//end additionalFilesOpenDefaults:

@end
