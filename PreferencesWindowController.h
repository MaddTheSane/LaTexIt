//  PreferencesWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"
#import "PreferencesController.h"

extern NSToolbarItemIdentifier const GeneralToolbarItemIdentifier;
extern NSToolbarItemIdentifier const EditionToolbarItemIdentifier;
extern NSToolbarItemIdentifier const TemplatesToolbarItemIdentifier;
extern NSToolbarItemIdentifier const CompositionToolbarItemIdentifier;
extern NSToolbarItemIdentifier const LibraryToolbarItemIdentifier;
extern NSToolbarItemIdentifier const HistoryToolbarItemIdentifier;
extern NSToolbarItemIdentifier const ServiceToolbarItemIdentifier;
extern NSToolbarItemIdentifier const AdvancedToolbarItemIdentifier;
extern NSToolbarItemIdentifier const WebToolbarItemIdentifier;
extern NSToolbarItemIdentifier const PluginsToolbarItemIdentifier;

@class AdditionalFilesTableView;
@class CompositionConfigurationsProgramArgumentsTableView;
@class CompositionConfigurationsTableView;
@class EncapsulationsTableView;
@class ExportFormatOptionsPanes;
@class PreamblesTableView;
@class BodyTemplatesTableView;
@class LineCountTextView;
@class ServiceRegularExpressionFiltersTableView;
@class ServiceShortcutsTableView;
@class TextShortcutsTableView;
@class TextViewWithPlaceHolder;

@class Plugin;

@interface PreferencesWindowController : NSWindowController <NSTextFieldDelegate> {
  IBOutlet NSView*        generalView;
  IBOutlet NSView*        editionView;
  IBOutlet NSView*        templatesView;
  IBOutlet NSTabView*     templatesTabView;
  IBOutlet NSView*        compositionView;
  IBOutlet NSView*        libraryView;
  IBOutlet NSView*        historyView;
  IBOutlet NSView*        serviceView;
  IBOutlet NSView*        advancedView;
  IBOutlet NSView*        webView;
  IBOutlet NSView*        pluginsView;
  IBOutlet NSView*        emptyView;
  NSMutableDictionary*    toolbarItems;
  NSMutableDictionary*    viewsMinSizes;
  
  //general view
  IBOutlet NSPopUpButton*   generalExportFormatPopupButton;
  IBOutlet NSButton*        generalExportFormatOptionsButton;
  IBOutlet NSButton*        generalExportFormatJpegWarning;
  IBOutlet NSButton*        generalExportFormatSvgWarning;
  IBOutlet NSButton*        generalExportFormatMathMLWarning;
  ExportFormatOptionsPanes* generalExportFormatOptionsPanes;
  IBOutlet NSTextField*     generalExportScaleLabel;
  IBOutlet NSTextField*     generalExportScalePercentTextField;
  IBOutlet NSButton*        generalExportIncludeBackgroundColorCheckBox;
  IBOutlet NSColorWell*     generalDummyBackgroundColorWell;
  IBOutlet NSButton*        generalDummyBackgroundAutoStateButton;
  IBOutlet NSButton*        generalDoNotClipPreviewButton;
  IBOutlet NSNumberFormatter* generalPointSizeFormatter;

  IBOutlet NSSegmentedControl* generalLatexisationLaTeXModeSegmentedControl;
  IBOutlet NSTextField*        generalLatexisationFontSizeTextField;
  IBOutlet NSColorWell*        generalLatexisationFontColorWell;
  
  IBOutlet NSTextField*       marginsAdditionalTopTextField;
  IBOutlet NSTextField*       marginsAdditionalLeftTextField;
  IBOutlet NSTextField*       marginsAdditionalRightTextField;
  IBOutlet NSTextField*       marginsAdditionalBottomTextField;
  IBOutlet NSNumberFormatter* marginsAdditionalPointSizeFormatter;
  
