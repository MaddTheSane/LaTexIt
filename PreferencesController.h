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
extern NSString* DefaultImageViewBackground;
extern NSString* DefaultColorKey;
extern NSString* DefaultPointSizeKey;
extern NSString* DefaultModeKey;
extern NSString* DefaultPreambleAttributedKey;
extern NSString* DefaultFontKey;
extern NSString* CompositionModeKey;
extern NSString* PdfLatexPathKey;
extern NSString* XeLatexPathKey;
extern NSString* DvipdfPathKey;
extern NSString* GsPathKey;
extern NSString* ServiceRespectsColorKey;
extern NSString* ServiceRespectsBaselineKey;
extern NSString* ServiceRespectsPointSizeKey;
extern NSString* AdditionalTopMarginKey;
extern NSString* AdditionalLeftMarginKey;
extern NSString* AdditionalRightMarginKey;
extern NSString* AdditionalBottomMarginKey;
extern NSString* EncapsulationsKey;
extern NSString* CurrentEncapsulationIndexKey;
extern NSString* LastEasterEggsDatesKey;

extern NSString* EncapsulationControllerVisibleAtStartupKey;
extern NSString* HistoryControllerVisibleAtStartupKey;
extern NSString* LatexPalettesControllerVisibleAtStartupKey;
extern NSString* LibraryControllerVisibleAtStartupKey;
extern NSString* MarginControllerVisibleAtStartupKey;

extern NSString* CheckForNewVersionsKey;

extern NSString* SomePathDidChangeNotification;
extern NSString* CompositionModeDidChangeNotification;

typedef enum {PDFLATEX, LATEXDVIPDF, XELATEX} composition_mode_t; 

@class EncapsulationTableView;
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
  
  IBOutlet NSColorWell*   defaultImageViewBackgroundColorWell;

  IBOutlet NSSegmentedControl* defaultModeSegmentedControl;
  IBOutlet NSTextField*        defaultPointSizeTextField;
  IBOutlet NSColorWell*        defaultColorColorWell;

  IBOutlet LineCountTextView* preambleTextView;
  IBOutlet NSButton*          selectFontButton;
  IBOutlet NSTextField*       fontTextField;

  IBOutlet NSMatrix*    compositionMatrix;  
  IBOutlet NSTextField* pdfLatexTextField;
  IBOutlet NSTextField* xeLatexTextField;
  IBOutlet NSTextField* dvipdfTextField;
  IBOutlet NSTextField* gsTextField;
  IBOutlet NSButton*    pdfLatexButton;
  IBOutlet NSButton*    xeLatexButton;
  IBOutlet NSButton*    dvipdfButton;
  IBOutlet NSButton*    gsButton;

  IBOutlet NSButton*    serviceRespectsBaseline;
  IBOutlet NSMatrix*    serviceRespectsPointSize;
  IBOutlet NSMatrix*    serviceRespectsColor;

  IBOutlet NSTextField* additionalTopMarginTextField;
  IBOutlet NSTextField* additionalLeftMarginTextField;
  IBOutlet NSTextField* additionalRightMarginTextField;
  IBOutlet NSTextField* additionalBottomMarginTextField;
  
  IBOutlet EncapsulationTableView* encapsulationTableView;
  IBOutlet NSButton*               removeEncapsulationButton;
  
  IBOutlet NSButton* checkForNewVersionsButton;

  BOOL didChangeXeLatexTextField;
  BOOL didChangePdfLatexTextField;
  BOOL didChangeDvipdfTextField;
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

-(IBAction) changeCompositionMode:(id)sender;
-(IBAction) changePath:(id)sender;
-(IBAction) changeServiceConfiguration:(id)sender;

-(IBAction) changeAdvancedConfiguration:(id)sender;

-(IBAction) newEncapsulation:(id)sender;
-(IBAction) removeSelectedEncapsulations:(id)sender;

-(IBAction) checkForUpdatesChange:(id)sender;
-(IBAction) checkNow:(id)sender;
-(IBAction) gotoWebSite:(id)sender;

-(void) selectPreferencesPaneWithIdentifier:(id)identifier;

@end
