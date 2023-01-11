//
//  PreferencesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/03/09.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

extern NSString* const LaTeXiTAppKey;
extern NSString* const Old_LaTeXiTAppKey;
extern NSString* const LaTeXiTVersionKey;

extern NSString* const DocumentStyleKey;
extern NSString* const DragExportTypeKey;
extern NSString* const DragExportJpegColorKey;
extern NSString* const DragExportJpegQualityKey;
extern NSString* const DragExportPDFWOFGsWriteEngineKey;
extern NSString* const DragExportPDFWOFGsPDFCompatibilityLevelKey;
extern NSString* const DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey;
extern NSString* const DragExportPDFMetadataInvisibleGraphicsEnabledKey;

extern NSString* const DragExportSvgPdfToSvgPathKey;
extern NSString* const DragExportSvgPdfToCairoPathKey;
extern NSString* const DragExportTextExportPreambleKey;
extern NSString* const DragExportTextExportEnvironmentKey;
extern NSString* const DragExportTextExportBodyKey;
extern NSString* const DragExportScaleAsPercentKey;
extern NSString* const DragExportIncludeBackgroundColorKey;
extern NSString* const DragExportAddTempFileEnabledKey;

extern NSString* const DefaultImageViewBackgroundKey;
extern NSString* const DefaultAutomaticHighContrastedPreviewBackgroundKey;
extern NSString* const DefaultDoNotClipPreviewKey;
extern NSString* const DefaultColorKey;
extern NSString* const DefaultPointSizeKey;
extern NSString* const DefaultModeKey;
extern NSString* const SpellCheckingEnableKey;
extern NSString* const SyntaxColoringEnableKey;
extern NSString* const SyntaxColoringTextForegroundColorKey;
extern NSString* const SyntaxColoringTextBackgroundColorKey;
extern NSString* const SyntaxColoringTextForegroundColorDarkModeKey;
extern NSString* const SyntaxColoringTextBackgroundColorDarkModeKey;
extern NSString* const SyntaxColoringCommandColorKey;
extern NSString* const SyntaxColoringCommandColorDarkModeKey;
extern NSString* const SyntaxColoringMathsColorKey;
extern NSString* const SyntaxColoringMathsColorDarkModeKey;
extern NSString* const SyntaxColoringKeywordColorKey;
extern NSString* const SyntaxColoringKeywordColorDarkModeKey;
extern NSString* const SyntaxColoringCommentColorKey;
extern NSString* const SyntaxColoringCommentColorDarkModeKey;
extern NSString* const ReducedTextAreaStateKey;
extern NSString* const DefaultFontKey;
extern NSString* const PreamblesKey;
extern NSString* const LatexisationSelectedPreambleIndexKey;
extern NSString* const BodyTemplatesKey;
extern NSString* const LatexisationSelectedBodyTemplateIndexKey;
extern NSString* const ServiceSelectedPreambleIndexKey;
extern NSString* const ServiceSelectedBodyTemplateIndexKey;
extern NSString* const ServiceShortcutsKey;
extern NSString* const ServiceShortcutEnabledKey;
extern NSString* const ServiceShortcutClipBoardOptionKey;
extern NSString* const ServiceShortcutStringKey;
extern NSString* const ServiceShortcutIdentifierKey;
extern NSString* const ServiceRespectsColorKey;
extern NSString* const ServiceRespectsBaselineKey;
extern NSString* const ServiceRespectsPointSizeKey;
extern NSString* const ServicePointSizeFactorKey;
extern NSString* const ServiceUsesHistoryKey;
extern NSString* const ServiceRegularExpressionFiltersKey;
extern NSString* const ServiceRegularExpressionFilterEnabledKey;
extern NSString* const ServiceRegularExpressionFilterInputPatternKey;
extern NSString* const ServiceRegularExpressionFilterOutputPatternKey;
extern NSString* const AdditionalTopMarginKey;
extern NSString* const AdditionalLeftMarginKey;
extern NSString* const AdditionalRightMarginKey;
extern NSString* const AdditionalBottomMarginKey;
extern NSString* const EncapsulationsEnabledKey;
extern NSString* const EncapsulationsKey;
extern NSString* const CurrentEncapsulationIndexKey;
extern NSString* const TextShortcutsKey;
extern NSString* const CompositionConfigurationsKey;
extern NSString* const CompositionConfigurationDocumentIndexKey;
extern NSString* const LastEasterEggsDatesKey;

