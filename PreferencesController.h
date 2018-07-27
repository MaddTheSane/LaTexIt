//  PreferencesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import <Cocoa/Cocoa.h>

extern NSString* GeneralToolbarItemIdentifier;
extern NSString* EditionToolbarItemIdentifier;
extern NSString* PreambleToolbarItemIdentifier;
extern NSString* CompositionToolbarItemIdentifier;
extern NSString* ServiceToolbarItemIdentifier;
extern NSString* AdvancedToolbarItemIdentifier;
extern NSString* WebToolbarItemIdentifier;

extern NSString* DragExportTypeKey;
extern NSString* DragExportJpegColorKey;
extern NSString* DragExportJpegQualityKey;
extern NSString* DefaultImageViewBackground;
extern NSString* DefaultColorKey;
extern NSString* DefaultPointSizeKey;
extern NSString* DefaultModeKey;
extern NSString* SyntaxColoringEnableKey;
extern NSString* SyntaxColoringTextForegroundColorKey;
extern NSString* SyntaxColoringTextBackgroundColorKey;
extern NSString* SyntaxColoringCommandColorKey;
extern NSString* SyntaxColoringMathsColorKey;
extern NSString* SyntaxColoringKeywordColorKey;
extern NSString* SyntaxColoringCommentColorKey;
extern NSString* DefaultPreambleAttributedKey;
extern NSString* DefaultFontKey;
extern NSString* CompositionModeKey;
extern NSString* PdfLatexPathKey;
extern NSString* XeLatexPathKey;
extern NSString* LatexPathKey;
extern NSString* DvipdfPathKey;
extern NSString* GsPathKey;
extern NSString* ServiceShortcutEnabledKey;
extern NSString* ServiceShortcutStringsKey;
extern NSString* ServiceRespectsColorKey;
extern NSString* ServiceRespectsBaselineKey;
extern NSString* ServiceRespectsPointSizeKey;
extern NSString* ServiceUsesHistoryKey;
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

extern NSString* LibraryViewRowTypeKey;

extern NSString* CheckForNewVersionsKey;

extern NSString* LatexPaletteGroupKey;
extern NSString* LatexPaletteFrameKey;
extern NSString* LatexPaletteDetailsStateKey;

extern NSString* SomePathDidChangeNotification;
extern NSString* CompositionModeDidChangeNotification;

typedef enum {PDFLATEX, LATEXDVIPDF, XELATEX} composition_mode_t; 

@class EncapsulationTableView;
@class LineCountTextView;
@class SMLSyntaxColouring;
@interface PreferencesController : NSWindowController {

  IBOutlet NSView*        generalView;
  IBOutlet NSView*        editionView;
  IBOutlet NSView*        preambleView;
  IBOutlet NSView*        compositionView;
  IBOutlet NSView*        serviceView;
  IBOutlet NSView*        advancedView;
  IBOutlet NSView*        webView;
  IBOutlet NSView*        emptyView;
  NSMutableDictionary*    toolbarItems;

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

  IBOutlet NSColorWell*       syntaxColoringTextForegroundColorColorWell;
  IBOutlet NSColorWell*       syntaxColoringTextBackgroundColorColorWell;
  IBOutlet NSButton*          enableSyntaxColoringButton;
  IBOutlet NSColorWell*       syntaxColoringCommandColorColorWell;
  IBOutlet NSColorWell*       syntaxColoringMathsColorColorWell;
  IBOutlet NSColorWell*       syntaxColoringKeywordColorColorWell;
  IBOutlet NSColorWell*       syntaxColoringCommentColorColorWell;

  IBOutlet NSTextField*       fontTextField;
  SMLSyntaxColouring*         exampleSyntaxColouring;
  IBOutlet NSTextView*        exampleTextView;

  IBOutlet LineCountTextView* preambleTextView;

  IBOutlet NSMatrix*    compositionMatrix;  
  IBOutlet NSTextField* pdfLatexTextField;
  IBOutlet NSTextField* xeLatexTextField;
  IBOutlet NSTextField* latexTextField;
  IBOutlet NSTextField* dvipdfTextField;
  IBOutlet NSTextField* gsTextField;
  IBOutlet NSButton*    pdfLatexButton;
  IBOutlet NSButton*    xeLatexButton;
  IBOutlet NSButton*    latexButton;
  IBOutlet NSButton*    dvipdfButton;
  IBOutlet NSButton*    gsButton;

  IBOutlet NSMatrix*    serviceRespectsPointSizeMatrix;
  IBOutlet NSMatrix*    serviceRespectsColorMatrix;
  IBOutlet NSButton*    serviceRespectsBaselineButton;
  IBOutlet NSButton*    serviceUsesHistoryButton;
  IBOutlet NSButton*    serviceWarningLinkBackButton;
  IBOutlet NSTableView* serviceShortcutsTableView;
  IBOutlet NSButton*    serviceWarningShortcutConflict;

  IBOutlet NSTextField* additionalTopMarginTextField;
  IBOutlet NSTextField* additionalLeftMarginTextField;
  IBOutlet NSTextField* additionalRightMarginTextField;
  IBOutlet NSTextField* additionalBottomMarginTextField;
  
  IBOutlet EncapsulationTableView* encapsulationTableView;
  IBOutlet NSButton*               removeEncapsulationButton;
  
  IBOutlet NSButton* checkForNewVersionsButton;

  BOOL didChangePdfLatexTextField;
  BOOL didChangeXeLatexTextField;
  BOOL didChangeLatexTextField;
  BOOL didChangeDvipdfTextField;
  BOOL didChangeGsTextField;
  
  NSAlert* applyPreambleToLibraryAlert;
  NSImage* warningImage;
  
  NSTextView* shortcutTextView;
}

-(IBAction) nullAction:(id)sender;//useful to avoid some bad connections in Interface builder
-(IBAction) toolbarHit:(id)sender;
-(IBAction) dragExportPopupFormatDidChange:(id)sender;
-(IBAction) dragExportJpegQualitySliderDidChange:(id)sender;
-(IBAction) openOptionsForDragExport:(id)sender;
-(IBAction) closeOptionsPane:(id)sender;

-(IBAction) changeDefaultGeneralConfig:(id)sender;

-(IBAction) changeSyntaxColoringConfiguration:(id)sender;
-(IBAction) resetDefaultPreamble:(id)sender;
-(IBAction) selectFont:(id)sender;
-(IBAction) applyPreambleToOpenDocuments:(id)sender;
-(IBAction) applyPreambleToLibrary:(id)sender;

-(IBAction) changeCompositionMode:(id)sender;
-(IBAction) changePath:(id)sender;
-(IBAction) changeServiceConfiguration:(id)sender;
-(IBAction) gotoPreferencePane:(id)sender;

-(IBAction) changeAdditionalMargin:(id)sender;

-(IBAction) newEncapsulation:(id)sender;
-(IBAction) removeSelectedEncapsulations:(id)sender;

-(IBAction) checkForUpdatesChange:(id)sender;
-(IBAction) checkNow:(id)sender;
-(IBAction) gotoWebSite:(id)sender;

-(void) selectPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier;

@end
