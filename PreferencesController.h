//
//  PreferencesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/03/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

extern NSString *const LaTeXiTAppKey;
extern NSString *const Old_LaTeXiTAppKey;

extern NSString *const LaTeXiTVersionKey;
extern NSString *const DocumentStyleKey;
extern NSString *const DragExportTypeKey;
extern NSString *const DragExportJpegColorKey;
extern NSString *const DragExportJpegQualityKey;
extern NSString *const DragExportPDFWOFGsWriteEngineKey;
extern NSString *const DragExportPDFWOFGsPDFCompatibilityLevelKey;
extern NSString *const DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey;

extern NSString *const DragExportSvgPdfToSvgPathKey;
extern NSString *const DragExportTextExportPreambleKey;
extern NSString *const DragExportTextExportEnvironmentKey;
extern NSString *const DragExportTextExportBodyKey;
extern NSString *const DragExportScaleAsPercentKey;
extern NSString *const DragExportIncludeBackgroundColorKey;
extern NSString *const DefaultImageViewBackgroundKey;
extern NSString *const DefaultAutomaticHighContrastedPreviewBackgroundKey;
extern NSString *const DefaultDoNotClipPreviewKey;
extern NSString *const DefaultColorKey;
extern NSString *const DefaultPointSizeKey;
extern NSString *const DefaultModeKey;
extern NSString *const SpellCheckingEnableKey;
extern NSString *const SyntaxColoringEnableKey;
extern NSString *const SyntaxColoringTextForegroundColorKey;
extern NSString *const SyntaxColoringTextBackgroundColorKey;
extern NSString *const SyntaxColoringCommandColorKey;
extern NSString *const SyntaxColoringMathsColorKey;
extern NSString *const SyntaxColoringKeywordColorKey;
extern NSString *const SyntaxColoringCommentColorKey;
extern NSString *const ReducedTextAreaStateKey;
extern NSString *const DefaultFontKey;
extern NSString *const PreamblesKey;
extern NSString *const LatexisationSelectedPreambleIndexKey;
extern NSString *const BodyTemplatesKey;
extern NSString *const LatexisationSelectedBodyTemplateIndexKey;
extern NSString *const ServiceSelectedPreambleIndexKey;
extern NSString *const ServiceSelectedBodyTemplateIndexKey;
extern NSString *const ServiceShortcutsKey;
extern NSString *const ServiceShortcutEnabledKey;
extern NSString *const ServiceShortcutClipBoardOptionKey;
extern NSString *const ServiceShortcutStringKey;
extern NSString *const ServiceShortcutIdentifierKey;
extern NSString *const ServiceRespectsColorKey;
extern NSString *const ServiceRespectsBaselineKey;
extern NSString *const ServiceRespectsPointSizeKey;
extern NSString *const ServicePointSizeFactorKey;
extern NSString *const ServiceUsesHistoryKey;
extern NSString *const ServiceRegularExpressionFiltersKey;
extern NSString *const ServiceRegularExpressionFilterEnabledKey;
extern NSString *const ServiceRegularExpressionFilterInputPatternKey;
extern NSString *const ServiceRegularExpressionFilterOutputPatternKey;
extern NSString *const AdditionalTopMarginKey;
extern NSString *const AdditionalLeftMarginKey;
extern NSString *const AdditionalRightMarginKey;
extern NSString *const AdditionalBottomMarginKey;
extern NSString *const EncapsulationsEnabledKey;
extern NSString *const EncapsulationsKey;
extern NSString *const CurrentEncapsulationIndexKey;
extern NSString *const TextShortcutsKey;
extern NSString *const CompositionConfigurationsKey;
extern NSString *const CompositionConfigurationDocumentIndexKey;
extern NSString *const LastEasterEggsDatesKey;

extern NSString *const EditionTabKeyInsertsSpacesEnabledKey;
extern NSString *const EditionTabKeyInsertsSpacesCountKey;

extern NSString *const CompositionConfigurationNameKey;
extern NSString *const CompositionConfigurationIsDefaultKey;
extern NSString *const CompositionConfigurationCompositionModeKey;
extern NSString *const CompositionConfigurationUseLoginShellKey;
extern NSString *const CompositionConfigurationPdfLatexPathKey;
extern NSString *const CompositionConfigurationPsToPdfPathKey;
extern NSString *const CompositionConfigurationXeLatexPathKey;
extern NSString *const CompositionConfigurationLuaLatexPathKey;
extern NSString *const CompositionConfigurationLatexPathKey;
extern NSString *const CompositionConfigurationDviPdfPathKey;
extern NSString *const CompositionConfigurationGsPathKey;
extern NSString *const CompositionConfigurationProgramArgumentsKey;
extern NSString *const CompositionConfigurationAdditionalProcessingScriptsKey;
extern NSString *const CompositionConfigurationAdditionalProcessingScriptEnabledKey;
extern NSString *const CompositionConfigurationAdditionalProcessingScriptTypeKey;
extern NSString *const CompositionConfigurationAdditionalProcessingScriptPathKey;
extern NSString *const CompositionConfigurationAdditionalProcessingScriptShellKey;
extern NSString *const CompositionConfigurationAdditionalProcessingScriptContentKey;

extern NSString *const HistoryDeleteOldEntriesEnabledKey;
extern NSString *const HistoryDeleteOldEntriesLimitKey;
extern NSString *const HistorySmartEnabledKey;

extern NSString *const CompositionConfigurationsControllerVisibleAtStartupKey;
extern NSString *const EncapsulationsControllerVisibleAtStartupKey;
extern NSString *const HistoryControllerVisibleAtStartupKey;
extern NSString *const LatexPalettesControllerVisibleAtStartupKey;
extern NSString *const LibraryControllerVisibleAtStartupKey;
extern NSString *const MarginControllerVisibleAtStartupKey;
extern NSString *const AdditionalFilesWindowControllerVisibleAtStartupKey;

extern NSString *const LibraryPathKey;
extern NSString *const LibraryViewRowTypeKey;
extern NSString *const LibraryDisplayPreviewPanelKey;
extern NSString *const HistoryDisplayPreviewPanelKey;

extern NSString *const CheckForNewVersionsKey;

extern NSString *const LatexPaletteGroupKey;
extern NSString *const LatexPaletteFrameKey;
extern NSString *const LatexPaletteDetailsStateKey;

extern NSString *const ShowWhiteColorWarningKey;

extern NSNotificationName const CompositionModeDidChangeNotification;
extern NSNotificationName const CurrentCompositionConfigurationDidChangeNotification;

extern NSString *const AdditionalFilesPathsKey;
extern NSString *const SynchronizationNewDocumentsEnabledKey;
extern NSString *const SynchronizationNewDocumentsSynchronizePreambleKey;
extern NSString *const SynchronizationNewDocumentsSynchronizeEnvironmentKey;
extern NSString *const SynchronizationNewDocumentsSynchronizeBodyKey;
extern NSString *const SynchronizationNewDocumentsPathKey;
extern NSString *const SynchronizationAdditionalScriptsKey;

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
@property BOOL exportIncludeBackgroundColor;

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