extern NSString* const EditionTabKeyInsertsSpacesEnabledKey;
extern NSString* const EditionTabKeyInsertsSpacesCountKey;
extern NSString* const EditionAutoCompleteOnBackslashEnabledKey;

extern NSString* const CompositionConfigurationNameKey;
extern NSString* const CompositionConfigurationIsDefaultKey;
extern NSString* const CompositionConfigurationCompositionModeKey;
extern NSString* const CompositionConfigurationUseLoginShellKey;
extern NSString* const CompositionConfigurationPdfLatexPathKey;
extern NSString* const CompositionConfigurationPsToPdfPathKey;
extern NSString* const CompositionConfigurationXeLatexPathKey;
extern NSString* const CompositionConfigurationLuaLatexPathKey;
extern NSString* const CompositionConfigurationLatexPathKey;
extern NSString* const CompositionConfigurationDviPdfPathKey;
extern NSString* const CompositionConfigurationGsPathKey;
extern NSString* const CompositionConfigurationProgramArgumentsKey;
extern NSString* const CompositionConfigurationAdditionalProcessingScriptsKey;
extern NSString* const CompositionConfigurationAdditionalProcessingScriptEnabledKey;
extern NSString* const CompositionConfigurationAdditionalProcessingScriptTypeKey;
extern NSString* const CompositionConfigurationAdditionalProcessingScriptPathKey;
extern NSString* const CompositionConfigurationAdditionalProcessingScriptShellKey;
extern NSString* const CompositionConfigurationAdditionalProcessingScriptContentKey;

extern NSString* const HistoryDeleteOldEntriesEnabledKey;
extern NSString* const HistoryDeleteOldEntriesLimitKey;
extern NSString* const HistorySmartEnabledKey;

extern NSString* const CompositionConfigurationsControllerVisibleAtStartupKey;
extern NSString* const EncapsulationsControllerVisibleAtStartupKey;
extern NSString* const HistoryControllerVisibleAtStartupKey;
extern NSString* const LatexPalettesControllerVisibleAtStartupKey;
extern NSString* const LibraryControllerVisibleAtStartupKey;
extern NSString* const MarginControllerVisibleAtStartupKey;
extern NSString* const AdditionalFilesWindowControllerVisibleAtStartupKey;

extern NSString* const LibraryPathKey;
extern NSString* const LibraryViewRowTypeKey;
extern NSString* const LibraryDisplayPreviewPanelKey;
extern NSString* const HistoryDisplayPreviewPanelKey;

extern NSString* const CheckForNewVersionsKey;

extern NSString* const LatexPaletteGroupKey;
extern NSString* const LatexPaletteFrameKey;
extern NSString* const LatexPaletteDetailsStateKey;

extern NSString* const ShowWhiteColorWarningKey;

extern NSString* const CompositionModeDidChangeNotification;
extern NSString* const CurrentCompositionConfigurationDidChangeNotification;

extern NSString* const AdditionalFilesPathsKey;
extern NSString* const SynchronizationNewDocumentsEnabledKey;
extern NSString* const SynchronizationNewDocumentsSynchronizePreambleKey;
extern NSString* const SynchronizationNewDocumentsSynchronizeEnvironmentKey;
extern NSString* const SynchronizationNewDocumentsSynchronizeBodyKey;
extern NSString* const SynchronizationNewDocumentsPathKey;
extern NSString* const SynchronizationAdditionalScriptsKey;

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
  BOOL exportAddTempFileCurrentSession;
}

+(PreferencesController*) sharedController;

-(NSUndoManager*) undoManager;

-(NSString*)    latexitVersion;

-(export_format_t) exportFormatPersistent;
-(void)            setExportFormatPersistent:(export_format_t)value;
-(export_format_t) exportFormatCurrentSession;
-(void)            setExportFormatCurrentSession:(export_format_t)value;
-(BOOL)            exportAddTempFilePersistent;
-(void)            setExportAddTempFilePersistent:(BOOL)value;
-(BOOL)            exportAddTempFileCurrentSession;
-(void)            setExportAddTempFileCurrentSession:(BOOL)value;


