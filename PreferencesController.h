//  PreferencesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import <Cocoa/Cocoa.h>

typedef enum {EXPORT_FORMAT_PDF, EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS,
              EXPORT_FORMAT_EPS, EXPORT_FORMAT_TIFF, EXPORT_FORMAT_PNG, EXPORT_FORMAT_JPEG} export_format_t;

extern NSString* SpellCheckingDidChangeNotification;

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
extern NSString* DragExportScaleAsPercentKey;
extern NSString* DefaultImageViewBackgroundKey;
extern NSString* DefaultAutomaticHighContrastedPreviewBackgroundKey;
extern NSString* DefaultColorKey;
extern NSString* DefaultPointSizeKey;
extern NSString* DefaultModeKey;
extern NSString* SpellCheckingEnableKey;
extern NSString* SyntaxColoringEnableKey;
extern NSString* SyntaxColoringTextForegroundColorKey;
extern NSString* SyntaxColoringTextBackgroundColorKey;
extern NSString* SyntaxColoringCommandColorKey;
extern NSString* SyntaxColoringMathsColorKey;
extern NSString* SyntaxColoringKeywordColorKey;
extern NSString* SyntaxColoringCommentColorKey;
extern NSString* DefaultPreambleAttributedKey;
extern NSString* DefaultFontKey;
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
extern NSString* TextShortcutsKey;
extern NSString* CompositionConfigurationsKey;
extern NSString* CurrentCompositionConfigurationIndexKey;
extern NSString* CompositionConfigurationNameKey;
extern NSString* CompositionConfigurationIsDefaultKey;
extern NSString* CompositionConfigurationCompositionModeKey;
extern NSString* CompositionConfigurationCompositionModeKey;
extern NSString* CompositionConfigurationPdfLatexPathKey;
extern NSString* CompositionConfigurationPs2PdfPathKey;
extern NSString* CompositionConfigurationXeLatexPathKey;
extern NSString* CompositionConfigurationLatexPathKey;
extern NSString* CompositionConfigurationDvipdfPathKey;
extern NSString* CompositionConfigurationGsPathKey;
extern NSString* CompositionConfigurationAdditionalProcessingScriptsKey;
extern NSString* LastEasterEggsDatesKey;

extern NSString* CompositionConfigurationControllerVisibleAtStartupKey;
extern NSString* EncapsulationControllerVisibleAtStartupKey;
extern NSString* HistoryControllerVisibleAtStartupKey;
extern NSString* LatexPalettesControllerVisibleAtStartupKey;
extern NSString* LibraryControllerVisibleAtStartupKey;
extern NSString* MarginControllerVisibleAtStartupKey;

extern NSString* LibraryViewRowTypeKey;
extern NSString* LibraryDisplayPreviewPanelKey;
extern NSString* HistoryDisplayPreviewPanelKey;

extern NSString* CheckForNewVersionsKey;

extern NSString* LatexPaletteGroupKey;
extern NSString* LatexPaletteFrameKey;
extern NSString* LatexPaletteDetailsStateKey;

extern NSString* ScriptEnabledKey;
extern NSString* ScriptSourceTypeKey;
extern NSString* ScriptShellKey;
extern NSString* ScriptBodyKey;
extern NSString* ScriptFileKey;

extern NSString* SomePathDidChangeNotification;
extern NSString* CompositionModeDidChangeNotification;
extern NSString* CurrentCompositionConfigurationDidChangeNotification;

typedef enum {COMPOSITION_MODE_PDFLATEX, COMPOSITION_MODE_LATEXDVIPDF, COMPOSITION_MODE_XELATEX} composition_mode_t;
typedef enum {SCRIPT_SOURCE_STRING, SCRIPT_SOURCE_FILE} script_source_t;
typedef enum {SCRIPT_PLACE_PREPROCESSING, SCRIPT_PLACE_MIDDLEPROCESSING, SCRIPT_PLACE_POSTPROCESSING} script_place_t;

