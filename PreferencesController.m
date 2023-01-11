//
//  PreferencesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/03/09.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import "PreferencesController.h"

#import "AdditionalFilesController.h"
#import "BodyTemplatesController.h"
#import "ComposedTransformer.h"
#import "IndexToIndexesTransformer.h"
#import "CompositionConfigurationsController.h"
#import "DictionaryToArrayTransformer.h"
#import "EncapsulationsController.h"
#import "MutableTransformer.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSDictionaryCompositionConfiguration.h"
#import "NSDictionaryCompositionConfigurationAdditionalProcessingScript.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSFontExtended.h"
#import "NSObjectExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreamblesController.h"
#import "PreferencesControllerMigration.h"
#import "ServiceRegularExpressionFiltersController.h"
#import "SynchronizationAdditionalScriptsController.h"
#import "Utils.h"

#import <Security/Security.h>

static PreferencesController* sharedInstance = nil;

NSString* const LaTeXiTAppKey = @"fr.chachatelier.pierre.LaTeXiT";
NSString* const Old_LaTeXiTAppKey = @"fr.club.ktd.LaTeXiT";

NSString* const LaTeXiTVersionKey = @"version";

NSString* const DocumentStyleKey = @"DocumentStyle";

NSString* const DragExportTypeKey                                   = @"DragExportType";
NSString* const DragExportJpegColorKey                              = @"DragExportJpegColor";
NSString* const DragExportJpegQualityKey                            = @"DragExportJpegQuality";
NSString* const DragExportPDFMetadataInvisibleGraphicsEnabledKey    = @"DragExportPDFMetadataInvisibleGraphicsEnabled";
NSString* const DragExportPDFWOFGsWriteEngineKey                    = @"DragExportPDFWOFGsWriteEngine";
NSString* const DragExportPDFWOFGsPDFCompatibilityLevelKey          = @"DragExportPDFWOFGsPDFCompatibilityLevel";
NSString* const DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey = @"DragExportPDFWOFMetadataInvisibleGraphicsEnabled";
NSString* const DragExportSvgPdfToSvgPathKey                        = @"DragExportSvgPdfToSvgPath";
NSString* const DragExportSvgPdfToCairoPathKey                      = @"DragExportSvgPdfToCairoPath";
NSString* const DragExportTextExportPreambleKey                     = @"DragExportTextExportPreambleKey";
NSString* const DragExportTextExportEnvironmentKey                  = @"DragExportTextExportEnvironmentKey";
NSString* const DragExportTextExportBodyKey                         = @"DragExportTextExportBodyKey";
NSString* const DragExportScaleAsPercentKey                         = @"DragExportScaleAsPercent";
NSString* const DragExportIncludeBackgroundColorKey                 = @"DragExportIncludeBackgroundColor";
NSString* const DragExportAddTempFileEnabledKey                     = @"DragExportAddTempFileEnabled";

NSString* const DefaultImageViewBackgroundKey                      = @"DefaultImageViewBackground";
NSString* const DefaultAutomaticHighContrastedPreviewBackgroundKey = @"DefaultAutomaticHighContrastedPreviewBackground";
NSString* const DefaultDoNotClipPreviewKey                         = @"DefaultDoNotClipPreview";
NSString* const DefaultColorKey                                    = @"DefaultColor";
NSString* const DefaultPointSizeKey                                = @"DefaultPointSize";
NSString* const DefaultModeKey                                     = @"DefaultMode";

NSString* const SpellCheckingEnableKey                       = @"SpellCheckingEnabled";
NSString* const SyntaxColoringEnableKey                      = @"SyntaxColoringEnabled";
NSString* const SyntaxColoringTextForegroundColorKey         = @"SyntaxColoringTextForegroundColor";
NSString* const SyntaxColoringTextForegroundColorDarkModeKey = @"SyntaxColoringTextForegroundColorDarkMode";
NSString* const SyntaxColoringTextBackgroundColorKey         = @"SyntaxColoringTextBackgroundColor";
NSString* const SyntaxColoringTextBackgroundColorDarkModeKey = @"SyntaxColoringTextBackgroundColorDarkMode";
NSString* const SyntaxColoringCommandColorKey                = @"SyntaxColoringCommandColor";
NSString* const SyntaxColoringCommandColorDarkModeKey        = @"SyntaxColoringCommandColorDarkMode";
NSString* const SyntaxColoringMathsColorKey                  = @"SyntaxColoringMathsColor";
NSString* const SyntaxColoringMathsColorDarkModeKey          = @"SyntaxColoringMathsColorDarkMode";
NSString* const SyntaxColoringKeywordColorKey                = @"SyntaxColoringKeywordColor";
NSString* const SyntaxColoringKeywordColorDarkModeKey        = @"SyntaxColoringKeywordColorDarkMode";
NSString* const SyntaxColoringCommentColorKey                = @"SyntaxColoringCommentColor";
NSString* const SyntaxColoringCommentColorDarkModeKey        = @"SyntaxColoringCommentColorDarkMode";
NSString* const ReducedTextAreaStateKey                      = @"ReducedTextAreaState";

NSString* const DefaultFontKey               = @"DefaultFont";
NSString* const PreamblesKey                         = @"Preambles";
NSString* const LatexisationSelectedPreambleIndexKey = @"LatexisationSelectedPreambleIndex";
NSString* const BodyTemplatesKey                         = @"BodyTemplates";
NSString* const LatexisationSelectedBodyTemplateIndexKey = @"LatexisationSelectedBodyTemplateIndexKey";

NSString* const ServiceSelectedPreambleIndexKey     = @"ServiceSelectedPreambleIndex";
NSString* const ServiceSelectedBodyTemplateIndexKey = @"ServiceSelectedBodyTemplateIndexKey";
NSString* const ServiceShortcutsKey                 = @"ServiceShortcuts";
NSString* const ServiceShortcutEnabledKey           = @"enabled";
NSString* const ServiceShortcutClipBoardOptionKey   = @"clipBoardOption";
NSString* const ServiceShortcutStringKey            = @"string";
NSString* const ServiceShortcutIdentifierKey        = @"identifier";

NSString* const ServiceRespectsBaselineKey      = @"ServiceRespectsBaseline";
NSString* const ServiceRespectsPointSizeKey     = @"ServiceRespectsPointSize";
NSString* const ServicePointSizeFactorKey       = @"ServicePointSizeFactor";
NSString* const ServiceRespectsColorKey         = @"ServiceRespectsColor";
NSString* const ServiceUsesHistoryKey           = @"ServiceUsesHistory";
NSString* const ServiceRegularExpressionFiltersKey         = @"ServiceRegularExpressionFilters";
NSString* const ServiceRegularExpressionFilterEnabledKey   = @"ServiceRegularExpressionFilterEnabled";
NSString* const ServiceRegularExpressionFilterInputPatternKey     = @"ServiceRegularExpressionFilterInputPattern";
NSString* const ServiceRegularExpressionFilterOutputPatternKey    = @"ServiceRegularExpressionFilterOutputPattern";

NSString* const AdditionalTopMarginKey          = @"AdditionalTopMargin";
NSString* const AdditionalLeftMarginKey         = @"AdditionalLeftMargin";
NSString* const AdditionalRightMarginKey        = @"AdditionalRightMargin";
NSString* const AdditionalBottomMarginKey       = @"AdditionalBottomMargin";
NSString* const EncapsulationsEnabledKey        = @"EncapsulationsEnabled";
NSString* const EncapsulationsKey               = @"Encapsulations";
NSString* const CurrentEncapsulationIndexKey    = @"CurrentEncapsulationIndex";
NSString* const TextShortcutsKey                = @"TextShortcuts";

NSString* const EditionTabKeyInsertsSpacesEnabledKey = @"EditionTabKeyInsertsSpacesEnabled";
NSString* const EditionTabKeyInsertsSpacesCountKey   = @"EditionTabKeyInsertsSpacesCount";
NSString* const EditionAutoCompleteOnBackslashEnabledKey = @"EditionAutoCompleteOnBackslashEnabled";

NSString* const CompositionConfigurationsKey             = @"CompositionConfigurations";
NSString* const CompositionConfigurationDocumentIndexKey = @"CompositionConfigurationDocumentIndexKey";

NSString* const HistoryDeleteOldEntriesEnabledKey = @"HistoryDeleteOldEntriesEnabled";
NSString* const HistoryDeleteOldEntriesLimitKey   = @"HistoryDeleteOldEntriesLimit";
NSString* const HistorySmartEnabledKey            = @"HistorySmartEnabled";

NSString* const LastEasterEggsDatesKey       = @"LastEasterEggsDates";

NSString* const CompositionConfigurationsControllerVisibleAtStartupKey = @"CompositionConfigurationsControllerVisibleAtStartup";
NSString* const EncapsulationsControllerVisibleAtStartupKey = @"EncapsulationsControllerVisibleAtStartup";
NSString* const HistoryControllerVisibleAtStartupKey       = @"HistoryControllerVisibleAtStartup";
NSString* const LatexPalettesControllerVisibleAtStartupKey = @"LatexPalettesControllerVisibleAtStartup";
NSString* const LibraryControllerVisibleAtStartupKey       = @"LibraryControllerVisibleAtStartup";
NSString* const MarginControllerVisibleAtStartupKey        = @"MarginControllerVisibleAtStartup";
NSString* const AdditionalFilesWindowControllerVisibleAtStartupKey = @"AdditionalFilesWindowControllerVisibleAtStartup";

NSString* const LibraryPathKey                = @"LibraryPath";
NSString* const LibraryViewRowTypeKey         = @"LibraryViewRowType";
NSString* const LibraryDisplayPreviewPanelKey = @"LibraryDisplayPreviewPanel";
NSString* const HistoryDisplayPreviewPanelKey = @"HistoryDisplayPreviewPanel";

NSString* const LatexPaletteGroupKey        = @"LatexPaletteGroup";
NSString* const LatexPaletteFrameKey        = @"LatexPaletteFrame";
NSString* const LatexPaletteDetailsStateKey = @"LatexPaletteDetailsState";

NSString* const ShowWhiteColorWarningKey       = @"ShowWhiteColorWarning";

NSString* const CompositionModeDidChangeNotification = @"CompositionModeDidChangeNotification";
NSString* const CurrentCompositionConfigurationDidChangeNotification = @"CurrentCompositionConfigurationDidChangeNotification";

NSString* const CompositionConfigurationNameKey                        = @"name";
NSString* const CompositionConfigurationIsDefaultKey                   = @"isDefault";
NSString* const CompositionConfigurationCompositionModeKey             = @"compositionMode";
NSString* const CompositionConfigurationUseLoginShellKey               = @"useLoginShell";
NSString* const CompositionConfigurationPdfLatexPathKey                = @"pdfLatexPath";
NSString* const CompositionConfigurationPsToPdfPathKey                 = @"psToPdfPath";
NSString* const CompositionConfigurationXeLatexPathKey                 = @"xeLatexPath";
NSString* const CompositionConfigurationLuaLatexPathKey                = @"luaLatexPath";
NSString* const CompositionConfigurationLatexPathKey                   = @"latexPath";
NSString* const CompositionConfigurationDviPdfPathKey                  = @"dviPdfPath";
NSString* const CompositionConfigurationGsPathKey                      = @"gsPath";
NSString* const CompositionConfigurationProgramArgumentsKey            = @"programArguments";
NSString* const CompositionConfigurationAdditionalProcessingScriptsKey = @"additionalProcessingScripts";
NSString* const CompositionConfigurationAdditionalProcessingScriptEnabledKey = @"enabled";
NSString* const CompositionConfigurationAdditionalProcessingScriptTypeKey    = @"sourceType";
NSString* const CompositionConfigurationAdditionalProcessingScriptPathKey    = @"file";
NSString* const CompositionConfigurationAdditionalProcessingScriptShellKey   = @"shell";
NSString* const CompositionConfigurationAdditionalProcessingScriptContentKey = @"body";

NSString* const AdditionalFilesPathsKey = @"AdditionalFilesPaths";

NSString* const SynchronizationNewDocumentsEnabledKey = @"SynchronizationNewDocumentsEnabled";
NSString* const SynchronizationNewDocumentsSynchronizePreambleKey = @"SynchronizationNewDocumentsSynchronizePreamble";
NSString* const SynchronizationNewDocumentsSynchronizeEnvironmentKey = @"SynchronizationNewDocumentsSynchronizeEnvironment";
NSString* const SynchronizationNewDocumentsSynchronizeBodyKey = @"SynchronizationNewDocumentsSynchronizeBody";
NSString* const SynchronizationNewDocumentsPathKey = @"SynchronizationNewDocumentsPath";
NSString* const SynchronizationAdditionalScriptsKey = @"SynchronizationAdditionalScripts";

@interface PreferencesController (/*PrivateAPI*/)
-(NSArrayController*) lazyEditionTextShortcutsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSArray*) editionTextShortcutsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
-(PreamblesController*) lazyPreamblesControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSArray*) preamblesFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
-(BodyTemplatesController*) lazyBodyTemplatesControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSArray*) bodyTemplatesFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
-(CompositionConfigurationsController*) lazyCompositionConfigurationsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSArray*) compositionConfigurationsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
-(NSArrayController*) lazyServiceShortcutsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSArray*) serviceShortcutsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
-(ServiceRegularExpressionFiltersController*) lazyServiceRegularExpressionFiltersControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSArray*) serviceRegularExpressionFiltersFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
-(AdditionalFilesController*) lazyAdditionalFilesControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSArray*) additionalFilesPathsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
-(SynchronizationAdditionalScriptsController*) lazySynchronizationAdditionalScriptsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSDictionary*) synchronizationAdditionalScriptsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
+(NSMutableDictionary*) defaultSynchronizationAdditionalScripts;
-(EncapsulationsController*) lazyEncapsulationsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded;
-(NSArray*) encapsulationsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded;
-(void) appearanceDidChange:(NSNotification*)notification;
@end

@implementation PreferencesController

static NSMutableArray* factoryDefaultsPreambles = nil;
static NSMutableArray* factoryDefaultsBodyTemplates = nil;

+(PreferencesController*) sharedController
{
  if (!sharedInstance)
  {
    @synchronized(self)
    {
      if (!sharedInstance)
        sharedInstance = [[PreferencesController alloc] init];
    }//end @synchronized(self)
  }//end if (!sharedInstance)
  return sharedInstance;
}
//end sharedController

