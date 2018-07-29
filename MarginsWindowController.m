//
//  MarginsWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/07/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "MarginsWindowController.h"

#import "NSViewExtended.h"
#import "PreferencesController.h"

@interface MarginsWindowController (PrivateAPI)
-(void) _updateWithUserDefaults;
@end

@implementation MarginsWindowController

//The init method can be called several times, it will only be applied once on the singleton
-(instancetype) init
{
  if (!((self = [super initWithWindowNibName:@"MarginsWindowController"])))
    return nil;
  return self;
}
//end init

//initializes the controls with default values
-(void) windowDidLoad
{
  //get rid of formatter localization problems
  self->pointSizeFormatter.locale = [NSLocale currentLocale];
  self->pointSizeFormatter.groupingSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
  self->pointSizeFormatter.decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
  NSString* pointSizeZeroSymbol =
  [NSString stringWithFormat:@"0%@%0*d%@",
   self->pointSizeFormatter.decimalSeparator, 2, 0, 
   self->pointSizeFormatter.positiveSuffix];
  self->pointSizeFormatter.zeroSymbol = pointSizeZeroSymbol;
  
  [self.window setFrameAutosaveName:@"margins"];
  [self.window setTitle:NSLocalizedString(@"Custom margins", @"Custom margins")];
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
  topMarginButton.floatValue = preferencesController.marginsAdditionalTop;
  leftMarginButton.floatValue = preferencesController.marginsAdditionalLeft;
  rightMarginButton.floatValue = preferencesController.marginsAdditionalRight;
  bottomMarginButton.floatValue = preferencesController.marginsAdditionalBottom;
}
//end _updateWithUserDefaults

-(IBAction) showWindow:(id)sender
{
  if (!self.window.visible)
    [self _updateWithUserDefaults];
  [super showWindow:sender];
}
//end showWindow:

-(CGFloat) topMargin
{
  return topMarginButton.floatValue;
}

-(CGFloat) leftMargin
{
  return leftMarginButton.floatValue;
}

-(CGFloat) rightMargin
{
  return rightMarginButton.floatValue;
}

-(CGFloat) bottomMargin
{
  return bottomMarginButton.floatValue;
}

-(IBAction) makeDefaultsMargins:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  preferencesController.marginsAdditionalTop = topMarginButton.floatValue;
  preferencesController.marginsAdditionalLeft = leftMarginButton.floatValue;
  preferencesController.marginsAdditionalRight = rightMarginButton.floatValue;
  preferencesController.marginsAdditionalBottom = bottomMarginButton.floatValue;
}
//end makeDefaultsMargins:

@end
