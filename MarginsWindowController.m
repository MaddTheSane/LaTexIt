//
//  MarginsWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/07/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "MarginsWindowController.h"

#import "NSViewExtended.h"
#import "PreferencesController.h"

@interface MarginsWindowController (PrivateAPI)
-(void) _updateWithUserDefaults;
@end

@implementation MarginsWindowController

//The init method can be called several times, it will only be applied once on the singleton
-(id) init
{
  if (!((self = [super initWithWindowNibName:@"MarginsWindowController"])))
    return nil;
  return self;
}
//end init

//initializes the controls with default values
-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"margins"];
  [[self window] setTitle:NSLocalizedString(@"Custom margins", @"Custom margins")];
  [self->saveAsDefaultButton setTitle:NSLocalizedString(@"Save as default margins", @"Save as default margins")];
  [self->saveAsDefaultButton sizeToFit];
  [self->saveAsDefaultButton centerInSuperviewHorizontally:YES vertically:NO];
  [self _updateWithUserDefaults];
}
//end windowDidLoad

//resets the controls with default values
-(void) windowWillClose:(NSNotification *)aNotification
{
  [self _updateWithUserDefaults];
}
//end windowWillClose:

-(void) _updateWithUserDefaults
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  [topMarginButton setFloatValue:[preferencesController marginsAdditionalTop]];
  [leftMarginButton setFloatValue:[preferencesController marginsAdditionalLeft]];
  [rightMarginButton setFloatValue:[preferencesController marginsAdditionalRight]];
  [bottomMarginButton setFloatValue:[preferencesController marginsAdditionalBottom]];
}
//end _updateWithUserDefaults

-(IBAction) showWindow:(id)sender
{
  if (![[self window] isVisible])
    [self _updateWithUserDefaults];
  [super showWindow:sender];
}
//end showWindow:

-(CGFloat) topMargin
{
  return [topMarginButton floatValue];
}

-(CGFloat) leftMargin
{
  return [leftMarginButton floatValue];
}

-(CGFloat) rightMargin
{
  return [rightMarginButton floatValue];
}

-(CGFloat) bottomMargin
{
  return [bottomMarginButton floatValue];
}

-(IBAction) makeDefaultsMargins:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  [preferencesController setMarginsAdditionalTop:[topMarginButton floatValue]];
  [preferencesController setMarginsAdditionalLeft:[leftMarginButton floatValue]];
  [preferencesController setMarginsAdditionalRight:[rightMarginButton floatValue]];
  [preferencesController setMarginsAdditionalBottom:[bottomMarginButton floatValue]];
}
//end makeDefaultsMargins:

@end