  IBOutlet NSTextField*       editionFontNameTextField;
  IBOutlet NSButton*          editionSyntaxColoringStateButton;
  IBOutlet NSColorWell*       editionSyntaxColoringTextForegroundColorWell;
  IBOutlet NSColorWell*       editionSyntaxColoringTextBackgroundColorWell;
  IBOutlet NSColorWell*       editionSyntaxColoringCommandColorWell;
  IBOutlet NSColorWell*       editionSyntaxColoringCommentColorWell;
  IBOutlet NSColorWell*       editionSyntaxColoringKeywordColorWell;
  IBOutlet NSColorWell*       editionSyntaxColoringMathsColorWell;
  IBOutlet NSTextView*        editionSyntaxColouringTextView;
  IBOutlet NSButton*          editionSpellCheckingStateButton;
  IBOutlet NSButton*          editionTextAreaReducedButton;
  IBOutlet NSButton*          editionTabKeyInsertsSpacesCheckBox;
  IBOutlet NSTextField*       editionTabKeyInsertsSpacesTextField;
  IBOutlet NSStepper*         editionTabKeyInsertsSpacesStepper;
  IBOutlet NSTextField*       editionTabKeyInsertsSpacesSpacesTextField;
  IBOutlet NSButton*          editionAutoCompleteOnBackslashButton;
  
  IBOutlet TextShortcutsTableView* editionTextShortcutsTableView;
  IBOutlet NSButton*               editionTextShortcutsAddButton;
  IBOutlet NSButton*               editionTextShortcutsRemoveButton;

  IBOutlet PreamblesTableView* preamblesNamesTableView;
  IBOutlet LineCountTextView*  preamblesValueTextView;
  IBOutlet NSButton*           preamblesAddButton;
  IBOutlet NSButton*           preamblesRemoveButton;
  IBOutlet NSButton*           preamblesValueResetDefaultButton;
  IBOutlet NSButton*           preamblesNamesLatexisationPopUpButton;
  IBOutlet NSButton*           preamblesValueApplyToOpenedDocumentsButton;
  IBOutlet NSButton*           preamblesValueApplyToLibraryButton;

  IBOutlet BodyTemplatesTableView* bodyTemplatesNamesTableView;
  IBOutlet LineCountTextView*      bodyTemplatesHeadTextView;
  IBOutlet LineCountTextView*      bodyTemplatesTailTextView;
  IBOutlet NSButton*               bodyTemplatesAddButton;
  IBOutlet NSButton*               bodyTemplatesRemoveButton;
  IBOutlet NSButton*               bodyTemplatesNamesLatexisationPopUpButton;
  IBOutlet NSButton*               bodyTemplatesApplyToOpenedDocumentsButton;

  IBOutlet NSPopUpButton* compositionConfigurationsCurrentPopUpButton;
  IBOutlet NSPopUpButton* compositionConfigurationsCurrentEnginePopUpButton;
  IBOutlet NSTextField*   compositionConfigurationsCurrentPdfLaTeXPathTextField;
  IBOutlet NSButton*      compositionConfigurationsCurrentPdfLaTeXAdvancedButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentPdfLaTeXPathChangeButton;
  IBOutlet NSTextField*   compositionConfigurationsCurrentXeLaTeXPathTextField;
  IBOutlet NSButton*      compositionConfigurationsCurrentXeLaTeXAdvancedButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentXeLaTeXPathChangeButton;
  IBOutlet NSTextField*   compositionConfigurationsCurrentLuaLaTeXPathTextField;
  IBOutlet NSButton*      compositionConfigurationsCurrentLuaLaTeXAdvancedButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentLuaLaTeXPathChangeButton;
  IBOutlet NSTextField*   compositionConfigurationsCurrentLaTeXPathTextField;
  IBOutlet NSButton*      compositionConfigurationsCurrentLaTeXAdvancedButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentLaTeXPathChangeButton;
  IBOutlet NSTextField*   compositionConfigurationsCurrentDviPdfPathTextField;
  IBOutlet NSButton*      compositionConfigurationsCurrentDviPdfAdvancedButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentDviPdfPathChangeButton;
  IBOutlet NSTextField*   compositionConfigurationsCurrentGsPathTextField;
  IBOutlet NSButton*      compositionConfigurationsCurrentGsAdvancedButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentGsPathChangeButton;
  IBOutlet NSTextField*   compositionConfigurationsCurrentPsToPdfPathTextField;
  IBOutlet NSButton*      compositionConfigurationsCurrentPsToPdfAdvancedButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentPsToPdfPathChangeButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentLoginShellUsedButton;
  IBOutlet NSButton*      compositionConfigurationsCurrentResetButton;

