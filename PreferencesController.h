//
//  PreferencesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/03/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

extern NSString* LaTeXiTAppKey;
extern NSString* Old_LaTeXiTAppKey;

extern NSString* LaTeXiTVersionKey;
extern NSString* DocumentStyleKey;
extern NSString* DragExportTypeKey;
extern NSString* DragExportJpegColorKey;
extern NSString* DragExportJpegQualityKey;
extern NSString* DragExportPDFWOFGsWriteEngineKey;
extern NSString* DragExportPDFWOFGsPDFCompatibilityLevelKey;
extern NSString* DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey;

extern NSString* DragExportSvgPdfToSvgPathKey;
extern NSString* DragExportTextExportPreambleKey;
extern NSString* DragExportTextExportEnvironmentKey;
extern NSString* DragExportTextExportBodyKey;
extern NSString* DragExportScaleAsPercentKey;
extern NSString* DefaultImageViewBackgroundKey;
extern NSString* DefaultAutomaticHighContrastedPreviewBackgroundKey;
extern NSString* DefaultDoNotClipPreviewKey;
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
extern NSString* ReducedTextAreaStateKey;
extern NSString* DefaultFontKey;
extern NSString* PreamblesKey;
extern NSString* LatexisationSelectedPreambleIndexKey;
extern NSString* BodyTemplatesKey;
extern NSString* LatexisationSelectedBodyTemplateIndexKey;
extern NSString* ServiceSelectedPreambleIndexKey;
extern NSString* ServiceSelectedBodyTemplateIndexKey;
extern NSString* ServiceShortcutsKey;
extern NSString* ServiceShortcutEnabledKey;
extern NSString* ServiceShortcutClipBoardOptionKey;
extern NSString* ServiceShortcutStringKey;
extern NSString* ServiceShortcutIdentifierKey;
extern NSString* ServiceRespectsColorKey;
extern NSString* ServiceRespectsBaselineKey;
extern NSString* ServiceRespectsPointSizeKey;
extern NSString* ServicePointSizeFactorKey;
extern NSString* ServiceUsesHistoryKey;
extern NSString* ServiceRegularExpressionFiltersKey;
extern NSString* ServiceRegularExpressionFilterEnabledKey;
extern NSString* ServiceRegularExpressionFilterInputPatternKey;
extern NSString* ServiceRegularExpressionFilterOutputPatternKey;
extern NSString* AdditionalTopMarginKey;
extern NSString* AdditionalLeftMarginKey;
extern NSString* AdditionalRightMarginKey;
extern NSString* AdditionalBottomMarginKey;
extern NSString* EncapsulationsEnabledKey;
extern NSString* EncapsulationsKey;
extern NSString* CurrentEncapsulationIndexKey;
extern NSString* TextShortcutsKey;
extern NSString* CompositionConfigurationsKey;
extern NSString* CompositionConfigurationDocumentIndexKey;
extern NSString* LastEasterEggsDatesKey;

extern NSString* EditionTabKeyInsertsSpacesEnabledKey;
extern NSString* EditionTabKeyInsertsSpacesCountKey;

extern NSString* CompositionConfigurationNameKey;
extern NSString* CompositionConfigurationIsDefaultKey;
extern NSString* CompositionConfigurationCompositionModeKey;
extern NSString* CompositionConfigurationUseLoginShellKey;
extern NSString* CompositionConfigurationPdfLatexPathKey;
extern NSString* CompositionConfigurationPsToPdfPathKey;
extern NSString* CompositionConfigurationXeLatexPathKey;
extern NSString* CompositionConfigurationLuaLatexPathKey;
extern NSString* CompositionConfigurationLatexPathKey;
extern NSString* CompositionConfigurationDviPdfPathKey;
extern NSString* CompositionConfigurationGsPathKey;
extern NSString* CompositionConfigurationProgramArgumentsKey;
extern NSString* CompositionConfigurationAdditionalProcessingScriptsKey;
extern NSString* CompositionConfigurationAdditionalProcessingScriptEnabledKey;
extern NSString* CompositionConfigurationAdditionalProcessingScriptTypeKey;
extern NSString* CompositionConfigurationAdditionalProcessingScriptPathKey;
extern NSString* CompositionConfigurationAdditionalProcessingScriptShellKey;
extern NSString* CompositionConfigurationAdditionalProcessingScriptContentKey;

extern NSString* HistoryDeleteOldEntriesEnabledKey;
extern NSString* HistoryDeleteOldEntriesLimitKey;
extern NSString* HistorySmartEnabledKey;

