//
//  Automator_CreateEquations.h
//  Automator_CreateEquations
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Automator/AMBundleAction.h>

@class ExportFormatOptionsPanes;

@interface Automator_CreateEquations : AMBundleAction 
{
  IBOutlet NSTabView*   tabView;
  IBOutlet NSTextField* warningMessage;

  IBOutlet NSView*             parametersView;
  IBOutlet NSSegmentedControl* latexModeSegmentedControl;
  IBOutlet NSTextField*        fontSizeLabel;
  IBOutlet NSTextField*        fontSizeTextField;
  IBOutlet NSStepper*          fontSizeStepper;
  IBOutlet NSTextField*        fontColorLabel;
  IBOutlet NSColorWell*        fontColorWell;

  IBOutlet NSPopUpButton* exportFormatPopupButton;
  IBOutlet NSButton*      exportFormatOptionsButton;
  
  IBOutlet NSTextField*   createEquationsOptionsLabel;
  IBOutlet NSPopUpButton* createEquationsOptionsPopUpButton;

  ExportFormatOptionsPanes* generalExportFormatOptionsPanes;
  BOOL latexitPreferencesAvailable;
  NSUInteger uniqueId;
  BOOL fromArchive;
}

-(id) runWithInput:(id)input fromAction:(AMAction*)anAction error:(NSDictionary**)errorInfo;
-(NSString*) extractFromObject:(id)object preamble:(NSString**)outPeamble body:(NSString**)outBody isFilePath:(BOOL*)isFilePath
                         error:(NSError**)error;
                         
-(IBAction) generalExportFormatOptionsOpen:(id)sender;

@end