  IBOutlet NSPanel*       compositionConfigurationsProgramArgumentsPanel;
  IBOutlet CompositionConfigurationsProgramArgumentsTableView* compositionConfigurationsProgramArgumentsTableView;
  IBOutlet NSButton*      compositionConfigurationsProgramArgumentsAddButton;
  IBOutlet NSButton*      compositionConfigurationsProgramArgumentsRemoveButton;
  IBOutlet NSButton*      compositionConfigurationsProgramArgumentsOkButton;
  
  IBOutlet NSPanel*       compositionConfigurationsManagerPanel;
  IBOutlet CompositionConfigurationsTableView* compositionConfigurationsManagerTableView;
  IBOutlet NSButton*      compositionConfigurationsManagerAddButton;
  IBOutlet NSButton*      compositionConfigurationsManagerRemoveButton;
  IBOutlet NSButton*      compositionConfigurationsManagerOkButton;
  
  IBOutlet NSTableView*   compositionConfigurationsAdditionalScriptsTableView;
  IBOutlet NSPopUpButton* compositionConfigurationsAdditionalScriptsTypePopUpButton;
  IBOutlet NSBox*         compositionConfigurationsAdditionalScriptsExistingBox;
  IBOutlet NSTextField*   compositionConfigurationsAdditionalScriptsExistingPathTextField;
  IBOutlet NSButton*      compositionConfigurationsAdditionalScriptsExistingPathChangeButton;
  IBOutlet NSBox*         compositionConfigurationsAdditionalScriptsDefiningBox;
  IBOutlet NSTextField*   compositionConfigurationsAdditionalScriptsDefiningShellTextField;
  IBOutlet NSTextView*    compositionConfigurationsAdditionalScriptsDefiningContentTextView;
           NSPanel*       compositionConfigurationsAdditionalScriptsHelpPanel;
  
  IBOutlet NSButton*    historySaveServiceResultsCheckbox;
  IBOutlet NSButton*    historyDeleteOldEntriesCheckbox;
  IBOutlet NSTextField* historyDeleteOldEntriesLimitTextField;
  IBOutlet NSStepper*   historyDeleteOldEntriesLimitStepper;
  IBOutlet NSButton*    historySmartCheckbox;
  IBOutlet NSButton*    historyVacuumButton;

  IBOutlet NSPopUpButton*             servicePreamblePopUpButton;
  IBOutlet NSPopUpButton*             serviceBodyTemplatesPopUpButton;
  IBOutlet NSMatrix*                  serviceRespectsPointSizeMatrix;
  IBOutlet NSTextField*               servicePointSizeFactorTextField;
  IBOutlet NSStepper*                 servicePointSizeFactorStepper;
  IBOutlet NSNumberFormatter*         servicePointSizeFactorFormatter;
  IBOutlet NSMatrix*                  serviceRespectsColorMatrix;
  IBOutlet NSButton*                  serviceRespectsBaselineButton;
  IBOutlet NSButton*                  serviceWarningLinkBackButton;
  IBOutlet NSButton*                  serviceUsesHistoryButton;
  IBOutlet ServiceShortcutsTableView* serviceShortcutsTableView;
  IBOutlet NSTextField*               serviceRelaunchWarning;
  IBOutlet ServiceRegularExpressionFiltersTableView* serviceRegularExpressionFiltersTableView;
  IBOutlet NSButton*                  serviceRegularExpressionsAddButton;
  IBOutlet NSButton*                  serviceRegularExpressionsRemoveButton;
  IBOutlet TextViewWithPlaceHolder*   serviceRegularExpressionsTestInputTextView;
  IBOutlet TextViewWithPlaceHolder*   serviceRegularExpressionsTestOutputTextView;
  IBOutlet NSButton*                  serviceRegularExpressionsHelpButton;
  