+(BOOL) isLaTeXiT
{
  BOOL result = NO;
  CFStringRef identifier = CFBundleGetIdentifier(CFBundleGetMainBundle());
  #ifdef ARC_ENABLED
  result = [(CHBRIDGE NSString*)identifier isEqualToString:LaTeXiTAppKey];
  #else
  result = [(NSString*)identifier isEqualToString:LaTeXiTAppKey];
  #endif
  return result;
}
//end isLaTeXiT

+(void) initialize
{
  @synchronized(self)
  {
    static BOOL initialized = NO;
    if (!initialized)
    {
      initialized = YES;
      if (!factoryDefaultsPreambles)
        factoryDefaultsPreambles = [[NSMutableArray alloc] initWithObjects:[PreamblesController defaultLocalizedPreambleDictionaryEncoded], nil];
      if (!factoryDefaultsBodyTemplates)
        factoryDefaultsBodyTemplates = [[NSMutableArray alloc] initWithObjects:[BodyTemplatesController defaultLocalizedBodyTemplateDictionaryEncoded], nil];

      NSMutableArray* defaultTextShortcuts = [NSMutableArray array];
      {
        NSString*  textShortcutsPlistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"textShortcuts" ofType:@"plist"];
        NSData*    dataTextShortcutsPlist = [NSData dataWithContentsOfFile:textShortcutsPlistPath options:NSUncachedRead error:nil];
        NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
        NSError* error = nil;
        NSDictionary* plist = [NSPropertyListSerialization propertyListWithData:dataTextShortcutsPlist
                                                                        options:NSPropertyListImmutable format:&format error:&error];
        NSString* version = [plist objectForKey:@"version"];
        //we can check the version...
        if (!version || [version compare:@"1.13.0" options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending)
        {
        }
        NSEnumerator* enumerator = [[plist objectForKey:@"shortcuts"] objectEnumerator];
        NSDictionary* dict = nil;
        while((dict = [enumerator nextObject]))
          [defaultTextShortcuts addObject:[NSMutableDictionary dictionaryWithDictionary:dict]];
      }
      
      NSString* desktopPath = [[NSWorkspace sharedWorkspace]
                                 getBestStandardPast:NSDesktopDirectory
                                 domain:NSUserDomainMask
                                 defaultValue:[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"]];

      NSString* currentVersion = ![[self class] isLaTeXiT] ? nil : [[NSWorkspace sharedWorkspace] applicationVersion];
      NSDictionary* defaults =
        [NSDictionary dictionaryWithObjectsAndKeys:
          !currentVersion ? @"" : currentVersion, LaTeXiTVersionKey,
             @(DOCUMENT_STYLE_NORMAL), DocumentStyleKey,
             @(EXPORT_FORMAT_PDF), DragExportTypeKey,
             [[NSColor whiteColor] colorAsData],      DragExportJpegColorKey,
             @(100),   DragExportJpegQualityKey,
             @"pdfwrite", DragExportPDFWOFGsWriteEngineKey,
             @"1.5", DragExportPDFWOFGsPDFCompatibilityLevelKey,
             @"", DragExportSvgPdfToSvgPathKey,
             @"", DragExportSvgPdfToCairoPathKey,
             @(YES), DragExportPDFMetadataInvisibleGraphicsEnabledKey,
             @(YES), DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey,
             @(YES), DragExportTextExportPreambleKey,
             @(YES), DragExportTextExportEnvironmentKey,
             @(YES), DragExportTextExportBodyKey,
             @(100),   DragExportScaleAsPercentKey,
             @(NO), DragExportIncludeBackgroundColorKey,
             @(NO), DragExportAddTempFileEnabledKey,
             [[NSColor whiteColor] colorAsData],      DefaultImageViewBackgroundKey,
             @(NO),     DefaultAutomaticHighContrastedPreviewBackgroundKey,
             @(NO),     DefaultDoNotClipPreviewKey,
             [[NSColor  blackColor]   colorAsData],   DefaultColorKey,
             @(36.0), DefaultPointSizeKey,
             @(LATEX_MODE_ALIGN), DefaultModeKey,
             @(YES), SpellCheckingEnableKey,
             @(YES), SyntaxColoringEnableKey,
             [[NSColor textColor] colorAsData], SyntaxColoringTextForegroundColorKey,
             [[NSColor textBackgroundColor]   colorAsData], SyntaxColoringTextBackgroundColorKey,
             [[NSColor textColor] colorAsData], SyntaxColoringTextForegroundColorDarkModeKey,
             [[NSColor textBackgroundColor]   colorAsData], SyntaxColoringTextBackgroundColorDarkModeKey,
             [[NSColor blueColor]    colorAsData], SyntaxColoringCommandColorKey,
             [[[NSColor blueColor] lighter:.33]    colorAsData], SyntaxColoringCommandColorDarkModeKey,
             [[NSColor magentaColor] colorAsData], SyntaxColoringMathsColorKey,
             [[[NSColor magentaColor] lighter:.33] colorAsData], SyntaxColoringMathsColorDarkModeKey,
             [[NSColor blueColor]    colorAsData], SyntaxColoringKeywordColorKey,
             [[[NSColor blueColor] lighter:.33]    colorAsData], SyntaxColoringKeywordColorDarkModeKey,
             [[NSColor colorWithCalibratedRed:0 green:128./255. blue:64./255. alpha:1] colorAsData], SyntaxColoringCommentColorKey,
             [[[NSColor colorWithCalibratedRed:0 green:128./255. blue:64./255. alpha:1] lighter:.33] colorAsData], SyntaxColoringCommentColorDarkModeKey,
             @(YES), EditionTabKeyInsertsSpacesEnabledKey,
             @(2), EditionTabKeyInsertsSpacesCountKey,
             @(NO), EditionAutoCompleteOnBackslashEnabledKey,
             @(NSControlStateValueOff), ReducedTextAreaStateKey,
             [[NSFont fontWithName:@"Monaco" size:12] data], DefaultFontKey,
             factoryDefaultsPreambles, PreamblesKey,
             factoryDefaultsBodyTemplates, BodyTemplatesKey,
             @(0), LatexisationSelectedPreambleIndexKey,
             @(0), ServiceSelectedPreambleIndexKey,
             @(-1), LatexisationSelectedBodyTemplateIndexKey,//none
             @(-1), ServiceSelectedBodyTemplateIndexKey,//none
             [NSArray arrayWithObjects:
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(NO), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_LATEXIZE_ALIGN), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(YES), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_LATEXIZE_ALIGN_CLIPBOARD), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(NO), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_LATEXIZE_DISPLAY), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(YES), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(NO), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_LATEXIZE_INLINE), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(YES), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_LATEXIZE_INLINE_CLIPBOARD), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(NO), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_LATEXIZE_TEXT), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(YES), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_LATEXIZE_TEXT_CLIPBOARD), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(NO), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_MULTILATEXIZE), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(YES), ServiceShortcutClipBoardOptionKey,
                 @(SERVICE_MULTILATEXIZE_CLIPBOARD), ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(YES), ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 @(SERVICE_DELATEXIZE), ServiceShortcutIdentifierKey,
                 nil],
              nil], ServiceShortcutsKey,
            [NSArray arrayWithObjects:
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(NO), ServiceRegularExpressionFilterEnabledKey,
                 @"<latex-align>(.*)</latex-align>", ServiceRegularExpressionFilterInputPatternKey,
                 @"\\\\begin\\{align\\*\\}$1\\\\end\\{align\\*\\}", ServiceRegularExpressionFilterOutputPatternKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(NO), ServiceRegularExpressionFilterEnabledKey,
                 @"<latex-display>(.*)</latex-display>", ServiceRegularExpressionFilterInputPatternKey,
                 @"\\\\[$1\\\\]", ServiceRegularExpressionFilterOutputPatternKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 @(NO), ServiceRegularExpressionFilterEnabledKey,
                 @"<latex-inline>(.*)</latex-inline>", ServiceRegularExpressionFilterInputPatternKey,
                 @"$$1$", ServiceRegularExpressionFilterOutputPatternKey,
                 nil],
              nil], ServiceRegularExpressionFiltersKey,
             @(YES), ServiceRespectsBaselineKey,
             @(YES), ServiceRespectsPointSizeKey,
             @(1.0), ServicePointSizeFactorKey,
             @(YES), ServiceRespectsColorKey,
             @(NO), ServiceUsesHistoryKey,
             @(0), AdditionalTopMarginKey,
             @(0), AdditionalLeftMarginKey,
             @(0), AdditionalRightMarginKey,
             @(0), AdditionalBottomMarginKey,
             @(YES), EncapsulationsEnabledKey,
             @[@"@", @"#", @"\\label{@}", @"\\ref{@}", @"$#$", @"\\[#\\]", @"\\begin{equation}#\\label{@}\\end{equation}"], EncapsulationsKey,
             @(0), CurrentEncapsulationIndexKey,
             defaultTextShortcuts, TextShortcutsKey,
             [NSArray arrayWithObjects:[CompositionConfigurationsController defaultCompositionConfigurationDictionary], nil],
               CompositionConfigurationsKey,
             @(0), CompositionConfigurationDocumentIndexKey,
             @(NO), CompositionConfigurationsControllerVisibleAtStartupKey,
             @(NO), HistoryDeleteOldEntriesEnabledKey,
             @(30), HistoryDeleteOldEntriesLimitKey,
             @(NO), HistorySmartEnabledKey,
             @(NO), EncapsulationsControllerVisibleAtStartupKey,
             @(NO), HistoryControllerVisibleAtStartupKey,
             @(NO), LatexPalettesControllerVisibleAtStartupKey,
             @(NO), LibraryControllerVisibleAtStartupKey,
             @(NO), MarginControllerVisibleAtStartupKey,
             @(LIBRARY_ROW_IMAGE_AND_TEXT), LibraryViewRowTypeKey,
             @(YES), LibraryDisplayPreviewPanelKey,
             @(NO), HistoryDisplayPreviewPanelKey,
             @(0), LatexPaletteGroupKey,
             NSStringFromRect(NSMakeRect(235, 624, 200, 170)), LatexPaletteFrameKey,
             @(NO), LatexPaletteDetailsStateKey,
             @(YES), ShowWhiteColorWarningKey,
             @(NO), SynchronizationNewDocumentsEnabledKey,
             @(YES), SynchronizationNewDocumentsSynchronizePreambleKey,
             @(YES), SynchronizationNewDocumentsSynchronizeEnvironmentKey,
             @(YES), SynchronizationNewDocumentsSynchronizeBodyKey,
             desktopPath, SynchronizationNewDocumentsPathKey,
             [self defaultSynchronizationAdditionalScripts], SynchronizationAdditionalScriptsKey,
             nil];
      
      //read old LaTeXiT preferences if any
      {
        NSMutableArray* allKeys = [NSMutableArray arrayWithArray:[defaults allKeys]];
        [allKeys addObjectsFromArray:[PreferencesController oldKeys]];
        NSEnumerator* keyEnumerator = [allKeys objectEnumerator];
        NSString* key = nil;
        while((key = [keyEnumerator nextObject]))
        {
          CFPropertyListRef oldPlistRef = CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)Old_LaTeXiTAppKey);
          if (oldPlistRef)
          {
            CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CFPropertyListRef)oldPlistRef, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
            CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, 0, (CHBRIDGE CFStringRef)Old_LaTeXiTAppKey);
            CFRelease(oldPlistRef);
          }
        }//end for each default
        CFPreferencesAppSynchronize((CHBRIDGE CFStringRef)Old_LaTeXiTAppKey);
        CFPreferencesAppSynchronize((CHBRIDGE CFStringRef)LaTeXiTAppKey);
      }

      //read LaTeXiT preferences event if we are not LaTeXiT (then certainly we are the Automator action)
      NSUserDefaults* userDefaults = ![self isLaTeXiT] ? nil : [NSUserDefaults standardUserDefaults];
      if (userDefaults)
        [userDefaults registerDefaults:defaults];
      else
      {
        NSEnumerator* keyEnumerator = [defaults keyEnumerator];
        NSString* key = nil;
        while((key = [keyEnumerator nextObject]))
        {
          id value = [defaults objectForKey:key];
          CFPropertyListRef plistRef = CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
          if (plistRef)
            CFRelease(plistRef);
          else
            CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFPropertyListRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
        }//end for each default
        CFPreferencesAppSynchronize((CHBRIDGE CFStringRef)LaTeXiTAppKey);
      }//end if (userDefaults)

      //from version >= 1.6.0, the export format is no more stored as a string but with a number
      id exportFormat = [userDefaults objectForKey:DragExportTypeKey];
      if ([exportFormat isKindOfClass:[NSString class]])
      {
        exportFormat = [exportFormat lowercaseString];
        if ([exportFormat isEqualToString:@"pdf"])
          exportFormat = @(EXPORT_FORMAT_PDF);
        else if ([exportFormat isEqualToString:@"eps"])
          exportFormat = @(EXPORT_FORMAT_EPS);
        else if ([exportFormat isEqualToString:@"tiff"])
          exportFormat = @(EXPORT_FORMAT_TIFF);
        else if ([exportFormat isEqualToString:@"png"])
          exportFormat = @(EXPORT_FORMAT_PNG);
        else if ([exportFormat isEqualToString:@"jpeg"])
          exportFormat = @(EXPORT_FORMAT_JPEG);
        else if ([exportFormat isEqualToString:@"svg"])
          exportFormat = @(EXPORT_FORMAT_SVG);
        else if ([exportFormat isEqualToString:@"text"])
          exportFormat = @(EXPORT_FORMAT_TEXT);
        else
          exportFormat = @(EXPORT_FORMAT_PDF);
        [userDefaults setObject:exportFormat forKey:DragExportTypeKey];
      }//end if ([exportFormat isKindOfClass:[NSString class]])
    }//end if (!initialized)
  }//end @synchronized(self)
}
//end initialize

-(id) init
{
  if (!((self = [super init])))
    return nil;
  self->isLaTeXiT = [[self class] isLaTeXiT];
  [self migratePreferences];
  CFPreferencesAppSynchronize((CHBRIDGE CFStringRef)LaTeXiTAppKey);
  self->exportFormatCurrentSession = [self exportFormatPersistent];
  self->exportAddTempFileCurrentSession = [self exportAddTempFilePersistent];
  [[NSUserDefaultsController sharedUserDefaultsController]
    addObserver:self forKeyPath:[NSUserDefaultsController adaptedKeyPath:DragExportTypeKey] options:0 context:nil];
  [self observeValueForKeyPath:DragExportTypeKey ofObject:[NSUserDefaultsController sharedUserDefaultsController] change:nil context:nil];
  [self observeValueForKeyPath:DragExportAddTempFileEnabledKey ofObject:[NSUserDefaultsController sharedUserDefaultsController] change:nil context:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceDidChange:) name:NSAppearanceDidChangeNotification object:nil];
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[NSUserDefaultsController adaptedKeyPath:DragExportTypeKey]];
  [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[NSUserDefaultsController adaptedKeyPath:DragExportAddTempFileEnabledKey]];
