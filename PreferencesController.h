//
//  PreferencesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/03/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
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

@class AdditionalFilesController;
@class BodyTemplatesController;
@class CompositionConfigurationsController;
@class EncapsulationsController;
@class PreamblesController;
@class ServiceRegularExpressionFiltersController;

@interface PreferencesController : NSObject {
  BOOL      isLaTeXiT;
  
  NSUndoManager* undoManager;

  NSArrayController*                         editionTextShortcutsController;
  PreamblesController*                       preamblesController;
  BodyTemplatesController*                   bodyTemplatesController;
  CompositionConfigurationsController*       compositionConfigurationsController;
  NSArrayController*                         serviceShortcutsController;
  ServiceRegularExpressionFiltersController* serviceRegularExpressionFiltersController;
  AdditionalFilesController*                 additionalFilesController;
  EncapsulationsController*                  encapsulationsController;
  
  export_format_t exportFormatCurrentSession;
}

+(PreferencesController*) sharedController;

-(NSUndoManager*) undoManager;

-(NSString*)    latexitVersion;

-(export_format_t) exportFormatPersistent;
-(void)            setExportFormatPersistent:(export_format_t)value;
-(export_format_t) exportFormatCurrentSession;
-(void)            setExportFormatCurrentSession:(export_format_t)value;


-(NSData*)         exportJpegBackgroundColorData;
-(void)            setExportJpegBackgroundColorData:(NSData*)value;
-(NSColor*)        exportJpegBackgroundColor;
-(void)            setExportJpegBackgroundColor:(NSColor*)value;
-(CGFloat)         exportJpegQualityPercent;
-(void)            setExportJpegQualityPercent:(CGFloat)value;
-(NSString*)       exportSvgPdfToSvgPath;
-(void)            setExportSvgPdfToSvgPath:(NSString*)value;
-(BOOL)            exportTextExportPreamble;
-(void)            setExportTextExportPreamble:(BOOL)value;
-(BOOL)            exportTextExportEnvironment;
-(void)            setExportTextExportEnvironment:(BOOL)value;
-(BOOL)            exportTextExportBody;
-(void)            setExportTextExportBody:(BOOL)value;
-(CGFloat)         exportScalePercent;
-(void)            setExportScalePercent:(CGFloat)value;

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

-(NSArray*)           editionTextShortcuts;
-(NSArrayController*) editionTextShortcutsController;

-(NSArray*)             preambles;
-(int)                  preambleDocumentIndex;
-(int)                  preambleServiceIndex;
-(NSAttributedString*)  preambleDocumentAttributedString;
-(NSAttributedString*)  preambleServiceAttributedString;
-(PreamblesController*) preamblesController;

-(NSArray*)                 bodyTemplates;
-(NSArray*)                 bodyTemplatesWithNone;
-(int)                      bodyTemplateDocumentIndex;
-(int)                      bodyTemplateServiceIndex;
-(NSDictionary*)            bodyTemplateDocumentDictionary;
-(NSDictionary*)            bodyTemplateServiceDictionary;
-(BodyTemplatesController*) bodyTemplatesController;

-(CompositionConfigurationsController*) compositionConfigurationsController;
-(NSArray*)           compositionConfigurations;
-(void)               setCompositionConfigurations:(NSArray*)value;

-(int)                compositionConfigurationsDocumentIndex;
-(void)               setCompositionConfigurationsDocumentIndex:(int)value;
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
-(int)                       encapsulationsSelectedIndex;
-(NSString*)                 encapsulationSelected;
-(EncapsulationsController*) encapsulationsController;

-(NSArray*)                   additionalFilesPaths;
-(void)                       setAdditionalFilesPaths:(NSArray*)value;
-(AdditionalFilesController*) additionalFilesController;

-(int)    paletteLaTeXGroupSelectedTag;
-(void)   setPaletteLaTeXGroupSelectedTag:(int)value;
-(NSRect) paletteLaTeXWindowFrame;
-(void)   setPaletteLaTeXWindowFrame:(NSRect)value;
-(BOOL)   paletteLaTeXDetailsOpened;
-(void)   setPaletteLaTeXDetailsOpened:(BOOL)value;

-(BOOL) historyDisplayPreviewPanelState;
-(void) setHistoryDisplayPreviewPanelState:(BOOL)value;

-(NSString*) libraryPath;
-(void)      setLibraryPath:(NSString*)libraryPath;
-(BOOL) libraryDisplayPreviewPanelState;
-(void) setLibraryDisplayPreviewPanelState:(BOOL)value;
-(library_row_t) libraryViewRowType;

@end