-(NSData*)         exportJpegBackgroundColorData;
-(void)            setExportJpegBackgroundColorData:(NSData*)value;
-(NSColor*)        exportJpegBackgroundColor;
-(void)            setExportJpegBackgroundColor:(NSColor*)value;
-(CGFloat)         exportJpegQualityPercent;
-(void)            setExportJpegQualityPercent:(CGFloat)value;
-(NSString*)       exportSvgPdfToSvgPath;
-(void)            setExportSvgPdfToSvgPath:(NSString*)value;
-(NSString*)       exportSvgPdfToCairoPath;
-(void)            setExportSvgPdfToCairoPath:(NSString*)value;
-(BOOL)            exportTextExportPreamble;
-(void)            setExportTextExportPreamble:(BOOL)value;
-(BOOL)            exportTextExportEnvironment;
-(void)            setExportTextExportEnvironment:(BOOL)value;
-(BOOL)            exportTextExportBody;
-(void)            setExportTextExportBody:(BOOL)value;
-(CGFloat)         exportScalePercent;
-(void)            setExportScalePercent:(CGFloat)value;
-(BOOL)            exportIncludeBackgroundColor;
-(void)            setExportIncludeBackgroundColor:(BOOL)value;

-(NSString*) exportPDFWOFGsWriteEngine;
-(void) setExportPDFWOFGsWriteEngine:(NSString*)value;
-(NSString*) exportPDFWOFGsPDFCompatibilityLevel;
-(void) setExportPDFWOFGsPDFCompatibilityLevel:(NSString*)value;
-(BOOL) exportPDFWOFMetaDataInvisibleGraphicsEnabled;
-(void) setExportPDFWOFMetaDataInvisibleGraphicsEnabled:(BOOL)value;

-(BOOL) exportPDFMetaDataInvisibleGraphicsEnabled;
-(void) setExportPDFMetaDataInvisibleGraphicsEnabled:(BOOL)value;

-(BOOL) doNotClipPreview;
-(void) setDoNotClipPreview:(BOOL)value;

-(latex_mode_t) latexisationLaTeXMode;
-(void)         setLatexisationLaTeXMode:(latex_mode_t)mode;
-(CGFloat)      latexisationFontSize;
-(NSData*)      latexisationFontColorData;
-(NSColor*)     latexisationFontColor;

-(CGFloat) marginsAdditionalLeft;
-(void)    setMarginsAdditionalLeft:(CGFloat)value;
-(CGFloat) marginsAdditionalRight;
-(void)    setMarginsAdditionalRight:(CGFloat)value;
-(CGFloat) marginsAdditionalTop;
-(void)    setMarginsAdditionalTop:(CGFloat)value;
-(CGFloat) marginsAdditionalBottom;
-(void)    setMarginsAdditionalBottom:(CGFloat)value;

-(document_style_t) documentStyle;
-(void)             setDocumentStyle:(document_style_t)documentStyle;
-(BOOL)             documentIsReducedTextArea;
-(NSData*)          documentImageViewBackgroundColorData;
-(NSColor*)         documentImageViewBackgroundColor;
-(BOOL)             documentUseAutomaticHighContrastedPreviewBackground;

-(NSData*)    editionFontData;
-(void)       setEditionFontData:(NSData*)value;
-(NSFont*)    editionFont;
-(void)       setEditionFont:(NSFont*)value;
-(BOOL)       editionSyntaxColoringEnabled;
-(NSData*)    editionSyntaxColoringTextForegroundColorData;
-(NSColor*)   editionSyntaxColoringTextForegroundColor;
-(NSData*)    editionSyntaxColoringTextBackgroundColorData;
-(NSColor*)   editionSyntaxColoringTextBackgroundColor;
-(NSData*)    editionSyntaxColoringCommandColorData;
-(NSColor*)   editionSyntaxColoringCommandColor;
-(NSData*)    editionSyntaxColoringCommentColorData;
-(NSColor*)   editionSyntaxColoringCommentColor;
-(NSData*)    editionSyntaxColoringKeywordColorData;
-(NSColor*)   editionSyntaxColoringKeywordColor;
-(NSData*)    editionSyntaxColoringMathsColorData;
-(NSColor*)   editionSyntaxColoringMathsColor;
-(BOOL)       editionTabKeyInsertsSpacesEnabled;
-(NSUInteger) editionTabKeyInsertsSpacesCount;
-(BOOL)       editionAutoCompleteOnBackslashEnabled;
-(void)       setEditionAutoCompleteOnBackslashEnabled:(BOOL)value;

-(NSArray*)           editionTextShortcuts;
-(NSArrayController*) editionTextShortcutsController;

-(NSArray*)             preambles;
-(NSInteger)            preambleDocumentIndex;
-(NSInteger)            preambleServiceIndex;
-(NSAttributedString*)  preambleDocumentAttributedString;
-(NSAttributedString*)  preambleServiceAttributedString;
-(PreamblesController*) preamblesController;