#ifdef ARC_ENABLED
#else
  [self->undoManager release];
  [self->editionTextShortcutsController release];
  [self->preamblesController release];
  [self->bodyTemplatesController release];
  [self->compositionConfigurationsController release];
  [self->serviceShortcutsController release];
  [self->serviceRegularExpressionFiltersController release];
  [self->encapsulationsController release];
  [super dealloc];
#endif
}
//end dealloc

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:[NSUserDefaultsController adaptedKeyPath:DragExportTypeKey]])
    [self setExportFormatCurrentSession:[self exportFormatPersistent]];
  else if ([keyPath isEqualToString:[NSUserDefaultsController adaptedKeyPath:DragExportAddTempFileEnabledKey]])
    [self setExportAddTempFileCurrentSession:[self exportAddTempFilePersistent]];
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) appearanceDidChange:(NSNotification*)notification
{
  [self willChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringTextBackgroundColor))];
  [self didChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringTextBackgroundColor))];
  [self willChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringTextForegroundColor))];
  [self didChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringTextForegroundColor))];
  [self willChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringCommandColor))];
  [self didChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringCommandColor))];
  [self willChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringMathsColor))];
  [self didChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringMathsColor))];
  [self willChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringKeywordColor))];
  [self didChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringKeywordColor))];
  [self willChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringCommentColor))];
  [self didChangeValueForKey:NSStringFromSelector(@selector(editionSyntaxColoringCommentColor))];
}
//end appearanceDidChange:

-(NSUndoManager*) undoManager
{
  if (!self->undoManager)
    self->undoManager = [[NSUndoManager alloc] init];
  return self->undoManager;
}
//end undoManager

-(NSString*) latexitVersion
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:LaTeXiTVersionKey];
  else
    #ifdef ARC_ENABLED
    result = (CHBRIDGE NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)LaTeXiTVersionKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)LaTeXiTVersionKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end latexitVersion

#pragma mark general

-(export_format_t) exportFormatPersistent
{
  export_format_t result = EXPORT_FORMAT_PDF;
  if (self->isLaTeXiT)
    result = (export_format_t)[[NSUserDefaults standardUserDefaults] integerForKey:DragExportTypeKey];
  else
  {
    Boolean ok = NO;
    result = (export_format_t)CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)DragExportTypeKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
    if (!ok)
      result = EXPORT_FORMAT_PDF;
  }
  return result;
}
//end exportFormatPersistent

-(void) setExportFormatPersistent:(export_format_t)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:DragExportTypeKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportTypeKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportTypeKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
  [self setExportFormatCurrentSession:value];
}
//end setExportFormatPersistent:

-(export_format_t) exportFormatCurrentSession
{
  export_format_t result = self->exportFormatCurrentSession;
  return result;
}
//end exportFormatCurrentSession

-(void) setExportFormatCurrentSession:(export_format_t)value
{
  self->exportFormatCurrentSession = value;
}
//end setExportFormatCurrentSession:

-(BOOL) exportAddTempFilePersistent
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:DragExportAddTempFileEnabledKey];
  else//if (!self->isLaTeXiT)
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)DragExportAddTempFileEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  }//end if (!self->isLaTeXiT)
  return result;
}
//end exportAddTempFilePersistent

-(void) setExportAddTempFilePersistent:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:DragExportAddTempFileEnabledKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportAddTempFileEnabledKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportAddTempFileEnabledKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
  [self setExportAddTempFileCurrentSession:value];
}
//end setExportAddTempFilePersistent:

-(BOOL) exportAddTempFileCurrentSession
{
  BOOL result = self->exportAddTempFileCurrentSession;
  return result;
}
//end exportAddTempFileCurrentSession

-(void) setExportAddTempFileCurrentSession:(BOOL)value
{
  self->exportAddTempFileCurrentSession = value;
}
//end setExportAddTempFileCurrentSession:

-(NSData*) exportJpegBackgroundColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:DragExportJpegColorKey];
  else
    #ifdef ARC_ENABLED
    result = (CHBRIDGE NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportJpegColorKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportJpegColorKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end exportJpegBackgroundColorData

-(void) setExportJpegBackgroundColorData:(NSData*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportJpegColorKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportJpegColorKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportJpegColorKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportJpegBackgroundColorData:

-(NSColor*) exportJpegBackgroundColor
{
  NSColor* result = [NSColor colorWithData:[self exportJpegBackgroundColorData]];
  return result;
}
//end exportJpegBackgroundColor

-(void) setExportJpegBackgroundColor:(NSColor*)value
{
  [self setExportJpegBackgroundColorData:[value colorAsData]];
}
//end setExportJpegBackgroundColor:

-(CGFloat) exportJpegQualityPercent
{
  CGFloat result = 0;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportJpegQualityKey];
  else
    #ifdef ARC_ENABLED
    number = (CHBRIDGE NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportJpegQualityKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportJpegQualityKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  result = !number ? 100. : [number floatValue];
  return result;
}
//end exportJpegQualityPercent

-(void) setExportJpegQualityPercent:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportJpegQualityKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportJpegQualityKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportJpegQualityKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportJpegQualityPercent:

-(NSString*) exportPDFWOFGsWriteEngine
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:DragExportPDFWOFGsWriteEngineKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFGsWriteEngineKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFGsWriteEngineKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end exportPDFWOFGsWriteEngine

-(void) setExportPDFWOFGsWriteEngine:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportPDFWOFGsWriteEngineKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFGsWriteEngineKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFGsWriteEngineKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportPDFWOFGsWriteEngine:

-(NSString*) exportPDFWOFGsPDFCompatibilityLevel
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:DragExportPDFWOFGsPDFCompatibilityLevelKey];
  else
#ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFGsPDFCompatibilityLevelKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
#else
  result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFGsPDFCompatibilityLevelKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
#endif
  return result;
}
//end exportPDFWOFGsPDFCompatibilityLevel

-(void) setExportPDFWOFGsPDFCompatibilityLevel:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportPDFWOFGsPDFCompatibilityLevelKey];
  else
#ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFGsPDFCompatibilityLevelKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
#else
  CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFGsPDFCompatibilityLevelKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
#endif
}
//end setExportPDFWOFGsPDFCompatibilityLevel:

-(BOOL) exportPDFWOFMetaDataInvisibleGraphicsEnabled
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey];
  else
  #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
  #else
  number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
  #endif
  result = !number ? NO : [number boolValue];
  return result;
}
//end exportPDFWOFMetaDataInvisibleGraphicsEnabled

-(void) setExportPDFWOFMetaDataInvisibleGraphicsEnabled:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey];
  else
  #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
  #else
  CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
  #endif
}
//end setExportPDFWOFMetaDataInvisibleGraphicsEnabled:

-(BOOL) exportPDFMetaDataInvisibleGraphicsEnabled
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportPDFMetadataInvisibleGraphicsEnabledKey];
  else
  #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFMetadataInvisibleGraphicsEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
  #else
  number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFMetadataInvisibleGraphicsEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
  #endif
  result = !number ? NO : [number boolValue];
  return result;
}
//end exportPDFMetaDataInvisibleGraphicsEnabled

-(void) setExportPDFMetaDataInvisibleGraphicsEnabled:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:DragExportPDFMetadataInvisibleGraphicsEnabledKey];
  else
  #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFMetadataInvisibleGraphicsEnabledKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
  #else
  CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFMetadataInvisibleGraphicsEnabledKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
  #endif
}
//end setExportPDFMetaDataInvisibleGraphicsEnabled:

-(NSString*) exportSvgPdfToSvgPath
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:DragExportSvgPdfToSvgPathKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportSvgPdfToSvgPathKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportSvgPdfToSvgPathKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end exportSvgPdfToSvgPath

-(void) setExportSvgPdfToSvgPath:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportSvgPdfToSvgPathKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportSvgPdfToSvgPathKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportSvgPdfToSvgPathKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportSvgPdfToSvgPath:

-(NSString*) exportSvgPdfToCairoPath
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:DragExportSvgPdfToCairoPathKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportSvgPdfToCairoPathKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportSvgPdfToCairoPathKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end exportSvgPdfToCairoPath

-(void) setExportSvgPdfToCairoPath:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportSvgPdfToCairoPathKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportSvgPdfToCairoPathKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportSvgPdfToCairoPathKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportSvgPdfToCairoPath:

-(BOOL) exportTextExportPreamble
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportTextExportPreambleKey];
  else
    #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportTextExportPreambleKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportTextExportPreambleKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  result = !number ? NO : [number boolValue];
  return result;
}
//end exportTextExportPreamble

-(void) setExportTextExportPreamble:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportTextExportPreambleKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportTextExportPreambleKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportTextExportPreambleKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportTextExportPreamble:

-(BOOL) exportTextExportEnvironment
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportTextExportEnvironmentKey];
  else
    #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportTextExportEnvironmentKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportTextExportEnvironmentKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  result = !number ? NO : [number boolValue];
  return result;
}
//end exportTextExportEnvironment

-(void) setExportTextExportEnvironment:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportTextExportEnvironmentKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportTextExportEnvironmentKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportTextExportEnvironmentKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportTextExportEnvironment:

-(BOOL) exportTextExportBody
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportTextExportBodyKey];
  else
    #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportTextExportBodyKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportTextExportBodyKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  result = !number ? NO : [number boolValue];
  return result;
}
//end exportTextExportBody

-(void) setExportTextExportBody:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportTextExportBodyKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportTextExportBodyKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportTextExportBodyKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportTextExportBody:

-(CGFloat) exportScalePercent
{
  CGFloat result = 0;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportScaleAsPercentKey];
  else
    #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportScaleAsPercentKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportScaleAsPercentKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  result = !number ? 100. : [number floatValue];
  return result;
}
//end exportScalePercent

-(void) setExportScalePercent:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportScaleAsPercentKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportScaleAsPercentKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportScaleAsPercentKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportScalePercent:

-(BOOL) exportIncludeBackgroundColor
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportIncludeBackgroundColorKey];
  else
#ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportIncludeBackgroundColorKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
#else
  number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportIncludeBackgroundColorKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
#endif
  result = !number ? NO : [number boolValue];
  return result;
}
//end exportIncludeBackgroundColor

-(void) setExportIncludeBackgroundColor:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportIncludeBackgroundColorKey];
  else
#ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportIncludeBackgroundColorKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
#else
  CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportIncludeBackgroundColorKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
#endif
}
//end setExportIncludeBackgroundColor:

-(BOOL) doNotClipPreview
{
  BOOL result = 0;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultDoNotClipPreviewKey];
  else
    #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultDoNotClipPreviewKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultDoNotClipPreviewKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  result = [number boolValue];
  return result;
}
//end doNotClipPreview

-(void) setDoNotClipPreview:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:DefaultDoNotClipPreviewKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DefaultDoNotClipPreviewKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DefaultDoNotClipPreviewKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setDoNotClipPreview:

#pragma mark latexisation

-(latex_mode_t) latexisationLaTeXMode
{
  latex_mode_t result = LATEX_MODE_ALIGN;
  if (self->isLaTeXiT)
    result = (latex_mode_t)[[NSUserDefaults standardUserDefaults] integerForKey:DefaultModeKey];
  else
  {
    Boolean ok = NO;
    result = (latex_mode_t)CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)DefaultModeKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
    if (!ok)
      result = LATEX_MODE_ALIGN;
  }
  return result;
}
//end latexisationLaTeXMode

-(void) setLatexisationLaTeXMode:(latex_mode_t)mode
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:DefaultModeKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DefaultModeKey, (CHBRIDGE const void*)@(mode), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DefaultModeKey, @(mode), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setLatexisationLaTeXMode:

-(CGFloat) latexisationFontSize
{
  CGFloat result = 0;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultPointSizeKey];
  else
    #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultPointSizeKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultPointSizeKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  result = !number ? 36. : [number floatValue];
  return result;
}
//end latexisationFontSize

-(NSData*) latexisationFontColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:DefaultColorKey];
  else
    #ifdef ARC_ENABLED
    result = (CHBRIDGE NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultColorKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultColorKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end latexisationFontColorData

-(NSColor*) latexisationFontColor
{
  NSColor* result = [NSColor colorWithData:[self latexisationFontColorData]];
  return result;
}
//end latexisationFontColor

-(document_style_t) documentStyle
{
  document_style_t result = DOCUMENT_STYLE_NORMAL;
  if (self->isLaTeXiT)
    result = (document_style_t)[[NSUserDefaults standardUserDefaults] integerForKey:DocumentStyleKey];
  else
  {
    Boolean ok = NO;
    result = (document_style_t)CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)DocumentStyleKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
    if (!ok)
      result = DOCUMENT_STYLE_NORMAL;
  }
  return result;
}
//end documentStyle

-(void) setDocumentStyle:(document_style_t)documentStyle
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setInteger:documentStyle forKey:DocumentStyleKey];
  else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DocumentStyleKey, (CHBRIDGE CFNumberRef)@(documentStyle), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
}
//end setDocumentStyle:

-(BOOL) documentIsReducedTextArea
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:ReducedTextAreaStateKey];
  else
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)ReducedTextAreaStateKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok) && ok;
  }
  return result;
}
//end documentIsReducedTextArea

-(NSData*) documentImageViewBackgroundColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:DefaultImageViewBackgroundKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultImageViewBackgroundKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultImageViewBackgroundKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end documentImageViewBackgroundColorData

-(NSColor*) documentImageViewBackgroundColor
{
  NSColor* result = [NSColor colorWithData:[self documentImageViewBackgroundColorData]];
  return result;
}
//end documentImageViewBackgroundColor

-(BOOL) documentUseAutomaticHighContrastedPreviewBackground
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultAutomaticHighContrastedPreviewBackgroundKey];
  else
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)DefaultAutomaticHighContrastedPreviewBackgroundKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok) && ok;
  }
  return result;
}
//end documentUseAutomaticHighContrastedPreviewBackground