extern NSString* CompositionConfigurationsControllerVisibleAtStartupKey;
extern NSString* EncapsulationsControllerVisibleAtStartupKey;
extern NSString* HistoryControllerVisibleAtStartupKey;
extern NSString* LatexPalettesControllerVisibleAtStartupKey;
extern NSString* LibraryControllerVisibleAtStartupKey;
extern NSString* MarginControllerVisibleAtStartupKey;
extern NSString* AdditionalFilesWindowControllerVisibleAtStartupKey;

extern NSString* LibraryPathKey;
extern NSString* LibraryViewRowTypeKey;
extern NSString* LibraryDisplayPreviewPanelKey;
extern NSString* HistoryDisplayPreviewPanelKey;

extern NSString* CheckForNewVersionsKey;

extern NSString* LatexPaletteGroupKey;
extern NSString* LatexPaletteFrameKey;
extern NSString* LatexPaletteDetailsStateKey;

extern NSString* ShowWhiteColorWarningKey;

extern NSString* CompositionModeDidChangeNotification;
extern NSString* CurrentCompositionConfigurationDidChangeNotification;

extern NSString* AdditionalFilesPathsKey;
extern NSString* SynchronizationNewDocumentsEnabledKey;
extern NSString* SynchronizationNewDocumentsSynchronizePreambleKey;
extern NSString* SynchronizationNewDocumentsSynchronizeEnvironmentKey;
extern NSString* SynchronizationNewDocumentsSynchronizeBodyKey;
extern NSString* SynchronizationNewDocumentsPathKey;
extern NSString* SynchronizationAdditionalScriptsKey;

@class AdditionalFilesController;
@class BodyTemplatesController;
@class CompositionConfigurationsController;
@class EncapsulationsController;
@class PreamblesController;
@class ServiceRegularExpressionFiltersController;
@class SynchronizationAdditionalScriptsController;

@interface PreferencesController : NSObject {
  BOOL      isLaTeXiT;
  
  NSUndoManager* undoManager;

  NSArrayController*                          editionTextShortcutsController;
  PreamblesController*                        preamblesController;
  BodyTemplatesController*                    bodyTemplatesController;
  CompositionConfigurationsController*        compositionConfigurationsController;
  NSArrayController*                          serviceShortcutsController;
  ServiceRegularExpressionFiltersController*  serviceRegularExpressionFiltersController;
  AdditionalFilesController*                  additionalFilesController;
  EncapsulationsController*                   encapsulationsController;
  SynchronizationAdditionalScriptsController* synchronizationAdditionalScriptsController;
  
  export_format_t exportFormatCurrentSession;
}

@property (class, readonly) PreferencesController* sharedController;

@property (readonly, strong) NSUndoManager *undoManager;

@property (readonly) NSString* latexitVersion;

@property export_format_t exportFormatPersistent;
@property export_format_t exportFormatCurrentSession;


@property (copy) NSData* exportJpegBackgroundColorData;
@property (assign) NSColor* exportJpegBackgroundColor;
@property float exportJpegQualityPercent;
@property (copy) NSString* exportSvgPdfToSvgPath;
@property BOOL exportTextExportPreamble;
@property BOOL exportTextExportEnvironment;
@property BOOL exportTextExportBody;
@property CGFloat exportScalePercent;

@property (copy) NSString* exportPDFWOFGsWriteEngine;
@property (copy) NSString* exportPDFWOFGsPDFCompatibilityLevel;
@property BOOL exportPDFWOFMetaDataInvisibleGraphicsEnabled;

@property BOOL doNotClipPreview;

@property latex_mode_t latexisationLaTeXMode;
@property (readonly) CGFloat latexisationFontSize;
@property (readonly) NSData* latexisationFontColorData;
@property (readonly) NSColor* latexisationFontColor;

@property CGFloat marginsAdditionalLeft;
@property CGFloat marginsAdditionalRight;
@property CGFloat marginsAdditionalTop;
@property CGFloat marginsAdditionalBottom;

@property document_style_t documentStyle;
@property (readonly) BOOL documentIsReducedTextArea;
@property (readonly) NSData* documentImageViewBackgroundColorData;
@property (readonly) NSColor* documentImageViewBackgroundColor;
@property (readonly) BOOL documentUseAutomaticHighContrastedPreviewBackground;

