//
//  CompositionConfigurationsWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/03/06.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationsWindowController.h"

#import "AppController.h"
#import "NSUserDefaultsControllerExtended.h"
#import "PreferencesController.h"
#import "PreferencesWindowController.h"
#import "Utils.h"

@interface CompositionConfigurationsWindowController (PrivateAPI)
-(void) compositionConfigurationsCurrentPopUpButtonSetSelectedIndex:(NSNumber*)index;
@end

@implementation CompositionConfigurationsWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"CompositionConfigurationsWindowController"])))
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
  //Composition configurations
  CompositionConfigurationsController* compositionConfigurationsController = [[PreferencesController sharedController] compositionConfigurationsController];
  [compositionConfigurationsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
  NSUserDefaultsController* userDefaultsController = [NSUserDefaultsController sharedUserDefaultsController];
  [userDefaultsController addObserver:self forKeyPath:[userDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]
    options:NSKeyValueObservingOptionNew context:nil];
  [self observeValueForKeyPath:@"arrangedObjects" ofObject:compositionConfigurationsController change:nil context:nil];
  [self observeValueForKeyPath:[userDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey] ofObject:userDefaultsController
    change:nil context:nil];
  [self->compositionConfigurationsCurrentPopUpButton setTarget:self];
  [self->compositionConfigurationsCurrentPopUpButton setAction:@selector(compositionConfigurationsManagerOpen:)];
}
//end awakeFromNib

-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"compositionConfiguration"];
  [[self window] setTitle:NSLocalizedString(@"Composition configurations", @"Composition configurations")];
}
//end windowDidLoad

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ((object == [[PreferencesController sharedController] compositionConfigurationsController]) && [keyPath isEqualToString:@"arrangedObjects"])
  {
    [self->compositionConfigurationsCurrentPopUpButton removeAllItems];
    [self->compositionConfigurationsCurrentPopUpButton addItemsWithTitles:
      [[[PreferencesController sharedController] compositionConfigurationsController]
        valueForKeyPath:[@"arrangedObjects." stringByAppendingString:CompositionConfigurationNameKey]]];
    [[self->compositionConfigurationsCurrentPopUpButton menu] addItem:[NSMenuItem separatorItem]];
    [self->compositionConfigurationsCurrentPopUpButton addItemWithTitle:NSLocalizedString(@"Edit the configurations...", @"Edit the configurations...")];
  }
  else if ((object == [NSUserDefaultsController sharedUserDefaultsController]) &&
           [keyPath isEqualToString:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]])
  {
    NSInteger index = [[PreferencesController sharedController] compositionConfigurationsDocumentIndex];
    //for some reason, this GUI modification must be delayed
    [self performSelector:@selector(compositionConfigurationsCurrentPopUpButtonSetSelectedIndex:) withObject:[NSNumber numberWithInteger:index] afterDelay:0.];
  }
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) compositionConfigurationsCurrentPopUpButtonSetSelectedIndex:(NSNumber*)index
{
  [self->compositionConfigurationsCurrentPopUpButton selectItemAtIndex:[index integerValue]];
}

-(IBAction) compositionConfigurationsManagerOpen:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSArray* compositionConfigurations = [preferencesController compositionConfigurations];
  NSInteger selectedIndex = [self->compositionConfigurationsCurrentPopUpButton indexOfSelectedItem];
  if (!IsBetween_i(1, selectedIndex+1, [compositionConfigurations count]))
  {
    [[AppController appController] showPreferencesPaneWithItemIdentifier:CompositionToolbarItemIdentifier options:nil];
    [[[AppController appController] preferencesWindowController] compositionConfigurationsManagerOpen:sender];
  }
  else
    [preferencesController setCompositionConfigurationsDocumentIndex:selectedIndex];
}
//end compositionConfigurationsManagerOpen:
@end