-(NSArray*)                 bodyTemplates;
-(NSArray*)                 bodyTemplatesWithNone;
-(NSInteger)                bodyTemplateDocumentIndex;
-(NSInteger)                bodyTemplateServiceIndex;
-(NSDictionary*)            bodyTemplateDocumentDictionary;
-(NSDictionary*)            bodyTemplateServiceDictionary;
-(BodyTemplatesController*) bodyTemplatesController;

-(CompositionConfigurationsController*) compositionConfigurationsController;
-(NSArray*)           compositionConfigurations;
-(void)               setCompositionConfigurations:(NSArray*)value;

-(NSInteger)          compositionConfigurationsDocumentIndex;
-(void)               setCompositionConfigurationsDocumentIndex:(NSInteger)value;
-(NSDictionary*)      compositionConfigurationDocument;
-(void)               setCompositionConfigurationDocument:(NSDictionary*)value;

-(void)               setCompositionConfigurationDocumentProgramPath:(NSString*)value forKey:(NSString*)key;

-(BOOL)      historySaveServicesResultsEnabled;
-(BOOL)      historyDeleteOldEntriesEnabled;
-(NSNumber*) historyDeleteOldEntriesLimit;
-(BOOL)      historySmartEnabled;

-(NSString*)          serviceDescriptionForIdentifier:(service_identifier_t)identifier;
-(NSArray*)           serviceShortcuts;
-(void)               setServiceShortcuts:(NSArray*)value;
-(NSArrayController*) serviceShortcutsController;
-(BOOL) changeServiceShortcutsWithDiscrepancyFallback:(change_service_shortcuts_fallback_t)discrepancyFallback
                               authenticationFallback:(change_service_shortcuts_fallback_t)authenticationFallback;
-(NSArray*)           serviceRegularExpressionFilters;
-(void)               setServiceRegularExpressionFilters:(NSArray*)value;
-(ServiceRegularExpressionFiltersController*) serviceRegularExpressionFiltersController;

-(BOOL)                      encapsulationsEnabled;
-(NSArray*)                  encapsulations;
-(NSInteger)                 encapsulationsSelectedIndex;
-(NSString*)                 encapsulationSelected;
-(EncapsulationsController*) encapsulationsController;

-(NSArray<NSString*>*)        additionalFilesPaths;
-(void)                       setAdditionalFilesPaths:(NSArray<NSString*>*)value;
-(AdditionalFilesController*) additionalFilesController;

-(BOOL)                                        synchronizationNewDocumentsEnabled;
-(void)                                        setSynchronizationNewDocumentsEnabled:(BOOL)value;
-(NSString*)                                   synchronizationNewDocumentsPath;
-(void)                                        setSynchronizationNewDocumentsPath:(NSString*)value;
-(BOOL)                                        synchronizationNewDocumentsSynchronizePreamble;
-(void)                                        setSynchronizationNewDocumentsSynchronizePreamble:(BOOL)value;
-(BOOL)                                        synchronizationNewDocumentsSynchronizeEnvironment;
-(void)                                        setSynchronizationNewDocumentsSynchronizeEnvironment:(BOOL)value;
-(BOOL)                                        synchronizationNewDocumentsSynchronizeBody;
-(void)                                        setSynchronizationNewDocumentsSynchronizeBody:(BOOL)value;
-(NSDictionary*)                               synchronizationAdditionalScripts;
-(SynchronizationAdditionalScriptsController*) synchronizationAdditionalScriptsController;

-(NSInteger) paletteLaTeXGroupSelectedTag;
-(void)      setPaletteLaTeXGroupSelectedTag:(NSInteger)value;
-(NSRect)    paletteLaTeXWindowFrame;
-(void)      setPaletteLaTeXWindowFrame:(NSRect)value;
-(BOOL)      paletteLaTeXDetailsOpened;
-(void)      setPaletteLaTeXDetailsOpened:(BOOL)value;

-(BOOL) historyDisplayPreviewPanelState;
-(void) setHistoryDisplayPreviewPanelState:(BOOL)value;

-(NSString*) libraryPath;
-(void)      setLibraryPath:(NSString*)libraryPath;
-(BOOL) libraryDisplayPreviewPanelState;
-(void) setLibraryDisplayPreviewPanelState:(BOOL)value;
-(library_row_t) libraryViewRowType;

@end