@class EncapsulationTableView;
@class LineCountTextView;
@class SMLSyntaxColouring;
@class TextShortcutsTableView;
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
  IBOutlet NSTextField*   dragExportScaleAsPercentTextField;
  
  IBOutlet NSColorWell*   defaultImageViewBackgroundColorWell;

  IBOutlet NSSegmentedControl* defaultModeSegmentedControl;
  IBOutlet NSTextField*        defaultPointSizeTextField;
  IBOutlet NSColorWell*        defaultColorColorWell;
  
  IBOutlet NSButton*          spellCheckingButton;

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
  
  IBOutlet TextShortcutsTableView* textShortcutsTableView;
  IBOutlet NSButton*               removeTextShortcutsButton;


  IBOutlet LineCountTextView* preambleTextView;

  IBOutlet NSPopUpButton* compositionSelectionPopUpButton;
  IBOutlet NSPanel*       compositionSelectionPanel;
  IBOutlet NSTableView*   compositionConfigurationTableView;
  IBOutlet NSButton*      compositionConfigurationRemoveButton;
  IBOutlet NSMatrix*      compositionMatrix;  
  IBOutlet NSTextField*   pdfLatexTextField;
  IBOutlet NSTextField*   xeLatexTextField;
  IBOutlet NSTextField*   latexTextField;
  IBOutlet NSTextField*   dvipdfTextField;
  IBOutlet NSTextField*   gsTextField;
  IBOutlet NSTextField*   ps2pdfTextField;
  IBOutlet NSButton*      pdfLatexButton;
  IBOutlet NSButton*      xeLatexButton;
  IBOutlet NSButton*      latexButton;
  IBOutlet NSButton*      dvipdfButton;
  IBOutlet NSButton*      gsButton;

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
  
  IBOutlet NSTableView*   scriptsTableView;
  IBOutlet NSPopUpButton* scriptsSourceTypePopUpButton;
  IBOutlet NSBox*         scriptsScriptSelectionBox;
  IBOutlet NSBox*         scriptsScriptDefinitionBox;
  IBOutlet NSTextField*   scriptsScriptSelectionTextField;
  IBOutlet NSButton*      scriptsScriptSelectionButton;
  IBOutlet NSTextField*   scriptsScriptDefinitionShellTextField;
  IBOutlet NSTextView*    scriptsScriptDefinitionBodyTextView;
  IBOutlet NSPanel*       scriptsHelpPanel;

  BOOL didChangePdfLatexTextField;
  BOOL didChangeXeLatexTextField;
  BOOL didChangeLatexTextField;
  BOOL didChangeDvipdfTextField;
  BOOL didChangeGsTextField;
  BOOL didChangePs2PdfTextField;
  
  NSAlert* applyPreambleToLibraryAlert;
  NSImage* warningImage;
  
  NSTextView* shortcutTextView;
}

+(PreferencesController*) sharedController;
+(NSDictionary*) defaultAdditionalScript;
+(NSDictionary*) defaultAdditionalScripts;
+(id)   currentCompositionConfigurationObjectForKey:(id)key;
+(void) currentCompositionConfigurationSetObject:(id)object forKey:(id)key;

-(IBAction) nullAction:(id)sender;//useful to avoid some bad connections in Interface builder
-(IBAction) toolbarHit:(id)sender;
-(IBAction) dragExportPopupFormatDidChange:(id)sender;
-(IBAction) dragExportJpegQualitySliderDidChange:(id)sender;
-(IBAction) openOptionsForDragExport:(id)sender;
-(IBAction) closeOptionsPane:(id)sender;

-(IBAction) changeDefaultGeneralConfig:(id)sender;

-(IBAction) changeSpellChecking:(id)sender;
-(IBAction) changeSyntaxColoringConfiguration:(id)sender;
-(IBAction) resetDefaultPreamble:(id)sender;
-(IBAction) selectFont:(id)sender;
-(IBAction) applyPreambleToOpenDocuments:(id)sender;
-(IBAction) applyPreambleToLibrary:(id)sender;

-(IBAction) changeCompositionSelection:(id)sender;
-(IBAction) closeCompositionSelectionPanel:(id)sender;
-(IBAction) changeCompositionMode:(id)sender;
-(IBAction) changePath:(id)sender;
-(IBAction) changeServiceConfiguration:(id)sender;
-(IBAction) gotoPreferencePane:(id)sender;

-(IBAction) changeScriptsConfiguration:(id)sender;
-(IBAction) selectScript:(id)sender;
-(IBAction) showScriptHelp:(id)sender;

-(IBAction) changeAdditionalMargin:(id)sender;

-(IBAction) newEncapsulation:(id)sender;
-(IBAction) removeSelectedEncapsulations:(id)sender;

-(IBAction) newTextShortcut:(id)sender;
-(IBAction) removeSelectedTextShortcuts:(id)sender;

-(IBAction) newCompositionConfiguration:(id)sender;
-(IBAction) removeSelectedCompositionConfigurations:(id)sender;

-(IBAction) checkForUpdatesChange:(id)sender;
-(IBAction) checkNow:(id)sender;
-(IBAction) gotoWebSite:(id)sender;

-(void) selectPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier;

@end