#pragma mark edition

-(NSData*) editionFontData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:DefaultFontKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultFontKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DefaultFontKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionFontData

-(void) setEditionFontData:(NSData*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DefaultFontKey];
  else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DefaultFontKey, (CHBRIDGE CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
}
//end setEditionFontData:

-(NSFont*) editionFont
{
  NSFont* result = [NSFont fontWithData:[self editionFontData]];
  return result;
}
//end editionFont

-(void) setEditionFont:(NSFont*)value
{
  [self setEditionFontData:[value data]];
}
//end setEditionFont:

-(BOOL) editionSyntaxColoringEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SyntaxColoringEnableKey];
  else
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)SyntaxColoringEnableKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok) && ok;
  }
  return result;
}
//end editionSyntaxColoringEnabled

-(NSData*) editionSyntaxColoringTextBackgroundColorData
{
  NSData* result = nil;
  NSString* key = [NSApp isDarkMode] ? SyntaxColoringTextBackgroundColorDarkModeKey : SyntaxColoringTextBackgroundColorKey;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:key];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringTextBackgroundColorData

-(void) setEditionSyntaxColoringTextBackgroundColorData:(NSData*)value
{
  if (![value isEqual:[self editionSyntaxColoringTextBackgroundColorData]])
  {
    NSString* key = [NSApp isDarkMode] ? SyntaxColoringTextBackgroundColorDarkModeKey : SyntaxColoringTextBackgroundColorKey;
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (![value isEqual:[self editionSyntaxColoringTextBackgroundColorData]])
}
//end setEditionSyntaxColoringTextBackgroundColorData:

-(NSColor*) editionSyntaxColoringTextBackgroundColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringTextBackgroundColorData]];
  return result;
}
//end editionSyntaxColoringTextBackgroundColor

-(void) setEditionSyntaxColoringTextBackgroundColor:(NSColor*)value
{
  if (![value isEqual:[self editionSyntaxColoringTextBackgroundColor]])
  {
    NSString* triggeredKey = NSStringFromSelector(@selector(editionSyntaxColoringTextBackgroundColor));
    [self willChangeValueForKey:triggeredKey];
    [self setEditionSyntaxColoringTextBackgroundColorData:[value colorAsData]];
    [self didChangeValueForKey:triggeredKey];
  }//end if (![value isEqual:[self editionSyntaxColoringTextBackgroundColor]])
}
//end setEditionSyntaxColoringTextBackgroundColor:

-(NSData*) editionSyntaxColoringTextForegroundColorData
{
  NSData* result = nil;
  NSString* key = [NSApp isDarkMode] ? SyntaxColoringTextForegroundColorDarkModeKey : SyntaxColoringTextForegroundColorKey;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:key];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringTextForegroundColorData

-(void) setEditionSyntaxColoringTextForegroundColorData:(NSData*)value
{
  if (![value isEqual:[self editionSyntaxColoringTextForegroundColorData]])
  {
    NSString* key = [NSApp isDarkMode] ? SyntaxColoringTextForegroundColorDarkModeKey : SyntaxColoringTextForegroundColorKey;
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (![value isEqual:[self editionSyntaxColoringTextForegroundColorData]])
}
//end setEditionSyntaxColoringTextForegroundColorData:

-(NSColor*) editionSyntaxColoringTextForegroundColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringTextForegroundColorData]];
  return result;
}
//end editionSyntaxColoringTextForegroundColor

-(void) setEditionSyntaxColoringTextForegroundColor:(NSColor*)value
{
  if (![value isEqual:[self editionSyntaxColoringTextForegroundColor]])
  {
    NSString* triggeredKey = NSStringFromSelector(@selector(editionSyntaxColoringTextForegroundColor));
    [self willChangeValueForKey:triggeredKey];
    [self setEditionSyntaxColoringTextForegroundColorData:[value colorAsData]];
    [self didChangeValueForKey:triggeredKey];
  }//end if (![value isEqual:[self editionSyntaxColoringTextForegroundColor]])
}
//end setEditionSyntaxColoringTextForegroundColor:

-(NSData*) editionSyntaxColoringCommandColorData
{
  NSData* result = nil;
  NSString* key = [NSApp isDarkMode] ? SyntaxColoringCommandColorDarkModeKey : SyntaxColoringCommandColorKey;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:key];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringCommandColorData

-(void) setEditionSyntaxColoringCommandColorData:(NSData*)value
{
  if (![value isEqual:[self editionSyntaxColoringCommandColorData]])
  {
    NSString* key = [NSApp isDarkMode] ? SyntaxColoringCommandColorDarkModeKey : SyntaxColoringCommandColorKey;
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (![value isEqual:[self editionSyntaxColoringCommandColorData]])
}
//end setEditionSyntaxColoringCommandColorData:

-(NSColor*) editionSyntaxColoringCommandColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringCommandColorData]];
  return result;
}
//end editionSyntaxColoringCommandColor

-(void) setEditionSyntaxColoringCommandColor:(NSColor*)value
{
  if (![value isEqual:[self editionSyntaxColoringCommandColor]])
  {
    NSString* triggeredKey = NSStringFromSelector(@selector(editionSyntaxColoringCommandColor));
    [self willChangeValueForKey:triggeredKey];
    [self setEditionSyntaxColoringCommandColorData:[value colorAsData]];
    [self didChangeValueForKey:triggeredKey];
  }//end if (![value isEqual:[self editionSyntaxColoringCommandColor]])
}
//end setEditionSyntaxColoringCommandColor:

-(NSData*) editionSyntaxColoringMathsColorData
{
  NSData* result = nil;
  NSString* key = [NSApp isDarkMode] ? SyntaxColoringMathsColorDarkModeKey : SyntaxColoringMathsColorKey;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:key];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringMathsColorData

-(void) setEditionSyntaxColoringMathsColorData:(NSData*)value
{
  if (![value isEqual:[self editionSyntaxColoringMathsColorData]])
  {
    NSString* key = [NSApp isDarkMode] ? SyntaxColoringMathsColorDarkModeKey : SyntaxColoringMathsColorKey;
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (![value isEqual:[self editionSyntaxColoringMathsColorData]])
}
//end setEditionSyntaxColoringMathsColorData:

-(NSColor*) editionSyntaxColoringMathsColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringMathsColorData]];
  return result;
}
//end editionSyntaxColoringMathsColor

-(void) setEditionSyntaxColoringMathsColor:(NSColor*)value
{
  if (![value isEqual:[self editionSyntaxColoringMathsColor]])
  {
    NSString* triggeredKey = NSStringFromSelector(@selector(editionSyntaxColoringMathsColor));
    [self willChangeValueForKey:triggeredKey];
    [self setEditionSyntaxColoringMathsColorData:[value colorAsData]];
    [self didChangeValueForKey:triggeredKey];
  }//end if (![value isEqual:[self editionSyntaxColoringMathsColor]])
}
//end setEditionSyntaxColoringMathsColor:

-(NSData*) editionSyntaxColoringKeywordColorData
{
  NSData* result = nil;
  NSString* key = [NSApp isDarkMode] ? SyntaxColoringKeywordColorDarkModeKey : SyntaxColoringKeywordColorKey;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:key];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringKeywordColorData

-(void) setEditionSyntaxColoringKeywordColorData:(NSData*)value
{
  if (![value isEqual:[self editionSyntaxColoringKeywordColorData]])
  {
    NSString* key = [NSApp isDarkMode] ? SyntaxColoringKeywordColorDarkModeKey : SyntaxColoringKeywordColorKey;
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (![value isEqual:[self editionSyntaxColoringKeywordColorData]])
}
//end setEditionSyntaxColoringKeywordColorData:

-(NSColor*) editionSyntaxColoringKeywordColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringKeywordColorData]];
  return result;
}
//end editionSyntaxColoringKeywordColor

-(void) setEditionSyntaxColoringKeywordColor:(NSColor*)value
{
  if (![value isEqual:[self editionSyntaxColoringKeywordColor]])
  {
    NSString* triggeredKey = NSStringFromSelector(@selector(editionSyntaxColoringKeywordColor));
    [self willChangeValueForKey:triggeredKey];
    [self setEditionSyntaxColoringKeywordColorData:[value colorAsData]];
    [self didChangeValueForKey:triggeredKey];
  }//end if (![value isEqual:[self editionSyntaxColoringKeywordColor]])
}
//end setEditionSyntaxColoringKeywordColor:

-(NSData*) editionSyntaxColoringCommentColorData
{
  NSData* result = nil;
  NSString* key = [NSApp isDarkMode] ? SyntaxColoringCommentColorDarkModeKey : SyntaxColoringCommentColorKey;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:key];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringCommentColorData

-(void) setEditionSyntaxColoringCommentColorData:(NSData*)value
{
  if (![value isEqual:[self editionSyntaxColoringCommentColorData]])
  {
    NSString* key = [NSApp isDarkMode] ? SyntaxColoringCommentColorDarkModeKey : SyntaxColoringCommentColorKey;
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CHBRIDGE CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)key, (CFDataRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (![value isEqual:[self editionSyntaxColoringCommentColorData]])
}
//end setEditionSyntaxColoringCommentColorData:

-(NSColor*) editionSyntaxColoringCommentColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringCommentColorData]];
  return result;
}
//end editionSyntaxColoringCommentColor

-(void) setEditionSyntaxColoringCommentColor:(NSColor*)value
{
  if (![value isEqual:[self editionSyntaxColoringCommentColor]])
  {
    NSString* triggeredKey = NSStringFromSelector(@selector(editionSyntaxColoringCommentColor));
    [self willChangeValueForKey:triggeredKey];
    [self setEditionSyntaxColoringCommentColorData:[value colorAsData]];
    [self didChangeValueForKey:triggeredKey];
  }//end if (![value isEqual:[self editionSyntaxColoringCommentColor]])
}
//end setEditionSyntaxColoringCommentColor:

-(NSArray*) editionTextShortcuts
{
  NSArray* result = [self editionTextShortcutsFromControllerIfPossible:YES createControllerIfNeeded:NO];
  return result;
}
//end editionTextShortcuts

-(NSArrayController*) editionTextShortcutsController
{
  NSArrayController* result = [self lazyEditionTextShortcutsControllerWithCreationIfNeeded:YES];
  return result;
}
//end editionTextShortcutsController

-(BOOL) editionTabKeyInsertsSpacesEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:EditionTabKeyInsertsSpacesEnabledKey];
  else
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)EditionTabKeyInsertsSpacesEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok) && ok;
  }
  return result;
}
//end editionTabKeyInsertsSpacesEnabled

-(NSUInteger) editionTabKeyInsertsSpacesCount
{
  NSUInteger result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:EditionTabKeyInsertsSpacesCountKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)EditionTabKeyInsertsSpacesCountKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) unsignedIntegerValue];
    #else
    result = [[NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)EditionTabKeyInsertsSpacesCountKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] unsignedIntegerValue];
    #endif
  return result;
}
//end editionTabKeyInsertsSpacesCount

-(BOOL) editionAutoCompleteOnBackslashEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:EditionAutoCompleteOnBackslashEnabledKey];
  else
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)EditionAutoCompleteOnBackslashEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok) && ok;
  }
  return result;
}
//end editionAutoCompleteOnBackslashEnabled

-(void) setEditionAutoCompleteOnBackslashEnabled:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:EditionAutoCompleteOnBackslashEnabledKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)EditionAutoCompleteOnBackslashEnabledKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)EditionAutoCompleteOnBackslashEnabledKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setEditionAutoCompleteOnBackslashEnabled:

#pragma mark preambles

-(NSArray*) preambles
{
  NSArray* result = [self preamblesFromControllerIfPossible:YES createControllerIfNeeded:NO];
  return result;
}
//end preambles

-(NSInteger) preambleDocumentIndex
{
  NSInteger result = 0;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:LatexisationSelectedPreambleIndexKey];
  else
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)LatexisationSelectedPreambleIndexKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end preambleDocumentIndex

-(NSInteger) preambleServiceIndex
{
  NSInteger result = 0;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:ServiceSelectedPreambleIndexKey];
  else
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)ServiceSelectedPreambleIndexKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end preambleServiceIndex

-(NSAttributedString*) preambleDocumentAttributedString
{
  NSAttributedString* result = nil;
  NSArray* preambles = [self preambles];
  NSInteger preambleDocumentIndex = [self preambleDocumentIndex];
  NSDictionary* preamble = (0<=preambleDocumentIndex) && ((unsigned)preambleDocumentIndex<[preambles count]) ?
                           [preambles objectAtIndex:preambleDocumentIndex] : nil;
  NSData* preambleData = [[preamble objectForKey:@"value"] dynamicCastToClass:[NSData class]];
  NSError* decodingError = nil;
  NSSet* securedClasses = [NSSet setWithArray:@[[NSAttributedString class], [NSTextTab class]]];//NSTextTab needed by a bug in High Sierra
  result = !preambleData ? nil :
    isMacOS10_13OrAbove() ? [NSKeyedUnarchiver unarchivedObjectOfClasses:securedClasses fromData:preambleData error:&decodingError] :
    [[NSKeyedUnarchiver unarchiveObjectWithData:preambleData] dynamicCastToClass:[NSAttributedString class]];
  if (decodingError != nil)
    DebugLog(0, @"decoding error : %@", decodingError);
  if (!result)
    result = [PreamblesController defaultLocalizedPreambleValueAttributedString];
  return result;
}
//end preambleDocumentAttributedString

-(NSAttributedString*) preambleServiceAttributedString
{
  NSAttributedString* result = nil;
  NSArray* preambles = [self preambles];
  NSInteger preambleServiceIndex = [self preambleServiceIndex];
  NSDictionary* preamble = (0<=preambleServiceIndex) && ((unsigned)preambleServiceIndex<[preambles count]) ?
                           [preambles objectAtIndex:preambleServiceIndex] : nil;
  NSData* preambleData = [[preamble objectForKey:@"value"] dynamicCastToClass:[NSData class]];
  NSError* decodingError = nil;
  NSSet* securedClasses = [NSSet setWithArray:@[[NSAttributedString class], [NSTextTab class]]];//NSTextTab needed by a bug in High Sierra
  result = !preambleData ? nil :
    isMacOS10_13OrAbove() ? [NSKeyedUnarchiver unarchivedObjectOfClasses:securedClasses fromData:preambleData error:&decodingError] :
    [[NSKeyedUnarchiver unarchiveObjectWithData:preambleData] dynamicCastToClass:[NSAttributedString class]];
  if (decodingError != nil)
    DebugLog(0, @"decoding error : %@", decodingError);
  if (!result)
    result = [PreamblesController defaultLocalizedPreambleValueAttributedString];
  return result;
}
//end preambleServiceAttributedString

