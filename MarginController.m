//
//  MarginController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/07/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "MarginController.h"

#import "PreferencesController.h"

@implementation MarginController

static MarginController* sharedControllerInstance = nil; //the (private) singleton

+(void) initialize
{
  if (!sharedControllerInstance) //creating the singleton at first time
  {
    sharedControllerInstance = [[MarginController alloc] init];
  }
}

//accessing the singleton
+(MarginController*) marginController
{
  return sharedControllerInstance;
}

//The init method can be called several times, it will only be applied once on the singleton
-(id) init
{
  if (sharedControllerInstance)  //do not recreate an instance
  {
    [sharedControllerInstance retain]; //but makes a retain to allow a release
    return sharedControllerInstance;
  }
  else
  {
    self = [super initWithWindowNibName:@"Margin"];
    if (self)
    {
      NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
      [notificationCenter addObserver:self selector:@selector(windowWillClose:)
                                 name:NSWindowWillCloseNotification object:nil];
    }
    return self;
  }
}

-(void) dealloc
{
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter removeObserver:self];
  [super dealloc];
}

+(void) updateWithUserDefaults
{
  [sharedControllerInstance updateWithUserDefaults];
}

-(void) updateWithUserDefaults
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [sharedControllerInstance->topMarginButton setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
  [sharedControllerInstance->leftMarginButton setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
  [sharedControllerInstance->rightMarginButton setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
  [sharedControllerInstance->bottomMarginButton setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
}

//initializes the controls with default values
-(void) windowDidLoad
{
  [self updateWithUserDefaults];
}

//resets the controls with default values
-(void)windowWillClose:(NSNotification *)aNotification
{
  if ([aNotification object] == [self window])
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [sharedControllerInstance->topMarginButton setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
    [sharedControllerInstance->leftMarginButton setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
    [sharedControllerInstance->rightMarginButton setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
    [sharedControllerInstance->bottomMarginButton setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
  }
}

+(float) topMargin
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  return sharedControllerInstance->topMarginButton ? 
                  [sharedControllerInstance->topMarginButton floatValue] :
                  [userDefaults floatForKey:AdditionalTopMarginKey];
}

+(float) leftMargin
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  return sharedControllerInstance->leftMarginButton ? 
                  [sharedControllerInstance->leftMarginButton floatValue] :
                  [userDefaults floatForKey:AdditionalLeftMarginKey];
}

+(float) rightMargin
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  return sharedControllerInstance->rightMarginButton ? 
                  [sharedControllerInstance->rightMarginButton floatValue] :
                  [userDefaults floatForKey:AdditionalRightMarginKey];
}

+(float) bottomMargin
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  return sharedControllerInstance->bottomMarginButton ? 
                  [sharedControllerInstance->bottomMarginButton floatValue] :
                  [userDefaults floatForKey:AdditionalBottomMarginKey];
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
