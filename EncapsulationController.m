//
//  EncapsulationController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//this class is the "encapsulation palette", see encaspulationManager for more details

#import "EncapsulationController.h"

#import "AppController.h"
#import "EncapsulationView.h"
#import "PreferencesController.h"

@interface EncapsulationController (PrivateAPI)
-(void) _updateButtonStates;
-(void) _updateCurrentEncapsulation;
@end

@implementation EncapsulationController

static EncapsulationController* sharedControllerInstance = nil; //the (private) singleton

+(void) initialize
{
  if (!sharedControllerInstance) //creating the singleton at first time
    sharedControllerInstance = [[EncapsulationController alloc] init];
}

//accessing the singleton
+(EncapsulationController*) encapsulationController
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
    self = [super initWithWindowNibName:@"Encapsulation"];
    if (self)
    {
    }
    return self;
  }
}

-(void) dealloc
{
  [super dealloc];
}

//initializes the controls with default values
-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"Encapsulations"];
}

//the help button opens the "Advanced" pane of the preferences controller
-(IBAction) openHelp:(id)sender
{
  [[AppController appController] showPreferencesPaneWithIdentifier:@"advanced"];
}

@end