-(PreamblesController*) preamblesController
{
  PreamblesController* result = [self lazyPreamblesControllerWithCreationIfNeeded:YES];
  return result;
}
//end preamblesController

#pragma mark bodyTemplates

-(NSArray*) bodyTemplates
{
  NSArray* result = [self bodyTemplatesFromControllerIfPossible:YES createControllerIfNeeded:self->isLaTeXiT];
  return result;
}
//end bodyTemplates

-(NSArray*) bodyTemplatesWithNone
{
  NSArray* result = [self bodyTemplatesFromControllerIfPossible:YES createControllerIfNeeded:self->isLaTeXiT];
  result = [result arrayByAddingObject:[BodyTemplatesController noneBodyTemplate] atIndex:0];
  return result;
}
//end bodyTemplates

-(NSInteger) bodyTemplateDocumentIndex
{
  NSInteger result = 0;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:LatexisationSelectedBodyTemplateIndexKey];
  else
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)LatexisationSelectedBodyTemplateIndexKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end bodyTemplateDocumentIndex

-(NSInteger) bodyTemplateServiceIndex
{
  NSInteger result = 0;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:ServiceSelectedBodyTemplateIndexKey];
  else
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)ServiceSelectedBodyTemplateIndexKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end bodyTemplateServiceIndex

-(NSDictionary*) bodyTemplateDocumentDictionary
{
  NSDictionary* result = nil;
  NSArray* bodyTemplates = [self bodyTemplates];
  NSInteger bodyTemplateDocumentIndex = [self bodyTemplateDocumentIndex];
  NSDictionary* bodyTemplate = (0<=bodyTemplateDocumentIndex) && ((unsigned)bodyTemplateDocumentIndex<[bodyTemplates count]) ?
                           [bodyTemplates objectAtIndex:bodyTemplateDocumentIndex] : nil;
  result = !bodyTemplate? nil : [NSDictionary dictionaryWithDictionary:bodyTemplate];
  return result;
}
//end bodyTemplateDocumentDictionary

-(NSDictionary*) bodyTemplateServiceDictionary
{
  NSDictionary* result = nil;
  NSArray* bodyTemplates = [self bodyTemplates];
  NSInteger bodyTemplateServiceIndex = [self bodyTemplateServiceIndex];
  NSDictionary* bodyTemplate = (0<=bodyTemplateServiceIndex) && ((NSUInteger)bodyTemplateServiceIndex<[bodyTemplates count]) ?
                           [bodyTemplates objectAtIndex:bodyTemplateServiceIndex] : nil;
  result = !bodyTemplate? nil : [NSDictionary dictionaryWithDictionary:bodyTemplate];
  return result;
}
//end bodyTemplateServiceDictionary

-(BodyTemplatesController*) bodyTemplatesController
{
  BodyTemplatesController* result = [self lazyBodyTemplatesControllerWithCreationIfNeeded:YES];
  return result;
}
//end bodyTemplatesController

#pragma mark composition

-(NSArray*) compositionConfigurations
{
  NSArray* result = [self compositionConfigurationsFromControllerIfPossible:YES createControllerIfNeeded:NO];
  return result;
}
//end compositionConfigurations

-(void) setCompositionConfigurations:(NSArray*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:CompositionConfigurationsKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)CompositionConfigurationsKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)CompositionConfigurationsKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setCompositionConfigurations:

-(NSInteger) compositionConfigurationsDocumentIndex
{
  NSInteger result = 0;
  NSArrayController* compositionsController = [self lazyCompositionConfigurationsControllerWithCreationIfNeeded:NO];
  if (compositionsController)
  {
    NSUInteger result2 = [compositionsController selectionIndex];
    result = (result2 == NSNotFound) ? -1 : (NSInteger)result2;
  }
  else
  {
    Boolean ok = NO;
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] integerForKey:CompositionConfigurationDocumentIndexKey];
    else
      result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)CompositionConfigurationDocumentIndexKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  }
  return result;
}
//end compositionConfigurationsDocumentIndex

-(void) setCompositionConfigurationsDocumentIndex:(NSInteger)value
{
  NSArrayController* compositionsController = [self lazyCompositionConfigurationsControllerWithCreationIfNeeded:NO];
  if (compositionsController)
  {
    if (value >= 0)
      [compositionsController setSelectionIndex:value];
    else
      [compositionsController setSelectionIndexes:[NSIndexSet indexSet]];
  }//end if (compositionsController)
  else//if (!compositionsController)
  {
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setInteger:value forKey:CompositionConfigurationDocumentIndexKey];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)CompositionConfigurationDocumentIndexKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)CompositionConfigurationDocumentIndexKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (!compositionsController)
}
//end setCompositionConfigurationsDocumentIndex:

-(NSDictionary*) compositionConfigurationDocument
{
  NSDictionary* result = nil;
  NSArray* configurations = [self compositionConfigurations];
  NSUInteger selectedIndex = Clip(0, [self compositionConfigurationsDocumentIndex], [configurations count]);
  result = (selectedIndex < [configurations count]) ? [configurations objectAtIndex:selectedIndex] : nil;
  return result;
}
//end compositionConfigurationDocument

-(void) setCompositionConfigurationDocument:(NSDictionary*)value
{
  NSMutableArray* configurations = [[self compositionConfigurations] mutableCopy];
  NSUInteger selectedIndex = Clip(0, [self compositionConfigurationsDocumentIndex], [configurations count]);
  if (selectedIndex < [configurations count])
  {
    [configurations replaceObjectAtIndex:selectedIndex withObject:value];
    [self setCompositionConfigurations:configurations];
  }
  #ifdef ARC_ENABLED
  #else
  [configurations release];
  #endif
}
//end setCompositionConfigurationDocument:

-(void) setCompositionConfigurationDocumentProgramPath:(NSString*)value forKey:(NSString*)key
{
  NSMutableDictionary* configuration = [[self compositionConfigurationDocument] mutableCopyDeep];
  [configuration setObject:value forKey:key];
  [self setCompositionConfigurationDocument:configuration];
  #ifdef ARC_ENABLED
  #else
  [configuration release];
  #endif
}
//end setCompositionConfigurationDocumentProgramPath:forKey:

-(CompositionConfigurationsController*) compositionConfigurationsController
{
  CompositionConfigurationsController* result = [self lazyCompositionConfigurationsControllerWithCreationIfNeeded:YES];
  return result;
}
//end compositionConfigurationsController

#pragma mark history_export_format_t
-(BOOL) historySaveServicesResultsEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:ServiceUsesHistoryKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceUsesHistoryKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceUsesHistoryKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
    #endif
  return result;
}
//end historySaveServicesEnabled

-(BOOL) historyDeleteOldEntriesEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:HistoryDeleteOldEntriesEnabledKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)HistoryDeleteOldEntriesEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)HistoryDeleteOldEntriesEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
    #endif
  return result;
}
//end historyDeleteOldEntriesEnabled

-(NSNumber*) historyDeleteOldEntriesLimit
{
  NSNumber* result = @(NSUIntegerMax);
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] objectForKey:HistoryDeleteOldEntriesLimitKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)HistoryDeleteOldEntriesLimitKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)HistoryDeleteOldEntriesLimitKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end historyDeleteOldEntriesLimit

-(BOOL) historySmartEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:HistorySmartEnabledKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)HistorySmartEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)HistorySmartEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
    #endif
  return result;
}
//end historySmartEnabled:

#pragma mark service

-(NSString*) serviceDescriptionForIdentifier:(service_identifier_t)identifier
{
  NSString* result = nil;
  switch(identifier)
  {
    case SERVICE_LATEXIZE_ALIGN:
      result = @"Typeset LaTeX Maths align";
      break;
    case SERVICE_LATEXIZE_ALIGN_CLIPBOARD:
      result = @"Typeset LaTeX Maths align and put result into clipboard";
      break;
    case SERVICE_LATEXIZE_EQNARRAY:
      result = @"Typeset LaTeX Maths eqnarray";
      break;
    case SERVICE_LATEXIZE_EQNARRAY_CLIPBOARD:
      result = @"Typeset LaTeX Maths eqnarray and put result into clipboard";
      break;
    case SERVICE_LATEXIZE_DISPLAY:
      result = @"Typeset LaTeX Maths display";
      break;
    case SERVICE_LATEXIZE_DISPLAY_CLIPBOARD:
      result = @"Typeset LaTeX Maths display and put result into clipboard";
      break;
    case SERVICE_LATEXIZE_INLINE:
      result = @"Typeset LaTeX Maths inline";
      break;
    case SERVICE_LATEXIZE_INLINE_CLIPBOARD:
      result = @"Typeset LaTeX Maths inline and put result into clipboard";
      break;
    case SERVICE_LATEXIZE_TEXT:
      result = @"Typeset LaTeX Text";
      break;
    case SERVICE_LATEXIZE_TEXT_CLIPBOARD:
      result = @"Typeset LaTeX Text and put result into clipboard";
      break;
    case SERVICE_MULTILATEXIZE:
      result = @"Detect and typeset equations";
      break;
    case SERVICE_MULTILATEXIZE_CLIPBOARD:
      result = @"Detect and typeset equations and put result into clipboard";
      break;
    case SERVICE_DELATEXIZE:
      result = @"Un-latexize the equations";
      break;
  }//end switch((service_identifier_t)[identifier integerValue])
  return result;
}
//end serviceDescriptionForIdentifier:

-(NSArray*) serviceShortcuts
{
  NSArray* result = [self serviceShortcutsFromControllerIfPossible:YES createControllerIfNeeded:NO];
  return result;
}
//end serviceShortcuts

-(void) setServiceShortcuts:(NSArray*)value
{
  NSArrayController* controller = [self lazyServiceShortcutsControllerWithCreationIfNeeded:NO];
  if (controller)
    #ifdef ARC_ENABLED
    [controller setContent:[value mutableCopy]];
    #else
    [controller setContent:[[value mutableCopy] autorelease]];
    #endif
  else if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:ServiceShortcutsKey];
  else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)ServiceShortcutsKey, (CHBRIDGE CFPropertyListRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
}
//end setServiceShortcuts:

-(NSArrayController*) serviceShortcutsController
{
  NSArrayController* result = [self lazyServiceShortcutsControllerWithCreationIfNeeded:YES];
  return result;
}
//end serviceShortcutsController

-(NSArray*) serviceRegularExpressionFilters
{
  NSArray* result = [self serviceRegularExpressionFiltersFromControllerIfPossible:YES createControllerIfNeeded:NO];
  return result;
}
//end serviceRegularExpressionFilters

-(void) setServiceRegularExpressionFilters:(NSArray*)value
{
  ServiceRegularExpressionFiltersController* controller = [self lazyServiceRegularExpressionFiltersControllerWithCreationIfNeeded:NO];
  if (controller)
    #ifdef ARC_ENABLED
    [controller setContent:[value mutableCopy]];
    #else
    [controller setContent:[[value mutableCopy] autorelease]];
    #endif
  else if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:ServiceRegularExpressionFiltersKey];
  else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)ServiceRegularExpressionFiltersKey, (CHBRIDGE CFPropertyListRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
}
//end setServiceRegularExpressionFilters:

-(ServiceRegularExpressionFiltersController*) serviceRegularExpressionFiltersController
{
  ServiceRegularExpressionFiltersController* result = [self lazyServiceRegularExpressionFiltersControllerWithCreationIfNeeded:YES];
  return result;
}
//end serviceRegularExpressionFiltersController

#pragma mark margins

-(CGFloat) marginsAdditionalLeft
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalLeftMarginKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalLeftMarginKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) floatValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalLeftMarginKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] floatValue];
    #endif
  return result;
}
//end marginsAdditionalLeft

-(void) setMarginsAdditionalLeft:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:AdditionalLeftMarginKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalLeftMarginKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalLeftMarginKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setMarginsAdditionalLeft:

-(CGFloat) marginsAdditionalRight
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] doubleForKey:AdditionalRightMarginKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalRightMarginKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) doubleValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalRightMarginKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] floatValue];
    #endif
  return result;
}
//end marginsAdditionalRight

-(void) setMarginsAdditionalRight:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:AdditionalRightMarginKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalRightMarginKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalRightMarginKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setMarginsAdditionalRight:

-(CGFloat) marginsAdditionalTop
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalTopMarginKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalTopMarginKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) floatValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalTopMarginKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] floatValue];
    #endif
  return result;
}
//end marginsAdditionalTop

-(void) setMarginsAdditionalTop:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setDouble:value forKey:AdditionalTopMarginKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalTopMarginKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalTopMarginKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setMarginsAdditionalTop:

-(CGFloat) marginsAdditionalBottom
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] doubleForKey:AdditionalBottomMarginKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalBottomMarginKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) doubleValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalBottomMarginKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] floatValue];
    #endif
  return result;
}
//end marginsAdditionalBottom

-(void) setMarginsAdditionalBottom:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:AdditionalBottomMarginKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalBottomMarginKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalBottomMarginKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setMarginsAdditionalBottom:

#pragma mark encapsulations

-(BOOL) encapsulationsEnabled
{
  BOOL result = YES;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:EncapsulationsEnabledKey];
  else
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)EncapsulationsEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end encapsulationsEnabled

-(NSArray*) encapsulations
{
  NSArray* result = [self encapsulationsFromControllerIfPossible:YES createControllerIfNeeded:NO];
  return result;
}
//end encapsulations

-(NSInteger) encapsulationsSelectedIndex
{
  NSInteger result = 0;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:CurrentEncapsulationIndexKey];
  else
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)CurrentEncapsulationIndexKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end encapsulationsSelectedIndex

-(NSString*) encapsulationSelected
{
  NSString* result = nil;
  NSArray* encapsulations = [self encapsulations];
  NSUInteger selectedIndex = Clip(0, [self encapsulationsSelectedIndex], [encapsulations count]);
  result = (selectedIndex < [encapsulations count]) ? [encapsulations objectAtIndex:selectedIndex] : nil;
  return result;
}
//end encapsulationSelected

-(EncapsulationsController*) encapsulationsController
{
  EncapsulationsController* result = [self lazyEncapsulationsControllerWithCreationIfNeeded:YES];
  return result;
}
//end encapsulationsController

