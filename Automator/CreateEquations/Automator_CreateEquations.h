//
//  Automator_CreateEquations.h
//  Automator_CreateEquations
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
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

-(nullable id) runWithInput:(nullable id)input error:(NSError * _Nullable __autoreleasing * _Nullable)error;
-(nullable NSString*) extractFromObject:(nullable id)object preamble:(NSString*_Nullable*_Nullable)outPeamble body:(NSString*_Nullable*_Nullable)outBody isFilePath:(BOOL*_Nullable)isFilePath
                         error:(NSError * _Nullable __autoreleasing * _Nullable)error;
                         
-(IBAction) generalExportFormatOptionsOpen:(nullable id)sender;

@end