  IBOutlet AdditionalFilesTableView* additionalFilesTableView;
  IBOutlet NSButton*                 additionalFilesAddButton;
  IBOutlet NSButton*                 additionalFilesRemoveButton;
  IBOutlet NSButton*                 additionalFilesHelpButton;
  
  IBOutlet NSButton*      synchronizationNewDocumentsEnabledButton;
  IBOutlet NSButton*      synchronizationNewDocumentsSynchronizePreambleCheckBox;
  IBOutlet NSButton*      synchronizationNewDocumentsSynchronizeEnvironmentCheckBox;
  IBOutlet NSButton*      synchronizationNewDocumentsSynchronizeBodyCheckBox;
  IBOutlet NSTextField*   synchronizationNewDocumentsPathTextField;
  IBOutlet NSButton*      synchronizationNewDocumentsPathChangeButton;
  IBOutlet NSTableView*   synchronizationAdditionalScriptsTableView;
  IBOutlet NSPopUpButton* synchronizationAdditionalScriptsTypePopUpButton;
  IBOutlet NSBox*         synchronizationAdditionalScriptsExistingBox;
  IBOutlet NSTextField*   synchronizationAdditionalScriptsExistingPathTextField;
  IBOutlet NSButton*      synchronizationAdditionalScriptsExistingPathChangeButton;
  IBOutlet NSBox*         synchronizationAdditionalScriptsDefiningBox;
  IBOutlet NSTextField*   synchronizationAdditionalScriptsDefiningShellTextField;
  IBOutlet NSTextView*    synchronizationAdditionalScriptsDefiningContentTextView;
           NSPanel*       synchronizationAdditionalScriptsHelpPanel;
  
  IBOutlet NSButton*                encapsulationsEnabledCheckBox;
  IBOutlet NSTextField*             encapsulationsLabel1;
  IBOutlet NSTextField*             encapsulationsLabel2;
  IBOutlet NSTextField*             encapsulationsLabel3;
  IBOutlet EncapsulationsTableView* encapsulationsTableView;
  IBOutlet NSButton*                encapsulationsAddButton;
  IBOutlet NSButton*                encapsulationsRemoveButton;
  IBOutlet NSButton*                libraryVacuumButton;

  IBOutlet NSButton* updatesCheckUpdatesButton;
  IBOutlet NSButton* updatesCheckUpdatesNowButton;
  
  IBOutlet NSTableView* pluginsPluginTableView;
  IBOutlet NSBox*       pluginsConfigurationBox;
  Plugin*               pluginCurrentlySelected;
  
  NSAlert*           applyPreambleToLibraryAlert;
}

-(IBAction) toolbarHit:(id)sender;

-(IBAction) generalExportFormatOptionsOpen:(id)sender;
-(void)     exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

-(IBAction) editionChangeFont:(id)sender;
-(void)     changeFont:(id)sender;//delegate method

-(IBAction) preamblesValueResetDefault:(id)sender;
-(IBAction) preamblesValueApplyToOpenedDocuments:(id)sender;
-(IBAction) preamblesValueApplyToLibrary:(id)sender;

-(IBAction) bodyTemplatesApplyToOpenedDocuments:(id)sender;

-(IBAction) compositionConfigurationsProgramArgumentsOpen:(id)sender;
-(IBAction) compositionConfigurationsProgramArgumentsClose:(id)sender;

-(IBAction) compositionConfigurationsManagerOpen:(id)sender;
-(IBAction) compositionConfigurationsManagerClose:(id)sender;
-(IBAction) compositionConfigurationsAdditionalScriptsOpenHelp:(id)sender;
-(IBAction) compositionConfigurationsCurrentReset:(id)sender;

-(IBAction) serviceRegularExpressionsHelpOpen:(id)sender;

-(IBAction) additionalFilesHelpOpen:(id)sender;
-(IBAction) synchronizationAdditionalScriptsOpenHelp:(id)sender;

-(IBAction) updatesCheckNow:(id)sender;
-(IBAction) updatesGotoWebSite:(id)sender;

-(void) selectPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier options:(id)options;

@end