#pragma mark additional files

-(NSArray*) additionalFilesPaths
{
  NSArray* result = [self additionalFilesPathsFromControllerIfPossible:YES createControllerIfNeeded:NO];
  return result;
}
//end additionalFilesPaths

-(void) setAdditionalFilesPaths:(NSArray*)value
{
  if (self->additionalFilesController)
      [self->additionalFilesController setContent:value];
  else//if (!additionalFilesController)
  {
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:AdditionalFilesPathsKey];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalFilesPathsKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)AdditionalFilesPathsKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (!additionalFilesController)
}
//end setAdditionalFilesPaths:

-(AdditionalFilesController*) additionalFilesController
{
  AdditionalFilesController* result = [self lazyAdditionalFilesControllerWithCreationIfNeeded:YES];
  return result;
}
//end additionalFilesController

#pragma mark synchronization additional scripts

-(BOOL) synchronizationNewDocumentsEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SynchronizationNewDocumentsEnabledKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
    #endif
  return result;
}
//end synchronizationNewDocumentsEnabled

-(void) setSynchronizationNewDocumentsEnabled:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsEnabledKey];
  else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsEnabledKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsEnabledKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
}
//end setSynchronizationNewDocumentsEnabled:

-(BOOL) synchronizationNewDocumentsSynchronizePreamble
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SynchronizationNewDocumentsSynchronizePreambleKey];
  else//if (!self->isLaTeXiT)
  {
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) boolValue];
    #else
    result = [[NSMakeCollectable(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
    #endif
  }//end if (!self->isLaTeXiT)
  return result;
}
//end synchronizationNewDocumentsSynchronizePreamble

-(void) setSynchronizationNewDocumentsSynchronizePreamble:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsSynchronizePreambleKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setSynchronizationNewDocumentsSynchronizePreamble:

-(BOOL) synchronizationNewDocumentsSynchronizeEnvironment
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SynchronizationNewDocumentsSynchronizeEnvironmentKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
    #endif
  return result;
}
//end synchronizationNewDocumentsSynchronizeEnvironment

-(void) setSynchronizationNewDocumentsSynchronizeEnvironment:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsSynchronizeEnvironmentKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setSynchronizationNewDocumentsSynchronizeEnvironment:

-(BOOL) synchronizationNewDocumentsSynchronizeBody
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SynchronizationNewDocumentsSynchronizeBodyKey];
  else
    #ifdef ARC_ENABLED
    result = [(__bridge_transfer NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
    #endif
  return result;
}
//end synchronizationNewDocumentsSynchronizeBody

-(void) setSynchronizationNewDocumentsSynchronizeBody:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsSynchronizeBodyKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setSynchronizationNewDocumentsSynchronizeBody:

-(NSString*) synchronizationNewDocumentsPath
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:SynchronizationNewDocumentsPathKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsPathKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsPathKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end synchronizationNewDocumentsPath

-(void) setSynchronizationNewDocumentsPath:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:SynchronizationNewDocumentsPathKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsPathKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)SynchronizationNewDocumentsPathKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setSynchronizationNewDocumentsPath:

-(NSDictionary*) synchronizationAdditionalScripts
{
  NSDictionary* result = [self synchronizationAdditionalScriptsFromControllerIfPossible:YES createControllerIfNeeded:YES];
  return result;
}
//end synchronizationAdditionalScripts

-(SynchronizationAdditionalScriptsController*) synchronizationAdditionalScriptsController
{
  SynchronizationAdditionalScriptsController* result = [self lazySynchronizationAdditionalScriptsControllerWithCreationIfNeeded:YES];
  return result;
}
//end synchronizationAdditionalScriptsController

-(SynchronizationAdditionalScriptsController*) lazySynchronizationAdditionalScriptsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  SynchronizationAdditionalScriptsController* result = self->synchronizationAdditionalScriptsController;
  if (!self->synchronizationAdditionalScriptsController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->synchronizationAdditionalScriptsController = [[SynchronizationAdditionalScriptsController alloc] initWithContent:nil];
      [self->synchronizationAdditionalScriptsController setAvoidsEmptySelection:NO];
      [self->synchronizationAdditionalScriptsController setAutomaticallyPreparesContent:YES];
      [self->synchronizationAdditionalScriptsController setObjectClass:[NSMutableDictionary class]];
      [self->synchronizationAdditionalScriptsController setPreservesSelection:YES];
      [self->synchronizationAdditionalScriptsController bind:NSContentArrayBinding
                                                    toObject:[NSUserDefaultsController sharedUserDefaultsController]
                                                 withKeyPath:[NSUserDefaultsController adaptedKeyPath:SynchronizationAdditionalScriptsKey]
                                                     options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                               [DictionaryToArrayTransformer transformerWithDescriptors:nil], NSValueTransformerBindingOption,
                                                               @(YES), NSHandlesContentAsCompoundValueBindingOption,
                                                               nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSDictionary* synchronizationAdditionalScripts = (CHBRIDGE NSDictionary*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationAdditionalScriptsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #else
      NSDictionary* synchronizationAdditionalScripts = [NSMakeCollectable((NSDictionary*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationAdditionalScriptsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      NSArray* array = [[DictionaryToArrayTransformer transformerWithDescriptors:nil] transformedValue:synchronizationAdditionalScripts];
      self->synchronizationAdditionalScriptsController = [[SynchronizationAdditionalScriptsController alloc] initWithContent:array];
    }
    result = self->synchronizationAdditionalScriptsController;
  }//end if (!self->synchronizationAdditionalScriptsController && creationOptionIfNeeded)
  return result;
}
//end lazySynchronizationAdditionalScriptsControllerWithCreationIfNeeded:

-(NSDictionary*) synchronizationAdditionalScriptsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSDictionary* result = nil;
  if (fromControllerIfPossible)
  {
    NSArray* array = [[self lazySynchronizationAdditionalScriptsControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
    result = [[DictionaryToArrayTransformer transformerWithDescriptors:nil] reverseTransformedValue:array];
  }//end if (fromControllerIfPossible)
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SynchronizationAdditionalScriptsKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationAdditionalScriptsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSDictionary*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)SynchronizationAdditionalScriptsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }//end if (!result)
  return result;
}
//end synchronizationAdditionalScriptsFromControllerIfPossible:createControllerIfNeeded:

+(NSMutableDictionary*) defaultSynchronizationAdditionalScripts
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    [NSDictionary dictionaryWithObjectsAndKeys:
      @(NO), CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      @(SCRIPT_SOURCE_STRING), CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [@(SYNCHRONIZATION_SCRIPT_PLACE_LOADING_PREPROCESSING) stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      @(NO), CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      @(SCRIPT_SOURCE_STRING), CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [@(SYNCHRONIZATION_SCRIPT_PLACE_LOADING_POSTPROCESSING) stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      @(NO), CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      @(SCRIPT_SOURCE_STRING), CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [@(SYNCHRONIZATION_SCRIPT_PLACE_SAVING_PREPROCESSING) stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      @(NO), CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      @(SCRIPT_SOURCE_STRING), CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [@(SYNCHRONIZATION_SCRIPT_PLACE_SAVING_POSTPROCESSING) stringValue],
    nil];
  return result;
}
//end defaultSynchronizationAdditionalScripts

#pragma mark Palette LaTeX

-(NSInteger) paletteLaTeXGroupSelectedTag
{
  NSInteger result = 0;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:LatexPaletteGroupKey];
  else
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)LatexPaletteGroupKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end paletteLaTeXGroupSelectedTag

-(void) setPaletteLaTeXGroupSelectedTag:(NSInteger)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:LatexPaletteGroupKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LatexPaletteGroupKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LatexPaletteGroupKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setPaletteLaTeXGroupSelectedTag:

-(NSRect) paletteLaTeXWindowFrame
{
  NSRect result = NSZeroRect;
  NSString* frameAsString = nil;
  if (self->isLaTeXiT)
    frameAsString = [[NSUserDefaults standardUserDefaults] stringForKey:LatexPaletteFrameKey];
  else
    #ifdef ARC_ENABLED
    frameAsString = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)LatexPaletteFrameKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    frameAsString = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)LatexPaletteFrameKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  if (frameAsString)
    result = NSRectFromString(frameAsString);
  return result;
}
//end paletteLaTeXWindowFrame

-(void) setPaletteLaTeXWindowFrame:(NSRect)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect(value) forKey:LatexPaletteFrameKey];
  else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LatexPaletteFrameKey, (CHBRIDGE CFStringRef)NSStringFromRect(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
}
//end setPaletteLaTeXWindowFrame:

-(BOOL) paletteLaTeXDetailsOpened
{
  BOOL result = NO;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:LatexPaletteDetailsStateKey];
  else
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)LatexPaletteDetailsStateKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end paletteLaTeXDetailsOpened

-(void) setPaletteLaTeXDetailsOpened:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:LatexPaletteDetailsStateKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LatexPaletteDetailsStateKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LatexPaletteDetailsStateKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setPaletteLaTeXDetailsOpened:

#pragma mark History

-(BOOL) historyDisplayPreviewPanelState
{
  BOOL result = NO;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:HistoryDisplayPreviewPanelKey];
  else
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)HistoryDisplayPreviewPanelKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end historyDisplayPreviewPanelState

-(void) setHistoryDisplayPreviewPanelState:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:HistoryDisplayPreviewPanelKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)HistoryDisplayPreviewPanelKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)HistoryDisplayPreviewPanelKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setHistoryDisplayPreviewPanelState

#pragma mark Library

-(NSString*) libraryPath
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:LibraryPathKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)LibraryPathKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)LibraryPathKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end libraryPath

-(void) setLibraryPath:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:LibraryPathKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LibraryPathKey, (CHBRIDGE const void*)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LibraryPathKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setLibraryPath:

-(BOOL) libraryDisplayPreviewPanelState
{
  BOOL result = NO;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:LibraryDisplayPreviewPanelKey];
  else
    result = CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)LibraryDisplayPreviewPanelKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end libraryDisplayPreviewPanelState

-(void) setLibraryDisplayPreviewPanelState:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:LibraryDisplayPreviewPanelKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LibraryDisplayPreviewPanelKey, (CHBRIDGE const void*)@(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)LibraryDisplayPreviewPanelKey, @(value), (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setLibraryDisplayPreviewPanelState

-(library_row_t) libraryViewRowType
{
  library_row_t result = LIBRARY_ROW_IMAGE_AND_TEXT;
  if (self->isLaTeXiT)
    result = (library_row_t)[[NSUserDefaults standardUserDefaults] integerForKey:LibraryViewRowTypeKey];
  else
  {
    Boolean ok = NO;
    result =  (library_row_t)CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)LibraryViewRowTypeKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
    if (!ok)
      result = LIBRARY_ROW_IMAGE_AND_TEXT;
  }
  return result;
}
//end libraryViewRowType

#pragma mark private

-(NSArrayController*) lazyEditionTextShortcutsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  NSArrayController* result = self->editionTextShortcutsController;
  if (!self->editionTextShortcutsController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->editionTextShortcutsController = [[NSArrayController alloc] initWithContent:nil];
      [self->editionTextShortcutsController bind:NSContentArrayBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
        withKeyPath:[NSUserDefaultsController adaptedKeyPath:TextShortcutsKey]
            options:[NSDictionary dictionaryWithObjectsAndKeys:@(YES), NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* editionTextShortcuts = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)TextShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* editionTextShortcuts = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)TextShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      self->editionTextShortcutsController = [[NSArrayController alloc] initWithContent:!editionTextShortcuts ? [NSArray array] : editionTextShortcuts];
    }
    [self->editionTextShortcutsController setAutomaticallyPreparesContent:NO];
    [self->editionTextShortcutsController setObjectClass:[NSMutableDictionary class]];
    result = self->editionTextShortcutsController;
  }//end if (!self->editionTextShortcutsController && creationOptionIfNeeded)
  return result;
}
//end lazyEditionTextShortcutsControllerWithCreationIfNeeded:

-(NSArray*) editionTextShortcutsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [[self lazyEditionTextShortcutsControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:TextShortcutsKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)TextShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)TextShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }
  return result;
}
//end editionTextShortcutsFromControllerIfPossible:createControllerIfNeeded:

-(PreamblesController*) lazyPreamblesControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  PreamblesController* result = self->preamblesController;
  if (!self->preamblesController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->preamblesController = [[PreamblesController alloc] initWithContent:nil];
      [self->preamblesController bind:NSContentArrayBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
        withKeyPath:[NSUserDefaultsController adaptedKeyPath:PreamblesKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:@(YES), NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* preambles =CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)PreamblesKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* preambles =[NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)PreamblesKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      self->preamblesController = [[PreamblesController alloc] initWithContent:!preambles ? [NSArray array] : preambles];
    }
    [self->preamblesController setPreservesSelection:YES];
    [self->preamblesController setAvoidsEmptySelection:YES];
    [self->preamblesController setAutomaticallyPreparesContent:NO];
    [self->preamblesController setObjectClass:[NSMutableDictionary class]];
    [self->preamblesController ensureDefaultPreamble];
    result = self->preamblesController;
  }//end if (!self->preamblesController && creationOptionIfNeeded)
  return result;
}
//end lazyPreamblesControllerWithCreationIfNeeded:

-(NSArray*) preamblesFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [[self lazyPreamblesControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:PreamblesKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)PreamblesKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)PreamblesKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }//end if (!result)
  return result;
}
//end preamblesFromControllerIfPossible:createControllerIfNeeded:

-(BodyTemplatesController*) lazyBodyTemplatesControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  BodyTemplatesController* result = self->bodyTemplatesController;
  if (!self->bodyTemplatesController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->bodyTemplatesController = [[BodyTemplatesController alloc] initWithContent:nil];
      [self->bodyTemplatesController bind:NSContentArrayBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
        withKeyPath:[NSUserDefaultsController adaptedKeyPath:BodyTemplatesKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:@(YES), NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* bodyTemplates = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)BodyTemplatesKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* bodyTemplates = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)BodyTemplatesKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      self->bodyTemplatesController = [[BodyTemplatesController alloc] initWithContent:!bodyTemplates ? [NSArray array] : bodyTemplates];
    }
    [self->bodyTemplatesController setPreservesSelection:YES];
    [self->bodyTemplatesController setAvoidsEmptySelection:YES];
    [self->bodyTemplatesController setAutomaticallyPreparesContent:NO];
    [self->bodyTemplatesController setObjectClass:[NSMutableDictionary class]];
    result = self->bodyTemplatesController;
  }//end if (!self->bodyTemplatesController && creationOptionIfNeeded)
  return result;
}
//end lazyBodyTemplatesControllerWithCreationIfNeeded:

