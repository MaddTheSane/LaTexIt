//  PreferencesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import <Cocoa/Cocoa.h>

extern NSString* DragExportTypeKey;
extern NSString* DragExportJpegColorKey;
extern NSString* DragExportJpegQualityKey;
extern NSString* DefaultColorKey;
extern NSString* DefaultPointSizeKey;
extern NSString* DefaultModeKey;
extern NSString* DefaultPreambleAttributedKey;
extern NSString* DefaultFontKey;
extern NSString* PdfLatexPathKey;
extern NSString* GsPathKey;
extern NSString* ServiceRespectsColorKey;
extern NSString* ServiceRespectsBaselineKey;
extern NSString* ServiceRespectsPointSizeKey;
extern NSString* AdditionalTopMarginKey;
extern NSString* AdditionalLeftMarginKey;
extern NSString* AdditionalRightMarginKey;
extern NSString* AdditionalBottomMarginKey;
extern NSString* AdvancedLibraryExportTypeKey;
extern NSString* AdvancedLibraryExportUseEncapsulationKey;
extern NSString* AdvancedLibraryExportEncapsulationTextKey;

extern NSString* SomePathDidChangeNotification;

@class LineCountTextView;
@interface PreferencesController : NSWindowController {

  IBOutlet NSTabView*     preferencesTabView;

  IBOutlet NSPopUpButton* dragExportPopupFormat;
  IBOutlet NSButton*      dragExportOptionsButton;
  IBOutlet NSPanel*       dragExportOptionsPane;
  IBOutlet NSButton*      dragExportJpegWarning;
  IBOutlet NSSlider*      dragExportJpegQualitySlider;
  IBOutlet NSTextField*   dragExportJpegQualityTextField;
  IBOutlet NSColorWell*   dragExportJpegColorWell;

  IBOutlet NSSegmentedControl* defaultModeSegmentedControl;
  IBOutlet NSTextField*        defaultPointSizeTextField;
  IBOutlet NSColorWell*        defaultColorColorWell;

  IBOutlet LineCountTextView* preambleTextView;
  IBOutlet NSButton*    selectFontButton;
  IBOutlet NSTextField* fontTextField;
  
  IBOutlet NSTextField* pdfLatexTextField;
  IBOutlet NSTextField* gsTextField;
  IBOutlet NSButton*    serviceRespectsColor;
  IBOutlet NSButton*    serviceRespectsBaseline;
  IBOutlet NSButton*    serviceRespectsPointSize;

  IBOutlet NSTextField* additionalTopMarginTextField;
  IBOutlet NSTextField* additionalLeftMarginTextField;
  IBOutlet NSTextField* additionalRightMarginTextField;
  IBOutlet NSTextField* additionalBottomMarginTextField;
  
  IBOutlet NSMatrix*    advancedLibraryStringExportMatrix;
  IBOutlet NSButton*    advancedLibraryStringExportCheckBox;
  IBOutlet NSTextField* advancedLibraryStringExportTextField;
  
  BOOL didChangePdfLatexTextField;
  BOOL didChangeGsTextField;
}

-(IBAction) dragExportPopupFormatDidChange:(id)sender;
-(IBAction) dragExportJpegQualitySliderDidChange:(id)sender;
-(IBAction) openOptions:(id)sender;
-(IBAction) closeOptionsPane:(id)sender;

-(IBAction) changeDefaultGeneralConfig:(id)sender;

-(IBAction) resetDefaultPreamble:(id)sender;
-(IBAction) selectFont:(id)sender;
-(IBAction) applyPreambleToOpenDocuments:(id)sender;
-(IBAction) applyPreambleToLibrary:(id)sender;

-(IBAction) changePath:(id)sender;
-(IBAction) changeServiceConfiguration:(id)sender;

-(IBAction) changeAdvancedConfiguration:(id)sender;

@end
