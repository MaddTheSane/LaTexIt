//  PreferencesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"
#import "LaTeXiTPreferencesKeys.h"

extern NSString* SpellCheckingDidChangeNotification;

extern NSString* GeneralToolbarItemIdentifier;
extern NSString* EditionToolbarItemIdentifier;
extern NSString* PreambleToolbarItemIdentifier;
extern NSString* CompositionToolbarItemIdentifier;
extern NSString* ServiceToolbarItemIdentifier;
extern NSString* AdvancedToolbarItemIdentifier;
extern NSString* WebToolbarItemIdentifier;

@class EncapsulationTableView;
@class PreamblesController;
@class LineCountTextView;
@class SMLSyntaxColouring;
@class TextShortcutsTableView;
@interface PreferencesController : NSWindowController {
  IBOutlet NSView*        generalView;
  IBOutlet NSView*        editionView;
  IBOutlet NSView*        preamblesView;
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

  IBOutlet NSButton*          reduceTextAreaButton;

  IBOutlet NSTextField*       fontTextField;
  SMLSyntaxColouring*         exampleSyntaxColouring;
  IBOutlet NSTextView*        exampleTextView;
  
  IBOutlet TextShortcutsTableView* textShortcutsTableView;
  IBOutlet NSButton*               removeTextShortcutsButton;

  IBOutlet NSTableView*       preamblesTableView;
  IBOutlet LineCountTextView* preambleTextView;
  IBOutlet NSButton*          addPreambleButton;
  IBOutlet NSButton*          removePreambleButton;

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

  IBOutlet NSPopUpButton* servicePreamblePopUpButton;
  IBOutlet NSMatrix*      serviceRespectsPointSizeMatrix;
  IBOutlet NSMatrix*      serviceRespectsColorMatrix;
  IBOutlet NSButton*      serviceRespectsBaselineButton;
  IBOutlet NSButton*      serviceUsesHistoryButton;
  IBOutlet NSButton*      serviceWarningLinkBackButton;
  IBOutlet NSTableView*   serviceShortcutsTableView;
  IBOutlet NSButton*      serviceWarningShortcutConflict;
  IBOutlet NSTextField*   serviceRelaunchWarning;

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
  
  NSObjectController*  selfController;
  PreamblesController* preamblesController;
  NSMutableArray* preambles;

  IBOutlet NSPopUpButton* latexisationSelectedPreamblePopUpButton;
  IBOutlet NSPopUpButton* serviceSelectedPreamblePopUpButton;
  NSDictionary*  latexisationSelectedPreamble;
  NSDictionary*  serviceSelectedPreamble;
  NSIndexSet*   draggedRowIndexes;
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
-(IBAction) changeReduceTextArea:(id)sender;
-(IBAction) resetSelectedPreambleToDefault:(id)sender;
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

-(NSMutableArray*) preambles;
-(NSAttributedString*) preambleForLatexisation;
-(NSAttributedString*) preambleForService;

-(NSDictionary*) latexisationSelectedPreamble;
-(void)          setLatexisationSelectedPreamble:(NSDictionary*)preamble;
-(NSDictionary*) serviceSelectedPreamble;
-(void)          setServiceSelectedPreamble:(NSDictionary*)preamble;

-(void) commitChanges;

@end