-(NSArray*) bodyTemplatesFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [[self lazyBodyTemplatesControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:BodyTemplatesKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)BodyTemplatesKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)BodyTemplatesKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }
  return result;
}
//end bodyTemplatesFromControllerIfPossible:createControllerIfNeeded:

-(CompositionConfigurationsController*) lazyCompositionConfigurationsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  CompositionConfigurationsController* result = self->compositionConfigurationsController;
  if (!self->compositionConfigurationsController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->compositionConfigurationsController = [[CompositionConfigurationsController alloc] initWithContent:nil];
      [self->compositionConfigurationsController bind:NSContentArrayBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
        withKeyPath:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationsKey]
            options:[NSDictionary dictionaryWithObjectsAndKeys:@(YES), NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* compositionConfigurations = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)CompositionConfigurationsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* compositionConfigurations = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)CompositionConfigurationsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      self->compositionConfigurationsController = [[CompositionConfigurationsController alloc] initWithContent:!compositionConfigurations ? [NSArray array] : compositionConfigurations];
    }
    [self->compositionConfigurationsController setPreservesSelection:YES];
    [self->compositionConfigurationsController setAvoidsEmptySelection:YES];
    [self->compositionConfigurationsController setAutomaticallyPreparesContent:YES];
    [self->compositionConfigurationsController setObjectClass:[NSMutableDictionary class]];
    [self->compositionConfigurationsController ensureDefaultCompositionConfiguration];
    [self->compositionConfigurationsController bind:NSSelectionIndexesBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
      withKeyPath:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]
          options:[NSDictionary dictionaryWithObjectsAndKeys:[IndexToIndexesTransformer name], NSValueTransformerNameBindingOption, nil]];
    result = self->compositionConfigurationsController;
  }//end if (!self->compositionConfigurationsController && creationOptionIfNeeded)
  return result;
}
//end lazyCompositionConfigurationsControllerWithCreationIfNeeded:

-(NSArray*) compositionConfigurationsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [[self lazyCompositionConfigurationsControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:CompositionConfigurationsKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)CompositionConfigurationsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)CompositionConfigurationsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }
  return result;
}
//end compositionConfigurationsFromControllerIfPossible:createControllerIfNeeded:

-(NSArrayController*) lazyServiceShortcutsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  NSArrayController* result = self->serviceShortcutsController;
  if (!self->serviceShortcutsController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->serviceShortcutsController = [[NSArrayController alloc] initWithContent:nil];
      [self->serviceShortcutsController bind:NSContentArrayBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
        withKeyPath:[NSUserDefaultsController adaptedKeyPath:ServiceShortcutsKey]
            options:[NSDictionary dictionaryWithObjectsAndKeys:@(YES), NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* serviceShortcuts = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* serviceShortcuts = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      self->serviceShortcutsController = [[NSArrayController alloc] initWithContent:!serviceShortcuts ? [NSArray array] : serviceShortcuts];
    }
    [self->serviceShortcutsController setAutomaticallyPreparesContent:NO];
    [self->serviceShortcutsController setObjectClass:[NSMutableDictionary class]];
    result = self->serviceShortcutsController;
  }//end if (!self->serviceShortcutsController && creationOptionIfNeeded)
  return result;
}
//end lazyServiceShortcutsControllerWithCreationIfNeeded:

-(NSArray*) serviceShortcutsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [[self lazyServiceShortcutsControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:ServiceShortcutsKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }
  return result;
}
//end serviceShortcutsFromControllerIfPossible:createControllerIfNeeded:

-(ServiceRegularExpressionFiltersController*) lazyServiceRegularExpressionFiltersControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  ServiceRegularExpressionFiltersController* result = self->serviceRegularExpressionFiltersController;
  if (!self->serviceRegularExpressionFiltersController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->serviceRegularExpressionFiltersController = [[ServiceRegularExpressionFiltersController alloc] initWithContent:nil];
      [self->serviceRegularExpressionFiltersController bind:NSContentArrayBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
        withKeyPath:[NSUserDefaultsController adaptedKeyPath:ServiceRegularExpressionFiltersKey]
            options:[NSDictionary dictionaryWithObjectsAndKeys:@(YES), NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* serviceRegularExpressionFilters = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceRegularExpressionFiltersKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* serviceRegularExpressionFilters = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceRegularExpressionFiltersKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      self->serviceRegularExpressionFiltersController = [[ServiceRegularExpressionFiltersController alloc] initWithContent:!serviceRegularExpressionFilters ? [NSArray array] : serviceRegularExpressionFilters];
    }
    [self->serviceRegularExpressionFiltersController setAutomaticallyPreparesContent:NO];
    [self->serviceRegularExpressionFiltersController setObjectClass:[NSMutableDictionary class]];
    result = self->serviceRegularExpressionFiltersController;
  }//end if (!self->serviceRegularExpressionFiltersController && creationOptionIfNeeded)
  return result;
}
//end lazyServiceRegularExpressionFiltersControllerWithCreationIfNeeded:

-(NSArray*) serviceRegularExpressionFiltersFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [[self lazyServiceRegularExpressionFiltersControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:ServiceRegularExpressionFiltersKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceRegularExpressionFiltersKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceRegularExpressionFiltersKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }
  return result;
}
//end serviceRegularExpressionFiltersFromControllerIfPossible:createControllerIfNeeded:

-(AdditionalFilesController*) lazyAdditionalFilesControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  AdditionalFilesController* result = self->additionalFilesController;
  if (!self->additionalFilesController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->additionalFilesController = [[AdditionalFilesController alloc] initWithContent:nil];
      [self->additionalFilesController bind:NSContentArrayBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
        withKeyPath:[NSUserDefaultsController adaptedKeyPath:AdditionalFilesPathsKey] options:nil];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* additionalFilesPaths = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalFilesPathsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* additionalFilesPaths = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalFilesPathsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      self->additionalFilesController = [[AdditionalFilesController alloc] initWithContent:!additionalFilesPaths ? [NSArray array] : additionalFilesPaths];
    }
    [self->additionalFilesController setAutomaticallyPreparesContent:YES];
    [self->additionalFilesController setPreservesSelection:YES];
    result = self->additionalFilesController;
  }//end if (!self->additionalFilesController && creationOptionIfNeeded)
  return result;
}
//end lazyAdditionalFilesControllerWithCreationIfNeeded:

-(NSArray*) additionalFilesPathsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [[self lazyAdditionalFilesControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:AdditionalFilesPathsKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalFilesPathsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)AdditionalFilesPathsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }
  if (!result) result = [NSArray array];
  return result;
}
//end additionalFilesPathsFromControllerIfPossible:createControllerIfNeeded:

-(EncapsulationsController*) lazyEncapsulationsControllerWithCreationIfNeeded:(BOOL)creationOptionIfNeeded
{
  EncapsulationsController* result = self->encapsulationsController;
  if (!self->encapsulationsController && creationOptionIfNeeded)
  {
    if (self->isLaTeXiT)
    {
      self->encapsulationsController = [[EncapsulationsController alloc] initWithContent:nil];
      [self->encapsulationsController bind:NSContentArrayBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
        withKeyPath:[NSUserDefaultsController adaptedKeyPath:EncapsulationsKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:[MutableTransformer name], NSValueTransformerNameBindingOption,
                @(YES), NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* encapsulations = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)EncapsulationsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* encapsulations = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)EncapsulationsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
      self->encapsulationsController = [[EncapsulationsController alloc] initWithContent:!encapsulations ? [NSArray array] : encapsulations];
    }
    [self->encapsulationsController setAvoidsEmptySelection:YES];
    [self->encapsulationsController setAutomaticallyPreparesContent:YES];
    [self->encapsulationsController setPreservesSelection:YES];
    [self->encapsulationsController bind:NSSelectionIndexesBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
      withKeyPath:[NSUserDefaultsController adaptedKeyPath:CurrentEncapsulationIndexKey]
      options:[NSDictionary dictionaryWithObjectsAndKeys:[IndexToIndexesTransformer name], NSValueTransformerNameBindingOption, nil]];
    result = self->encapsulationsController;
  }//end if (!self->encapsulationsController && creationOptionIfNeeded)
  return result;
}
//end lazyEncapsulationsControllerWithCreationIfNeeded:

-(NSArray*) encapsulationsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [[self lazyEncapsulationsControllerWithCreationIfNeeded:createControllerIfNeeded] arrangedObjects];
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:EncapsulationsKey];
    else
      #ifdef ARC_ENABLED
      result = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)EncapsulationsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)EncapsulationsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }
  return result;
}
//end encapsulationsFromControllerIfPossible:createControllerIfNeeded:

