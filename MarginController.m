//
//  MarginController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/07/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "MarginController.h"

#import "PreferencesController.h"

@interface MarginController (PrivateAPI)
-(void) _updateWithUserDefaults;
@end

@implementation MarginController


//The init method can be called several times, it will only be applied once on the singleton
-(id) init
{
  if (![super initWithWindowNibName:@"Margin"])
    return nil;
  return self;
}

-(void) _updateWithUserDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [topMarginButton setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
  [leftMarginButton setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
  [rightMarginButton setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
  [bottomMarginButton setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
}

-(IBAction) showWindow:(id)sender
{
  if (![[self window] isVisible])
    [self _updateWithUserDefaults];
  [super showWindow:sender];
}

//initializes the controls with default values
-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"margins"];
  [self _updateWithUserDefaults];
}

//resets the controls with default values
-(void) windowWillClose:(NSNotification *)aNotification
{
  [self _updateWithUserDefaults];
}

-(float) topMargin
{
  return [topMarginButton floatValue];
}

-(float) leftMargin
{
  return [leftMarginButton floatValue];
}

-(float) rightMargin
{
  return [rightMarginButton floatValue];
}

-(float) bottomMargin
{
  return [bottomMarginButton floatValue];
}

-(IBAction) makeDefaultsMargins:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setFloat:[topMarginButton    floatValue] forKey:AdditionalTopMarginKey];
  [userDefaults setFloat:[leftMarginButton   floatValue] forKey:AdditionalLeftMarginKey];
  [userDefaults setFloat:[rightMarginButton  floatValue] forKey:AdditionalRightMarginKey];
  [userDefaults setFloat:[bottomMarginButton floatValue] forKey:AdditionalBottomMarginKey];
}

@end
