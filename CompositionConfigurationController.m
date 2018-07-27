//
//  CompositionConfigurationController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationController.h"

#import "AppController.h"
#import "CompositionConfigurationManager.h"
#import "NSPopUpButtonExtended.h"
#import "PreferencesController.h"

@interface CompositionConfigurationController (PrivateAPI)
-(void) _updateButtonStates:(NSNotification*)notification;
@end

@implementation CompositionConfigurationController

-(id) init
{
  if (![super initWithWindowNibName:@"CompositionConfiguration"])
    return nil;
  return self;
}

-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"compositionConfiguration"];
  [self _updateButtonStates:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateButtonStates:)
                                               name:CompositionConfigurationsDidChangeNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updateButtonStates:)
                                               name:CurrentCompositionConfigurationDidChangeNotification object:nil];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(IBAction) changeCompositionConfiguration:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender && ([sender selectedTag] == -1))
  {
    [[AppController appController] showPreferencesPaneWithItemIdentifier:CompositionToolbarItemIdentifier];
    [[PreferencesController sharedController] changeCompositionSelection:sender];
  }
  else if (sender)
  {
    [userDefaults setInteger:[sender selectedTag] forKey:CurrentCompositionConfigurationIndexKey];
    [[NSNotificationCenter defaultCenter]
      postNotificationName:CurrentCompositionConfigurationDidChangeNotification object:compositionConfigurationsPopUpButton];
  }
}

-(void) _updateButtonStates:(NSNotification*)notification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (!notification || [[notification name] isEqualToString:CompositionConfigurationsDidChangeNotification]
                    || [[notification name] isEqualToString:CurrentCompositionConfigurationDidChangeNotification])
  {
    [compositionConfigurationsPopUpButton removeAllItems];
    NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
    unsigned int i = 0;
    for(i = 0 ; i<[compositionConfigurations count] ; ++i)
    {
      NSString* title = [[compositionConfigurations objectAtIndex:i] objectForKey:CompositionConfigurationNameKey];
      [[compositionConfigurationsPopUpButton menu] addItemWithTitle:title action:nil keyEquivalent:@""];
      [[compositionConfigurationsPopUpButton lastItem] setTag:i];
    }
    [[compositionConfigurationsPopUpButton menu] addItem:[NSMenuItem separatorItem]];
    [[compositionConfigurationsPopUpButton menu] addItemWithTitle:
      NSLocalizedString(@"Edit configurations list...", @"Edit configurations list...") action:nil keyEquivalent:@""];
    [[compositionConfigurationsPopUpButton lastItem] setTag:-1];
    [compositionConfigurationsPopUpButton selectItemWithTag:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];

    [compositionConfigurationsPopUpButton selectItemWithTag:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
  }
}
@end