-(BOOL) changeServiceShortcutsWithDiscrepancyFallback:(change_service_shortcuts_fallback_t)discrepancyFallback
                               authenticationFallback:(change_service_shortcuts_fallback_t)authenticationFallback
{
  BOOL ok = self->isLaTeXiT;
  if (ok)
  {
    NSURL* infoPlistURL =
      [[[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@"Contents"] URLByAppendingPathComponent:@"Info.plist"];
    CFPropertyListFormat format = kCFPropertyListBinaryFormat_v1_0;
    CFErrorRef cfError = nil;
    #ifdef ARC_ENABLED
    NSInputStream *stream = [[NSInputStream alloc] initWithURL:infoPlistURL];
    CFPropertyListRef cfInfoPlist = CFPropertyListCreateWithStream(kCFAllocatorDefault,
                                                                   (__bridge CFReadStreamRef)(stream), 0,
                                                                   kCFPropertyListMutableContainersAndLeaves, &format, &cfError);
    #else
    CFPropertyListRef cfInfoPlist = CFPropertyListCreateWithData(kCFAllocatorDefault,
                                                                 (CFDataRef)[NSData dataWithContentsOfURL:infoPlistURL],
                                                                 kCFPropertyListMutableContainersAndLeaves, &format, &cfError);
    #endif
    if (cfInfoPlist && !cfError)
    {
      //build services as found in info.plist
      #ifdef ARC_ENABLED
      NSMutableDictionary* infoPlist = (CHBRIDGE NSMutableDictionary*) cfInfoPlist;
      NSArray* currentServicesInInfoPlist = [[infoPlist objectForKey:@"NSServices"] mutableCopy];
      #else
      NSMutableDictionary* infoPlist = (NSMutableDictionary*) cfInfoPlist;
      NSArray* currentServicesInInfoPlist = [[[infoPlist objectForKey:@"NSServices"] mutableCopy] autorelease];
      #endif
      NSMutableDictionary* equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict =
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_ALIGN), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(NO), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_ALIGN),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_ALIGN_CLIPBOARD), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(YES), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_ALIGN_CLIPBOARD),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_EQNARRAY), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(NO), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_EQNARRAY),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_EQNARRAY_CLIPBOARD), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(YES), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_EQNARRAY_CLIPBOARD),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_DISPLAY), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(NO), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_DISPLAY),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(YES), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_INLINE), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(NO), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_INLINE),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_INLINE_CLIPBOARD), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(YES), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_INLINE_CLIPBOARD),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_TEXT), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(NO), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_TEXT),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_LATEXIZE_TEXT_CLIPBOARD), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(YES), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_LATEXIZE_TEXT_CLIPBOARD),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_MULTILATEXIZE), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(NO), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_MULTILATEXIZE),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_MULTILATEXIZE_CLIPBOARD), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @(YES), ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_MULTILATEXIZE_CLIPBOARD),
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @(SERVICE_DELATEXIZE), ServiceShortcutIdentifierKey,
            @(NO), ServiceShortcutEnabledKey,
            @"", ServiceShortcutStringKey,
            nil], @(SERVICE_DELATEXIZE),
          nil];

      NSMutableDictionary* identifiersByServiceName = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        @(SERVICE_LATEXIZE_ALIGN), @"serviceLatexisationAlign",
        @(SERVICE_LATEXIZE_ALIGN_CLIPBOARD), @"serviceLatexisationAlignAndPutIntoClipBoard",
        @(SERVICE_LATEXIZE_ALIGN), @"serviceLatexisationEqnarray",//redirection to Align on purpose for migration
        @(SERVICE_LATEXIZE_ALIGN_CLIPBOARD), @"serviceLatexisationEqnarrayAndPutIntoClipBoard",//redirection to Align on purpose for migration
        @(SERVICE_LATEXIZE_DISPLAY), @"serviceLatexisationDisplay",
        @(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD), @"serviceLatexisationDisplayAndPutIntoClipBoard",
        @(SERVICE_LATEXIZE_INLINE), @"serviceLatexisationInline",
        @(SERVICE_LATEXIZE_INLINE_CLIPBOARD), @"serviceLatexisationInlineAndPutIntoClipBoard",
        @(SERVICE_LATEXIZE_TEXT), @"serviceLatexisationText",
        @(SERVICE_LATEXIZE_TEXT_CLIPBOARD), @"serviceLatexisationTextAndPutIntoClipBoard",
        @(SERVICE_MULTILATEXIZE), @"serviceMultiLatexisation",
        @(SERVICE_MULTILATEXIZE_CLIPBOARD), @"serviceMultiLatexisationAndPutIntoClipBoard",
        @(SERVICE_DELATEXIZE), @"serviceDeLatexisation",
        nil];
      NSMutableDictionary* serviceNameByIdentifier = [NSMutableDictionary dictionaryWithCapacity:[identifiersByServiceName count]];
      NSEnumerator* enumerator = [[identifiersByServiceName allKeys] objectEnumerator];
      NSString* serviceName = nil;
      while((serviceName = [enumerator nextObject]))
        [serviceNameByIdentifier setObject:serviceName forKey:[identifiersByServiceName objectForKey:serviceName]];
      [serviceNameByIdentifier setObject:@"serviceLatexisationAlign" forKey:@(SERVICE_LATEXIZE_ALIGN)];
      [serviceNameByIdentifier setObject:@"serviceLatexisationAlignAndPutIntoClipBoard" forKey:@(SERVICE_LATEXIZE_ALIGN_CLIPBOARD)];

      enumerator = [currentServicesInInfoPlist objectEnumerator];
      NSDictionary* service = nil;
      BOOL didEncounterEqnarray = NO;
      while((service = [enumerator nextObject]))
      {
        NSString* message  = [service objectForKey:@"NSMessage"];
        NSString* shortcutDefault = [[service objectForKey:@"NSKeyEquivalent"] objectForKey:@"default"];
        NSString* shortcutWhenEnabled = [[service objectForKey:@"NSKeyEquivalent"] objectForKey:@"whenEnabled"];
        NSNumber* enabled = @(shortcutDefault && shortcutWhenEnabled && [shortcutDefault isEqualToString:shortcutWhenEnabled]);
        NSNumber* identifier = [identifiersByServiceName objectForKey:message];
        didEncounterEqnarray |= [message isEqualToString:@"serviceLatexisationEqnarray"] ||
                                [message isEqualToString:@"serviceLatexisationEqnarrayAndPutIntoClipBoard"];
        NSMutableDictionary* serviceEntry = !identifier ? nil : [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:identifier];
        [serviceEntry setObject:enabled forKey:ServiceShortcutEnabledKey];
        [serviceEntry setObject:(shortcutDefault ? shortcutDefault : @"") forKey:ServiceShortcutStringKey];
      }//end for each service of info.plist
      NSArray* equivalentUserDefaultsToCurrentServicesInInfoPlist =
        [NSArray arrayWithObjects:
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_LATEXIZE_ALIGN)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_LATEXIZE_ALIGN_CLIPBOARD)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_LATEXIZE_DISPLAY)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_LATEXIZE_INLINE)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_LATEXIZE_INLINE_CLIPBOARD)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_LATEXIZE_TEXT)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_LATEXIZE_TEXT_CLIPBOARD)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_MULTILATEXIZE)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_MULTILATEXIZE_CLIPBOARD)],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:@(SERVICE_DELATEXIZE)],
          nil];          

      //build services as found in user defaults
      NSMutableArray* equivalentServicesToCurrentUserDefaults = [NSMutableArray arrayWithCapacity:6];
      NSArray* standardReturnTypes = @[@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", (NSString*)kUTTypeRTFD,
                                       @"NSPasteboardTypePDF", @"NSPDFPboardType", (NSString*)kUTTypePDF,
                                       @"NSPostScriptPboardType", @"com.adobe.encapsulated-postscript",
                                       @"NSPasteboardTypeTIFF", @"NSTIFFPboardType", (NSString*)kUTTypeTIFF,
                                       @"NSPNGPboardType", (NSString*)kUTTypePNG,
                                       (NSString*)kUTTypeJPEG];
      NSArray* standardSendTypes = @[@"NSPasteboardTypeRTF", @"NSRTFPboardType", (NSString*)kUTTypeRTF,
                                     @"NSPasteboardTypePDF", @"NSPDFPboardType", (NSString*)kUTTypePDF,
                                     @"NSPasteboardTypeString", @"NSStringPboardType", @"public.utf8-plain-text"];
      NSArray* multiLatexisationReturnTypes = @[@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", (NSString*)kUTTypeRTFD];
      NSArray* multiLatexisationSendTypes = @[@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", (NSString*)kUTTypeRTFD,
                                              @"NSRTFPboardType", (NSString*)kUTTypeRTF];
      NSArray* deLatexisationReturnTypes = @[@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", (NSString*)kUTTypeRTFD,
                                             @"NSPasteboardTypePDF", @"NSPDFPboardType", (NSString*)kUTTypePDF,
                                             @"NSPasteboardTypeRTF", @"NSRTFPboardType", (NSString*)kUTTypeRTF];
      NSArray* deLatexisationSendTypes = @[@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", (NSString*)kUTTypeRTFD,
                                           @"NSPasteboardTypePDF", @"NSPDFPboardType", (NSString*)kUTTypePDF];
      NSDictionary* returnTypesByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        standardReturnTypes, @(SERVICE_LATEXIZE_ALIGN),
        standardReturnTypes, @(SERVICE_LATEXIZE_ALIGN_CLIPBOARD),
        standardReturnTypes, @(SERVICE_LATEXIZE_DISPLAY),
        standardReturnTypes, @(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD),
        standardReturnTypes, @(SERVICE_LATEXIZE_INLINE),
        standardReturnTypes, @(SERVICE_LATEXIZE_INLINE_CLIPBOARD),
        standardReturnTypes, @(SERVICE_LATEXIZE_TEXT),
        standardReturnTypes, @(SERVICE_LATEXIZE_TEXT_CLIPBOARD),
        multiLatexisationReturnTypes, @(SERVICE_MULTILATEXIZE),
        multiLatexisationReturnTypes, @(SERVICE_MULTILATEXIZE_CLIPBOARD),
        deLatexisationReturnTypes, @(SERVICE_DELATEXIZE),
        nil];
      NSDictionary* sendTypesByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        standardSendTypes, @(SERVICE_LATEXIZE_ALIGN),
        standardSendTypes, @(SERVICE_LATEXIZE_ALIGN_CLIPBOARD),
        standardSendTypes, @(SERVICE_LATEXIZE_DISPLAY),
        standardSendTypes, @(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD),
        standardSendTypes, @(SERVICE_LATEXIZE_INLINE),
        standardSendTypes, @(SERVICE_LATEXIZE_INLINE_CLIPBOARD),
        standardSendTypes, @(SERVICE_LATEXIZE_TEXT),
        standardSendTypes, @(SERVICE_LATEXIZE_TEXT_CLIPBOARD),
        multiLatexisationSendTypes, @(SERVICE_MULTILATEXIZE),
        multiLatexisationSendTypes, @(SERVICE_MULTILATEXIZE_CLIPBOARD),
        deLatexisationSendTypes, @(SERVICE_DELATEXIZE),
        nil];
      NSDictionary* serviceDescriptionsByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        @"SERVICE_DESCRIPTION_ALIGN", @(SERVICE_LATEXIZE_ALIGN),
        @"SERVICE_DESCRIPTION_ALIGN_CLIPBOARD", @(SERVICE_LATEXIZE_ALIGN_CLIPBOARD),
        @"SERVICE_DESCRIPTION_DISPLAY", @(SERVICE_LATEXIZE_DISPLAY),
        @"SERVICE_DESCRIPTION_DISPLAY_CLIPBOARD", @(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD),
        @"SERVICE_DESCRIPTION_INLINE", @(SERVICE_LATEXIZE_INLINE),
        @"SERVICE_DESCRIPTION_INLINE_CLIPBOARD", @(SERVICE_LATEXIZE_INLINE_CLIPBOARD),
        @"SERVICE_DESCRIPTION_TEXT", @(SERVICE_LATEXIZE_TEXT),
        @"SERVICE_DESCRIPTION_TEXT_CLIPBOARD", @(SERVICE_LATEXIZE_TEXT_CLIPBOARD),
        @"SERVICE_DESCRIPTION_MULTIPLE", @(SERVICE_MULTILATEXIZE),
        @"SERVICE_DESCRIPTION_MULTIPLE_CLIPBOARD", @(SERVICE_MULTILATEXIZE_CLIPBOARD),
        @"SERVICE_DESCRIPTION_DELATEXISATION", @(SERVICE_DELATEXIZE),
        nil];
      
      
      NSArray* currentServiceShortcuts = [self serviceShortcuts];
      enumerator = [currentServiceShortcuts objectEnumerator];
      service = nil;
      while((service = [enumerator nextObject]))
      {
        NSNumber* serviceIdentifier  = [service objectForKey:ServiceShortcutIdentifierKey];
        NSString* serviceTitle       = [self serviceDescriptionForIdentifier:(service_identifier_t)[serviceIdentifier integerValue]];
        NSString* menuItemName       = [@"LaTeXiT/" stringByAppendingString:serviceTitle];
        NSString* serviceMessage     = [serviceNameByIdentifier objectForKey:serviceIdentifier];
        NSString* shortcutString     = [service objectForKey:ServiceShortcutStringKey];
        BOOL      shortcutEnabled    = [[service objectForKey:ServiceShortcutEnabledKey] boolValue];
        NSArray*  returnTypes        = [returnTypesByServiceIdentifier objectForKey:serviceIdentifier];
        NSArray*  sendTypes          = [sendTypesByServiceIdentifier objectForKey:serviceIdentifier];
        NSString* serviceDescription = [NSString stringWithFormat:@"%@\n%@",
                                          @"SERVICE_DESCRIPTION",
                                          [serviceDescriptionsByServiceIdentifier objectForKey:serviceIdentifier]];

        NSDictionary* serviceItemPlist =
          [NSDictionary dictionaryWithObjectsAndKeys:
            [NSDictionary dictionaryWithObjectsAndKeys:
              (!shortcutEnabled ? @"" : shortcutString), @"default",
              !shortcutEnabled ? nil : shortcutString, !shortcutEnabled ? nil : @"whenEnabled",
              nil], @"NSKeyEquivalent",
            [NSDictionary dictionaryWithObjectsAndKeys:menuItemName, @"default", nil], @"NSMenuItem",
            !serviceMessage ? @"" : serviceMessage, @"NSMessage",
            @"LaTeXiT", @"NSPortName",
            !serviceDescription ? @"" : serviceDescription, @"NSServiceDescription",
            !returnTypes ? [NSArray array] : returnTypes, @"NSReturnTypes",
            !sendTypes ? [NSArray array] : sendTypes, @"NSSendTypes",
            [@(30000) stringValue], @"NSTimeOut",
            [NSDictionary dictionary], @"NSRequiredContext",
            nil];
          [equivalentServicesToCurrentUserDefaults addObject:serviceItemPlist];
      }//end for each service from user preferences

      if (didEncounterEqnarray || ![equivalentUserDefaultsToCurrentServicesInInfoPlist isEqualToArray:currentServiceShortcuts])
      {
        if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK)
        {
          NSAlert* alert = [[NSAlert alloc] init];
          alert.messageText = NSLocalizedString(@"The current Service shortcuts of LaTeXiT do not match the ones defined in the preferences", @"");
          [alert addButtonWithTitle:NSLocalizedString(@"Apply preferences", @"")];
          [alert addButtonWithTitle:NSLocalizedString(@"Update preferences", @"")];
          [alert addButtonWithTitle:NSLocalizedString(@"Ignore", @"")];
          alert.informativeText = NSLocalizedString(@"__EXPLAIN_CHANGE_SHORTCUTS__", @"");
          [[[alert buttons] objectAtIndex:2] setKeyEquivalent:[NSString stringWithFormat:@"%c", '\033']];//escape
          NSInteger result = [alert runModal];
#ifndef ARC_ENABLED
          [alert release];
#endif
          if (result == NSAlertFirstButtonReturn)
            discrepancyFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS;
          else if (result == NSAlertSecondButtonReturn)
            discrepancyFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS;
          else if (result == NSAlertThirdButtonReturn)
            discrepancyFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE;
        }
        if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE)
          ok = NO;
        else if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS)
        {
          [self setServiceShortcuts:equivalentUserDefaultsToCurrentServicesInInfoPlist];
          NSUpdateDynamicServices();
          ok = YES;
        }
        else if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS)
        {
          [infoPlist setObject:equivalentServicesToCurrentUserDefaults forKey:@"NSServices"];
          ok = [infoPlist writeToURL:infoPlistURL atomically:YES];
          if (!ok)
          {
            AuthorizationRef myAuthorizationRef = 0;
            OSStatus myStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment,
                                                    kAuthorizationFlagDefaults, &myAuthorizationRef);
            AuthorizationItem myItems[1] = {{0}};
            myItems[0].name = kAuthorizationRightExecute;
            myItems[0].valueLength = 0;
            myItems[0].value = NULL;
            myItems[0].flags = 0;
            AuthorizationRights myRights = {0};
            myRights.count = sizeof(myItems) / sizeof(myItems[0]);
            myRights.items = myItems;
            AuthorizationFlags myFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
                                         kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize;
            myStatus = myStatus ? myStatus : AuthorizationCopyRights(myAuthorizationRef, &myRights,
                                                                     kAuthorizationEmptyEnvironment, myFlags, NULL);
            NSString* src = nil;
            [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-info.XXXXXXXX" extension:@"plist" outFilePath:&src
                                                     workingDirectory:[[NSWorkspace sharedWorkspace] temporaryDirectory]];
            NSString* dst = [infoPlistURL path];
            if (!myStatus && src && dst && [infoPlist writeToFile:src atomically:YES])
            {
              NSString* systemCall = [NSString stringWithFormat:@"cat \"%@\" | /usr/libexec/authopen -w \"%@\"", src, dst];
              int status = system([systemCall UTF8String]);
              DebugLog(1, @"<%@> =>%d", systemCall, status);
              //const char* args[] = {[src UTF8String], [dst UTF8String], NULL};
              //myStatus = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/cp", kAuthorizationFlagDefaults, (char**)args, NULL);
            }
            if (src)
              [[NSFileManager defaultManager] removeItemAtPath:src error:0];
            if (myAuthorizationRef != 0)
              AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDestroyRights);
            ok = (myStatus == 0);
          }//end if (!ok)
          if (ok)
             NSUpdateDynamicServices();
          else
          {
            if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK)
            {
              NSAlert* alert = [[NSAlert alloc] init];
              alert.messageText = NSLocalizedString(@"New Service shortcuts could not be set", @"");
              alert.informativeText = NSLocalizedString(@"Authentication failed or did not allow to rewrite the <Info.plist> file inside the LaTeXiT.app bundle", @"");
              [alert addButtonWithTitle:NSLocalizedString(@"Update preferences", @"")];
              [alert addButtonWithTitle:NSLocalizedString(@"Ignore", @"")];
              [[alert.buttons objectAtIndex:1] setKeyEquivalent:[NSString stringWithFormat:@"%c",'\033']];
              NSInteger result = [alert runModal];
#ifndef ARC_ENABLED
          [alert release];
#endif
              if (result == NSAlertFirstButtonReturn)
                 authenticationFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS;
              else
                 authenticationFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE;
            }//end if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK)
            if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE)
              ok = NO;
            else if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS)
            {
              [self setServiceShortcuts:equivalentUserDefaultsToCurrentServicesInInfoPlist];
              NSUpdateDynamicServices();
              ok = YES;
            }//end if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS)
          }//end if (authentication did not help writing)
        }//end if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS)
      }//end if (![currentServicesInInfoPlist iEqualTo:equivalentServicesToCurrentUserDefaults])
    }//end if (cfInfoPlist && !cfError)
    if (cfInfoPlist)
      CFRelease(cfInfoPlist);
    if (cfError)
      CFRelease(cfError);
  }//end if (ok)  
  return ok;
}
//end changeServiceShortcutsWithDiscrepancyFallback:authenticationFallback:

@end