@property (copy) NSData* editionFontData;
@property (assign) NSFont* editionFont;
@property (readonly) BOOL editionSyntaxColoringEnabled;
@property (readonly, copy) NSData *editionSyntaxColoringTextForegroundColorData;
@property (readonly, copy) NSColor *editionSyntaxColoringTextForegroundColor;
@property (readonly, copy) NSData *editionSyntaxColoringTextBackgroundColorData;
@property (readonly, copy) NSColor *editionSyntaxColoringTextBackgroundColor;
@property (readonly, copy) NSData *editionSyntaxColoringCommandColorData;
@property (readonly, copy) NSColor *editionSyntaxColoringCommandColor;
@property (readonly, copy) NSData *editionSyntaxColoringCommentColorData;
@property (readonly, copy) NSColor *editionSyntaxColoringCommentColor;
@property (readonly, copy) NSData *editionSyntaxColoringKeywordColorData;
@property (readonly, copy) NSColor *editionSyntaxColoringKeywordColor;
@property (readonly, copy) NSData *editionSyntaxColoringMathsColorData;
@property (readonly, copy) NSColor *editionSyntaxColoringMathsColor;
@property (readonly) BOOL editionTabKeyInsertsSpacesEnabled;
@property (readonly) NSUInteger editionTabKeyInsertsSpacesCount;

@property (readonly) NSArray* editionTextShortcuts;
@property (readonly, strong) NSArrayController *editionTextShortcutsController;

@property (readonly) NSArray* preambles;
@property (readonly) NSInteger preambleDocumentIndex;
@property (readonly) NSInteger preambleServiceIndex;
@property (readonly, copy) NSAttributedString *preambleDocumentAttributedString;
@property (readonly, copy) NSAttributedString *preambleServiceAttributedString;
@property (readonly, strong) PreamblesController *preamblesController;

@property (readonly) NSArray* bodyTemplates;
@property (readonly) NSArray* bodyTemplatesWithNone;
@property (readonly) NSInteger bodyTemplateDocumentIndex;
@property (readonly) NSInteger bodyTemplateServiceIndex;
@property (readonly) NSDictionary* bodyTemplateDocumentDictionary;
@property (readonly) NSDictionary* bodyTemplateServiceDictionary;
@property (readonly, strong) BodyTemplatesController *bodyTemplatesController;

@property (readonly, strong) CompositionConfigurationsController *compositionConfigurationsController;
@property (copy) NSArray* compositionConfigurations;

@property NSInteger   compositionConfigurationsDocumentIndex;
@property (copy) NSDictionary* compositionConfigurationDocument;

-(void)               setCompositionConfigurationDocumentProgramPath:(NSString*)value forKey:(NSString*)key;

@property (readonly) BOOL historySaveServicesResultsEnabled;
@property (readonly) BOOL historyDeleteOldEntriesEnabled;
@property (readonly) NSNumber* historyDeleteOldEntriesLimit;
@property (readonly) BOOL historySmartEnabled;

-(NSString*)          serviceDescriptionForIdentifier:(service_identifier_t)identifier;
@property (copy) NSArray* serviceShortcuts;
@property (readonly, strong) NSArrayController *serviceShortcutsController;
-(BOOL) changeServiceShortcutsWithDiscrepancyFallback:(change_service_shortcuts_fallback_t)discrepancyFallback
                               authenticationFallback:(change_service_shortcuts_fallback_t)authenticationFallback;
@property (copy) NSArray<NSString*>* serviceRegularExpressionFilters;
@property (readonly, strong) ServiceRegularExpressionFiltersController *serviceRegularExpressionFiltersController;

@property (readonly) BOOL encapsulationsEnabled;
@property (readonly) NSArray* encapsulations;
@property (readonly) NSInteger encapsulationsSelectedIndex;
@property (readonly) NSString* encapsulationSelected;
@property (readonly, strong) EncapsulationsController *encapsulationsController;

@property (copy) NSArray<NSString*>* additionalFilesPaths;
@property (readonly, strong) AdditionalFilesController *additionalFilesController;

@property BOOL synchronizationNewDocumentsEnabled;
@property (copy) NSString* synchronizationNewDocumentsPath;
@property BOOL synchronizationNewDocumentsSynchronizePreamble;
@property BOOL synchronizationNewDocumentsSynchronizeEnvironment;
@property BOOL synchronizationNewDocumentsSynchronizeBody;
@property (readonly) NSDictionary *synchronizationAdditionalScripts;
@property (readonly, strong) SynchronizationAdditionalScriptsController *synchronizationAdditionalScriptsController;

@property NSInteger paletteLaTeXGroupSelectedTag;
@property NSRect paletteLaTeXWindowFrame;
@property BOOL paletteLaTeXDetailsOpened;

@property BOOL historyDisplayPreviewPanelState;

@property (copy) NSString* libraryPath;
@property BOOL libraryDisplayPreviewPanelState;
@property (readonly) library_row_t libraryViewRowType;

@end
