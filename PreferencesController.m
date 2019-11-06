//
//  PreferencesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/03/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
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

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

static PreferencesController* sharedInstance = nil;

NSString*const LaTeXiTAppKey = @"fr.chachatelier.pierre.LaTeXiT";
NSString*const Old_LaTeXiTAppKey = @"fr.club.ktd.LaTeXiT";

NSString*const LaTeXiTVersionKey = @"version";

NSString*const DocumentStyleKey = @"DocumentStyle";

NSString*const DragExportTypeKey                                   = @"DragExportType";
NSString*const DragExportJpegColorKey                              = @"DragExportJpegColor";
NSString*const DragExportJpegQualityKey                            = @"DragExportJpegQuality";
NSString*const DragExportPDFMetadataInvisibleGraphicsEnabledKey    = @"DragExportPDFMetadataInvisibleGraphicsEnabled";
NSString*const DragExportPDFWOFGsWriteEngineKey                    = @"DragExportPDFWOFGsWriteEngine";
NSString*const DragExportPDFWOFGsPDFCompatibilityLevelKey          = @"DragExportPDFWOFGsPDFCompatibilityLevel";
NSString*const DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey = @"DragExportPDFWOFMetadataInvisibleGraphicsEnabled";
NSString*const DragExportSvgPdfToSvgPathKey                        = @"DragExportSvgPdfToSvgPath";
NSString*const DragExportTextExportPreambleKey                     = @"DragExportTextExportPreambleKey";
NSString*const DragExportTextExportEnvironmentKey                  = @"DragExportTextExportEnvironmentKey";
NSString*const DragExportTextExportBodyKey                         = @"DragExportTextExportBodyKey";
NSString*const DragExportScaleAsPercentKey                         = @"DragExportScaleAsPercent";
NSString*const DragExportIncludeBackgroundColorKey                 = @"DragExportIncludeBackgroundColor";
NSString*const DragExportAddTempFileEnabledKey                     = @"DragExportAddTempFileEnabled";

NSString*const DefaultImageViewBackgroundKey                      = @"DefaultImageViewBackground";
NSString*const DefaultAutomaticHighContrastedPreviewBackgroundKey = @"DefaultAutomaticHighContrastedPreviewBackground";
NSString*const DefaultDoNotClipPreviewKey                         = @"DefaultDoNotClipPreview";
NSString*const DefaultColorKey                                    = @"DefaultColor";
NSString*const DefaultPointSizeKey                                = @"DefaultPointSize";
NSString*const DefaultModeKey                                     = @"DefaultMode";

NSString*const SpellCheckingEnableKey               = @"SpellCheckingEnabled";
NSString*const SyntaxColoringEnableKey              = @"SyntaxColoringEnabled";
NSString*const SyntaxColoringTextForegroundColorKey = @"SyntaxColoringTextForegroundColor";
NSString*const SyntaxColoringTextForegroundColorDarkModeKey = @"SyntaxColoringTextForegroundColorDarkMode";
NSString*const SyntaxColoringTextBackgroundColorKey = @"SyntaxColoringTextBackgroundColor";
NSString*const SyntaxColoringTextBackgroundColorDarkModeKey = @"SyntaxColoringTextBackgroundColorDarkMode";
NSString*const SyntaxColoringCommandColorKey        = @"SyntaxColoringCommandColor";
NSString*const SyntaxColoringCommandColorDarkModeKey        = @"SyntaxColoringCommandColorDarkMode";
NSString*const SyntaxColoringMathsColorKey          = @"SyntaxColoringMathsColor";
NSString*const SyntaxColoringMathsColorDarkModeKey          = @"SyntaxColoringMathsColorDarkMode";
NSString*const SyntaxColoringKeywordColorKey        = @"SyntaxColoringKeywordColor";
NSString*const SyntaxColoringKeywordColorDarkModeKey        = @"SyntaxColoringKeywordColorDarkMode";
NSString*const SyntaxColoringCommentColorKey        = @"SyntaxColoringCommentColor";
NSString*const SyntaxColoringCommentColorDarkModeKey        = @"SyntaxColoringCommentColorDarkMode";
NSString*const ReducedTextAreaStateKey              = @"ReducedTextAreaState";

NSString*const DefaultFontKey               = @"DefaultFont";
NSString*const PreamblesKey                         = @"Preambles";
NSString*const LatexisationSelectedPreambleIndexKey = @"LatexisationSelectedPreambleIndex";
NSString*const BodyTemplatesKey                         = @"BodyTemplates";
NSString*const LatexisationSelectedBodyTemplateIndexKey = @"LatexisationSelectedBodyTemplateIndexKey";

NSString*const ServiceSelectedPreambleIndexKey     = @"ServiceSelectedPreambleIndex";
NSString*const ServiceSelectedBodyTemplateIndexKey = @"ServiceSelectedBodyTemplateIndexKey";
NSString*const ServiceShortcutsKey                 = @"ServiceShortcuts";
NSString*const ServiceShortcutEnabledKey           = @"enabled";
NSString*const ServiceShortcutClipBoardOptionKey   = @"clipBoardOption";
NSString*const ServiceShortcutStringKey            = @"string";
NSString*const ServiceShortcutIdentifierKey        = @"identifier";

NSString*const ServiceRespectsBaselineKey      = @"ServiceRespectsBaseline";
NSString*const ServiceRespectsPointSizeKey     = @"ServiceRespectsPointSize";
NSString*const ServicePointSizeFactorKey       = @"ServicePointSizeFactor";
NSString*const ServiceRespectsColorKey         = @"ServiceRespectsColor";
NSString*const ServiceUsesHistoryKey           = @"ServiceUsesHistory";
NSString*const ServiceRegularExpressionFiltersKey         = @"ServiceRegularExpressionFilters";
NSString*const ServiceRegularExpressionFilterEnabledKey   = @"ServiceRegularExpressionFilterEnabled";
NSString*const ServiceRegularExpressionFilterInputPatternKey     = @"ServiceRegularExpressionFilterInputPattern";
NSString*const ServiceRegularExpressionFilterOutputPatternKey    = @"ServiceRegularExpressionFilterOutputPattern";

NSString*const AdditionalTopMarginKey          = @"AdditionalTopMargin";
NSString*const AdditionalLeftMarginKey         = @"AdditionalLeftMargin";
NSString*const AdditionalRightMarginKey        = @"AdditionalRightMargin";
NSString*const AdditionalBottomMarginKey       = @"AdditionalBottomMargin";
NSString*const EncapsulationsEnabledKey        = @"EncapsulationsEnabled";
NSString*const EncapsulationsKey               = @"Encapsulations";
NSString*const CurrentEncapsulationIndexKey    = @"CurrentEncapsulationIndex";
NSString*const TextShortcutsKey                = @"TextShortcuts";

NSString*const EditionTabKeyInsertsSpacesEnabledKey = @"EditionTabKeyInsertsSpacesEnabled";
NSString*const EditionTabKeyInsertsSpacesCountKey   = @"EditionTabKeyInsertsSpacesCount";
NSString*const EditionAutoCompleteOnBackslashEnabledKey = @"EditionAutoCompleteOnBackslashEnabled";

NSString*const CompositionConfigurationsKey             = @"CompositionConfigurations";
NSString*const CompositionConfigurationDocumentIndexKey = @"CompositionConfigurationDocumentIndexKey";

NSString*const HistoryDeleteOldEntriesEnabledKey = @"HistoryDeleteOldEntriesEnabled";
NSString*const HistoryDeleteOldEntriesLimitKey   = @"HistoryDeleteOldEntriesLimit";
NSString*const HistorySmartEnabledKey            = @"HistorySmartEnabled";

NSString*const LastEasterEggsDatesKey       = @"LastEasterEggsDates";

NSString*const CompositionConfigurationsControllerVisibleAtStartupKey = @"CompositionConfigurationsControllerVisibleAtStartup";
NSString*const EncapsulationsControllerVisibleAtStartupKey = @"EncapsulationsControllerVisibleAtStartup";
NSString*const HistoryControllerVisibleAtStartupKey       = @"HistoryControllerVisibleAtStartup";
NSString*const LatexPalettesControllerVisibleAtStartupKey = @"LatexPalettesControllerVisibleAtStartup";
NSString*const LibraryControllerVisibleAtStartupKey       = @"LibraryControllerVisibleAtStartup";
NSString*const MarginControllerVisibleAtStartupKey        = @"MarginControllerVisibleAtStartup";
NSString*const AdditionalFilesWindowControllerVisibleAtStartupKey = @"AdditionalFilesWindowControllerVisibleAtStartup";

NSString*const LibraryPathKey                = @"LibraryPath";
NSString*const LibraryViewRowTypeKey         = @"LibraryViewRowType";
NSString*const LibraryDisplayPreviewPanelKey = @"LibraryDisplayPreviewPanel";
NSString*const HistoryDisplayPreviewPanelKey = @"HistoryDisplayPreviewPanel";

NSString*const LatexPaletteGroupKey        = @"LatexPaletteGroup";
NSString*const LatexPaletteFrameKey        = @"LatexPaletteFrame";
NSString*const LatexPaletteDetailsStateKey = @"LatexPaletteDetailsState";

NSString*const ShowWhiteColorWarningKey       = @"ShowWhiteColorWarning";

NSString* const CompositionModeDidChangeNotification = @"CompositionModeDidChangeNotification";
NSString* const CurrentCompositionConfigurationDidChangeNotification = @"CurrentCompositionConfigurationDidChangeNotification";

NSString*const CompositionConfigurationNameKey                        = @"name";
NSString*const CompositionConfigurationIsDefaultKey                   = @"isDefault";
NSString*const CompositionConfigurationCompositionModeKey             = @"compositionMode";
NSString*const CompositionConfigurationUseLoginShellKey               = @"useLoginShell";
NSString*const CompositionConfigurationPdfLatexPathKey                = @"pdfLatexPath";
NSString*const CompositionConfigurationPsToPdfPathKey                 = @"psToPdfPath";
NSString*const CompositionConfigurationXeLatexPathKey                 = @"xeLatexPath";
NSString*const CompositionConfigurationLuaLatexPathKey                = @"luaLatexPath";
NSString*const CompositionConfigurationLatexPathKey                   = @"latexPath";
NSString*const CompositionConfigurationDviPdfPathKey                  = @"dviPdfPath";
NSString*const CompositionConfigurationGsPathKey                      = @"gsPath";
NSString*const CompositionConfigurationProgramArgumentsKey            = @"programArguments";
NSString*const CompositionConfigurationAdditionalProcessingScriptsKey = @"additionalProcessingScripts";
NSString*const CompositionConfigurationAdditionalProcessingScriptEnabledKey = @"enabled";
NSString*const CompositionConfigurationAdditionalProcessingScriptTypeKey    = @"sourceType";
NSString*const CompositionConfigurationAdditionalProcessingScriptPathKey    = @"file";
NSString*const CompositionConfigurationAdditionalProcessingScriptShellKey   = @"shell";
NSString*const CompositionConfigurationAdditionalProcessingScriptContentKey = @"body";

NSString*const AdditionalFilesPathsKey = @"AdditionalFilesPaths";

NSString*const SynchronizationNewDocumentsEnabledKey = @"SynchronizationNewDocumentsEnabled";
NSString*const SynchronizationNewDocumentsSynchronizePreambleKey = @"SynchronizationNewDocumentsSynchronizePreamble";
NSString*const SynchronizationNewDocumentsSynchronizeEnvironmentKey = @"SynchronizationNewDocumentsSynchronizeEnvironment";
NSString*const SynchronizationNewDocumentsSynchronizeBodyKey = @"SynchronizationNewDocumentsSynchronizeBody";
NSString*const SynchronizationNewDocumentsPathKey = @"SynchronizationNewDocumentsPath";
NSString*const SynchronizationAdditionalScriptsKey = @"SynchronizationAdditionalScripts";

@interface PreferencesController ()
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
  result = [(__bridge NSString*)identifier isEqualToString:LaTeXiTAppKey];
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
        NSError* errorString = nil;
        NSDictionary* plist = [NSPropertyListSerialization propertyListWithData:dataTextShortcutsPlist
                                                                        options:NSPropertyListImmutable
                                                                         format:&format error:&errorString];
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
             [NSNumber numberWithInteger:DOCUMENT_STYLE_NORMAL], DocumentStyleKey,
             [NSNumber numberWithInteger:EXPORT_FORMAT_PDF], DragExportTypeKey,
             [[NSColor whiteColor] colorAsData],      DragExportJpegColorKey,
             [NSNumber numberWithFloat:100],   DragExportJpegQualityKey,
             @"pdfwrite", DragExportPDFWOFGsWriteEngineKey,
             @"1.5", DragExportPDFWOFGsPDFCompatibilityLevelKey,
             @"", DragExportSvgPdfToSvgPathKey,
             [NSNumber numberWithBool:YES], DragExportPDFMetadataInvisibleGraphicsEnabledKey,
             [NSNumber numberWithBool:YES], DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey,
             [NSNumber numberWithBool:YES], DragExportTextExportPreambleKey,
             [NSNumber numberWithBool:YES], DragExportTextExportEnvironmentKey,
             [NSNumber numberWithBool:YES], DragExportTextExportBodyKey,
             [NSNumber numberWithFloat:100],   DragExportScaleAsPercentKey,
             [NSNumber numberWithBool:NO], DragExportIncludeBackgroundColorKey,
             [NSNumber numberWithBool:NO], DragExportAddTempFileEnabledKey,
             [[NSColor whiteColor] colorAsData],      DefaultImageViewBackgroundKey,
             [NSNumber numberWithBool:NO],     DefaultAutomaticHighContrastedPreviewBackgroundKey,
             [NSNumber numberWithBool:NO],     DefaultDoNotClipPreviewKey,
             [[NSColor  blackColor]   colorAsData],   DefaultColorKey,
             [NSNumber numberWithDouble:36.0], DefaultPointSizeKey,
             [NSNumber numberWithInteger:LATEX_MODE_ALIGN], DefaultModeKey,
             [NSNumber numberWithBool:YES], SpellCheckingEnableKey,
             [NSNumber numberWithBool:YES], SyntaxColoringEnableKey,
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
             [NSNumber numberWithBool:YES], EditionTabKeyInsertsSpacesEnabledKey,
             [NSNumber numberWithUnsignedInteger:2], EditionTabKeyInsertsSpacesCountKey,
             [NSNumber numberWithBool:NO], EditionAutoCompleteOnBackslashEnabledKey,
             [NSNumber numberWithInteger:NSOffState], ReducedTextAreaStateKey,
             [[NSFont fontWithName:@"Monaco" size:12] data], DefaultFontKey,
             factoryDefaultsPreambles, PreamblesKey,
             factoryDefaultsBodyTemplates, BodyTemplatesKey,
             [NSNumber numberWithUnsignedInteger:0], LatexisationSelectedPreambleIndexKey,
             [NSNumber numberWithUnsignedInteger:0], ServiceSelectedPreambleIndexKey,
             [NSNumber numberWithInteger:-1], LatexisationSelectedBodyTemplateIndexKey,//none
             [NSNumber numberWithInteger:-1], ServiceSelectedBodyTemplateIndexKey,//none
             [NSArray arrayWithObjects:
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN_CLIPBOARD], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE_CLIPBOARD], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT_CLIPBOARD], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                 [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE_CLIPBOARD], ServiceShortcutIdentifierKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                 @"", ServiceShortcutStringKey,
                 [NSNumber numberWithInteger:SERVICE_DELATEXIZE], ServiceShortcutIdentifierKey,
                 nil],
              nil], ServiceShortcutsKey,
            [NSArray arrayWithObjects:
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:NO], ServiceRegularExpressionFilterEnabledKey,
                 @"<latex-align>(.*)</latex-align>", ServiceRegularExpressionFilterInputPatternKey,
                 @"\\\\begin\\{align\\*\\}$1\\\\end\\{align\\*\\}", ServiceRegularExpressionFilterOutputPatternKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:NO], ServiceRegularExpressionFilterEnabledKey,
                 @"<latex-display>(.*)</latex-display>", ServiceRegularExpressionFilterInputPatternKey,
                 @"\\\\[$1\\\\]", ServiceRegularExpressionFilterOutputPatternKey,
                 nil],
               [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithBool:NO], ServiceRegularExpressionFilterEnabledKey,
                 @"<latex-inline>(.*)</latex-inline>", ServiceRegularExpressionFilterInputPatternKey,
                 @"$$1$", ServiceRegularExpressionFilterOutputPatternKey,
                 nil],
              nil], ServiceRegularExpressionFiltersKey,
             [NSNumber numberWithBool:YES], ServiceRespectsBaselineKey,
             [NSNumber numberWithBool:YES], ServiceRespectsPointSizeKey,
             [NSNumber numberWithDouble:1.0], ServicePointSizeFactorKey,
             [NSNumber numberWithBool:YES], ServiceRespectsColorKey,
             [NSNumber numberWithBool:NO], ServiceUsesHistoryKey,
             [NSNumber numberWithFloat:0], AdditionalTopMarginKey,
             [NSNumber numberWithFloat:0], AdditionalLeftMarginKey,
             [NSNumber numberWithFloat:0], AdditionalRightMarginKey,
             [NSNumber numberWithFloat:0], AdditionalBottomMarginKey,
             [NSNumber numberWithBool:YES], EncapsulationsEnabledKey,
             [NSArray arrayWithObjects:@"@", @"#", @"\\label{@}", @"\\ref{@}", @"$#$",
                                       @"\\[#\\]", @"\\begin{equation}#\\label{@}\\end{equation}",
                                       nil], EncapsulationsKey,
             [NSNumber numberWithUnsignedInteger:0], CurrentEncapsulationIndexKey,
             defaultTextShortcuts, TextShortcutsKey,
             [NSArray arrayWithObjects:[CompositionConfigurationsController defaultCompositionConfigurationDictionary], nil],
               CompositionConfigurationsKey,
             [NSNumber numberWithUnsignedInteger:0], CompositionConfigurationDocumentIndexKey,
             [NSNumber numberWithBool:NO], CompositionConfigurationsControllerVisibleAtStartupKey,
             [NSNumber numberWithBool:NO], HistoryDeleteOldEntriesEnabledKey,
             [NSNumber numberWithInteger:30], HistoryDeleteOldEntriesLimitKey,
             [NSNumber numberWithBool:NO], HistorySmartEnabledKey,
             [NSNumber numberWithBool:NO], EncapsulationsControllerVisibleAtStartupKey,
             [NSNumber numberWithBool:NO], HistoryControllerVisibleAtStartupKey,
             [NSNumber numberWithBool:NO], LatexPalettesControllerVisibleAtStartupKey,
             [NSNumber numberWithBool:NO], LibraryControllerVisibleAtStartupKey,
             [NSNumber numberWithBool:NO], MarginControllerVisibleAtStartupKey,
             [NSNumber numberWithInteger:LIBRARY_ROW_IMAGE_AND_TEXT], LibraryViewRowTypeKey,
             [NSNumber numberWithBool:YES], LibraryDisplayPreviewPanelKey,
             [NSNumber numberWithBool:NO], HistoryDisplayPreviewPanelKey,
             [NSNumber numberWithInteger:0], LatexPaletteGroupKey,
             NSStringFromRect(NSMakeRect(235, 624, 200, 170)), LatexPaletteFrameKey,
             [NSNumber numberWithBool:NO], LatexPaletteDetailsStateKey,
             [NSNumber numberWithBool:YES], ShowWhiteColorWarningKey,
             [NSNumber numberWithBool:NO], SynchronizationNewDocumentsEnabledKey,
             [NSNumber numberWithBool:YES], SynchronizationNewDocumentsSynchronizePreambleKey,
             [NSNumber numberWithBool:YES], SynchronizationNewDocumentsSynchronizeEnvironmentKey,
             [NSNumber numberWithBool:YES], SynchronizationNewDocumentsSynchronizeBodyKey,
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
          exportFormat = [NSNumber numberWithInteger:EXPORT_FORMAT_PDF];
        else if ([exportFormat isEqualToString:@"eps"])
          exportFormat = [NSNumber numberWithInteger:EXPORT_FORMAT_EPS];
        else if ([exportFormat isEqualToString:@"tiff"])
          exportFormat = [NSNumber numberWithInteger:EXPORT_FORMAT_TIFF];
        else if ([exportFormat isEqualToString:@"png"])
          exportFormat = [NSNumber numberWithInteger:EXPORT_FORMAT_PNG];
        else if ([exportFormat isEqualToString:@"jpeg"])
          exportFormat = [NSNumber numberWithInteger:EXPORT_FORMAT_JPEG];
        else if ([exportFormat isEqualToString:@"svg"])
          exportFormat = [NSNumber numberWithInteger:EXPORT_FORMAT_SVG];
        else if ([exportFormat isEqualToString:@"text"])
          exportFormat = [NSNumber numberWithInteger:EXPORT_FORMAT_TEXT];
        else
          exportFormat = [NSNumber numberWithInteger:EXPORT_FORMAT_PDF];
        [userDefaults setObject:exportFormat forKey:DragExportTypeKey];
      }//end if ([exportFormat isKindOfClass:[NSString class]])
    }//end if (!initialized)
  }//end @synchronized(self)
}
//end initialize

-(instancetype) init
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CFStringRef)LaTeXiTVersionKey, (CFStringRef)LaTeXiTAppKey));
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
    result = (export_format_t)CFPreferencesGetAppIntegerValue((CFStringRef)DragExportTypeKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
    CFPreferencesSetAppValue((CFStringRef)DragExportTypeKey, (__bridge CFNumberRef)@(value), (CFStringRef)LaTeXiTAppKey);
  self.exportFormatCurrentSession = value;
}
//end setExportFormatPersistent:

@synthesize exportFormatCurrentSession;

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
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportAddTempFileEnabledKey, (CHBRIDGE const void*)[NSNumber numberWithBool:value], (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportAddTempFileEnabledKey, [NSNumber numberWithBool:value], (CHBRIDGE CFStringRef)LaTeXiTAppKey);
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

@synthesize exportAddTempFileCurrentSession;

-(NSData*) exportJpegBackgroundColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:DragExportJpegColorKey];
  else
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportJpegColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end exportJpegBackgroundColorData

-(void) setExportJpegBackgroundColorData:(NSData*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportJpegColorKey];
  else
    CFPreferencesSetAppValue((CFStringRef)DragExportJpegColorKey, (__bridge CFPropertyListRef)value, (CFStringRef)LaTeXiTAppKey);
}
//end setExportJpegBackgroundColorData:

-(NSColor*) exportJpegBackgroundColor
{
  NSColor* result = [NSColor colorWithData:self.exportJpegBackgroundColorData];
  return result;
}
//end exportJpegBackgroundColor

-(void) setExportJpegBackgroundColor:(NSColor*)value
{
  self.exportJpegBackgroundColorData = [value colorAsData];
}
//end setExportJpegBackgroundColor:

-(float) exportJpegQualityPercent
{
  float result = 0;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportJpegQualityKey];
  else
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportJpegQualityKey, (__bridge CFStringRef)LaTeXiTAppKey));
  result = !number ? 100. : number.floatValue;
  return result;
}
//end exportJpegQualityPercent

-(void) setExportJpegQualityPercent:(float)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportJpegQualityKey];
  else
    CFPreferencesSetAppValue((CFStringRef)DragExportJpegQualityKey, (__bridge CFPropertyListRef)@(value), (CFStringRef)LaTeXiTAppKey);
}
//end setExportJpegQualityPercent:

-(NSString*) exportPDFWOFGsWriteEngine
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:DragExportPDFWOFGsWriteEngineKey];
  else
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportPDFWOFGsWriteEngineKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end exportPDFWOFGsWriteEngine

-(void) setExportPDFWOFGsWriteEngine:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportPDFWOFGsWriteEngineKey];
  else
    CFPreferencesSetAppValue((CFStringRef)DragExportPDFWOFGsWriteEngineKey, (__bridge CFPropertyListRef)value, (CFStringRef)LaTeXiTAppKey);
}
//end setExportPDFWOFGsWriteEngine:

-(NSString*) exportPDFWOFGsPDFCompatibilityLevel
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:DragExportPDFWOFGsPDFCompatibilityLevelKey];
  else
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportPDFWOFGsPDFCompatibilityLevelKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end exportPDFWOFGsPDFCompatibilityLevel

-(void) setExportPDFWOFGsPDFCompatibilityLevel:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportPDFWOFGsPDFCompatibilityLevelKey];
  else
    CFPreferencesSetAppValue((CFStringRef)DragExportPDFWOFGsPDFCompatibilityLevelKey, (__bridge CFPropertyListRef)value, (CFStringRef)LaTeXiTAppKey);
}
//end setExportPDFWOFGsPDFCompatibilityLevel:

-(BOOL) exportPDFWOFMetaDataInvisibleGraphicsEnabled
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey];
  else
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey, (__bridge CFStringRef)LaTeXiTAppKey));
  result = !number ? NO : number.boolValue;
  return result;
}
//end exportPDFWOFMetaDataInvisibleGraphicsEnabled

-(void) setExportPDFWOFMetaDataInvisibleGraphicsEnabled:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey];
  else
    CFPreferencesSetAppValue((CFStringRef)DragExportPDFWOFMetadataInvisibleGraphicsEnabledKey, (__bridge CFPropertyListRef)@(value), (CFStringRef)LaTeXiTAppKey);
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
    number = (CHBRIDGE NSNumber*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)DragExportPDFMetadataInvisibleGraphicsEnabledKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
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
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFMetadataInvisibleGraphicsEnabledKey, (CHBRIDGE const void*)[NSNumber numberWithBool:value], (CHBRIDGE CFStringRef)LaTeXiTAppKey);
  #else
  CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportPDFMetadataInvisibleGraphicsEnabledKey, [NSNumber numberWithBool:value], (CHBRIDGE CFStringRef)LaTeXiTAppKey);
  #endif
}
//end setExportPDFMetaDataInvisibleGraphicsEnabled:

-(NSString*) exportSvgPdfToSvgPath
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:DragExportSvgPdfToSvgPathKey];
  else
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportSvgPdfToSvgPathKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end exportSvgPdfToSvgPath

-(void) setExportSvgPdfToSvgPath:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DragExportSvgPdfToSvgPathKey];
  else
    CFPreferencesSetAppValue((CFStringRef)DragExportSvgPdfToSvgPathKey, (__bridge const void*)value, (CFStringRef)LaTeXiTAppKey);
}
//end setExportSvgPdfToSvgPath:

-(BOOL) exportTextExportPreamble
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportTextExportPreambleKey];
  else
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportTextExportPreambleKey, (__bridge CFStringRef)LaTeXiTAppKey));
  result = !number ? NO : number.boolValue;
  return result;
}
//end exportTextExportPreamble

-(void) setExportTextExportPreamble:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportTextExportPreambleKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportTextExportPreambleKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setExportTextExportPreamble:

-(BOOL) exportTextExportEnvironment
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportTextExportEnvironmentKey];
  else
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportTextExportEnvironmentKey, (__bridge CFStringRef)LaTeXiTAppKey));
  result = !number ? NO : number.boolValue;
  return result;
}
//end exportTextExportEnvironment

-(void) setExportTextExportEnvironment:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportTextExportEnvironmentKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportTextExportEnvironmentKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setExportTextExportEnvironment:

-(BOOL) exportTextExportBody
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportTextExportBodyKey];
  else
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportTextExportBodyKey, (__bridge CFStringRef)LaTeXiTAppKey));
  result = !number ? NO : number.boolValue;
  return result;
}
//end exportTextExportBody

-(void) setExportTextExportBody:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:DragExportTextExportBodyKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportTextExportBodyKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setExportTextExportBody:

-(CGFloat) exportScalePercent
{
  CGFloat result = 0;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportScaleAsPercentKey];
  else
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportScaleAsPercentKey, (__bridge CFStringRef)LaTeXiTAppKey));
  result = !number ? 100. : number.doubleValue;
  return result;
}
//end exportScalePercent

-(void) setExportScalePercent:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setDouble:value forKey:DragExportScaleAsPercentKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportScaleAsPercentKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
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
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportIncludeBackgroundColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:DragExportIncludeBackgroundColorKey];
  else
#ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportIncludeBackgroundColorKey, (__bridge CFTypeRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
#else
  CFPreferencesSetAppValue((CHBRIDGE CFStringRef)DragExportIncludeBackgroundColorKey, [NSNumber numberWithBool:value], (CHBRIDGE CFStringRef)LaTeXiTAppKey);
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
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultDoNotClipPreviewKey, (__bridge CFStringRef)LaTeXiTAppKey));
  result = number.boolValue;
  return result;
}
//end doNotClipPreview

-(void) setDoNotClipPreview:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:DefaultDoNotClipPreviewKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)DefaultDoNotClipPreviewKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setDoNotClipPreview:

#pragma mark latexisation

-(latex_mode_t) latexisationLaTeXMode
{
  CFIndex result = LATEX_MODE_ALIGN;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:DefaultModeKey];
  else
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)DefaultModeKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
    if (!ok)
      result = LATEX_MODE_ALIGN;
  }
  return (latex_mode_t)result;
}
//end latexisationLaTeXMode

-(void) setLatexisationLaTeXMode:(latex_mode_t)mode
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:DefaultModeKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)DefaultModeKey, (__bridge CFPropertyListRef)@(mode), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setLatexisationLaTeXMode:

-(CGFloat) latexisationFontSize
{
  CGFloat result = 0;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultPointSizeKey];
  else
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultPointSizeKey, (__bridge CFStringRef)LaTeXiTAppKey));
  result = !number ? 36. : number.doubleValue;
  return result;
}
//end latexisationFontSize

-(NSData*) latexisationFontColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:DefaultColorKey];
  else
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end latexisationFontColorData

-(NSColor*) latexisationFontColor
{
  NSColor* result = [NSColor colorWithData:self.latexisationFontColorData];
  return result;
}
//end latexisationFontColor

-(document_style_t) documentStyle
{
  CFIndex result = DOCUMENT_STYLE_NORMAL;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:DocumentStyleKey];
  else
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppIntegerValue((CHBRIDGE CFStringRef)DocumentStyleKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, &ok);
    if (!ok)
      result = DOCUMENT_STYLE_NORMAL;
  }
  return (document_style_t)result;
}
//end documentStyle

-(void) setDocumentStyle:(document_style_t)documentStyle
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setInteger:documentStyle forKey:DocumentStyleKey];
  else
    CFPreferencesSetAppValue((CFStringRef)DocumentStyleKey, (CFNumberRef)@(documentStyle), (CFStringRef)LaTeXiTAppKey);
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultImageViewBackgroundKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end documentImageViewBackgroundColorData

-(NSColor*) documentImageViewBackgroundColor
{
  NSColor* result = [NSColor colorWithData:self.documentImageViewBackgroundColorData];
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultFontKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
  NSFont* result = [NSFont fontWithData:self.editionFontData];
  return result;
}
//end editionFont

-(void) setEditionFont:(NSFont*)value
{
  self.editionFontData = [value data];
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)LaTeXiTAppKey));
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)LaTeXiTAppKey));
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)LaTeXiTAppKey));
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)LaTeXiTAppKey));
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)LaTeXiTAppKey));
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)LaTeXiTAppKey));
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
    result = [CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)EditionTabKeyInsertsSpacesCountKey, (__bridge CFStringRef)LaTeXiTAppKey)) unsignedIntValue];
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
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)EditionAutoCompleteOnBackslashEnabledKey, (CHBRIDGE const void*)[NSNumber numberWithBool:value], (CHBRIDGE CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)EditionAutoCompleteOnBackslashEnabledKey, [NSNumber numberWithBool:value], (CHBRIDGE CFStringRef)LaTeXiTAppKey);
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
  NSArray* preambles = self.preambles;
  NSInteger preambleDocumentIndex = [self preambleDocumentIndex];
  NSDictionary* preamble = (0<=preambleDocumentIndex) && ((unsigned)preambleDocumentIndex<[preambles count]) ?
                           [preambles objectAtIndex:preambleDocumentIndex] : nil;
  id preambleValue = [preamble objectForKey:@"value"];
  result = !preambleValue ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:preambleValue];
  if (!result)
    result = [PreamblesController defaultLocalizedPreambleValueAttributedString];
  return result;
}
//end preambleDocumentAttributedString

-(NSAttributedString*) preambleServiceAttributedString
{
  NSAttributedString* result = nil;
  NSArray* preambles = self.preambles;
  NSInteger preambleServiceIndex = [self preambleServiceIndex];
  NSDictionary* preamble = (0<=preambleServiceIndex) && ((unsigned)preambleServiceIndex<[preambles count]) ?
                           [preambles objectAtIndex:preambleServiceIndex] : nil;
  id preambleValue = [preamble objectForKey:@"value"];
  result = !preambleValue ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:preambleValue];
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
  NSArray* bodyTemplates = self.bodyTemplates;
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
  NSArray* bodyTemplates = self.bodyTemplates;
  NSInteger bodyTemplateServiceIndex = [self bodyTemplateServiceIndex];
  NSDictionary* bodyTemplate = (0<=bodyTemplateServiceIndex) && ((unsigned)bodyTemplateServiceIndex<[bodyTemplates count]) ?
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
    CFPreferencesSetAppValue((__bridge CFStringRef)CompositionConfigurationsKey, (__bridge CFArrayRef)value, (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setCompositionConfigurations:

-(NSInteger) compositionConfigurationsDocumentIndex
{
  NSInteger result = 0;
  NSArrayController* compositionsController = [self lazyCompositionConfigurationsControllerWithCreationIfNeeded:NO];
  if (compositionsController)
  {
    NSUInteger result2 = compositionsController.selectionIndex;
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
  }
  else//if (!compositionsController)
  {
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setInteger:value forKey:CompositionConfigurationDocumentIndexKey];
    else
      CFPreferencesSetAppValue((__bridge CFStringRef)CompositionConfigurationDocumentIndexKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
  }//end if (!compositionsController)
}
//end setCompositionConfigurationsDocumentIndex:

-(NSDictionary*) compositionConfigurationDocument
{
  NSDictionary* result = nil;
  NSArray* configurations = self.compositionConfigurations;
  NSUInteger selectedIndex = (NSUInteger)Clip_N(0, [self compositionConfigurationsDocumentIndex], [configurations count]);
  result = (selectedIndex < [configurations count]) ? [configurations objectAtIndex:selectedIndex] : nil;
  return result;
}
//end compositionConfigurationDocument

-(void) setCompositionConfigurationDocument:(NSDictionary*)value
{
  NSMutableArray* configurations = [self.compositionConfigurations mutableCopy];
  NSUInteger selectedIndex = (NSUInteger)Clip_N(0, [self compositionConfigurationsDocumentIndex], [configurations count]);
  if (selectedIndex < configurations.count)
  {
    configurations[selectedIndex] = value;
    self.compositionConfigurations = configurations;
  }
}
//end setCompositionConfigurationDocument:

-(void) setCompositionConfigurationDocumentProgramPath:(NSString*)value forKey:(NSString*)key
{
  NSMutableDictionary* configuration = [self.compositionConfigurationDocument deepMutableCopy];
  configuration[key] = value;
  self.compositionConfigurationDocument = configuration;
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
    result = [CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceUsesHistoryKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
  return result;
}
//end historySaveServicesEnabled

-(BOOL) historyDeleteOldEntriesEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:HistoryDeleteOldEntriesEnabledKey];
  else
    result = [CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)HistoryDeleteOldEntriesEnabledKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
  return result;
}
//end historyDeleteOldEntriesEnabled

-(NSNumber*) historyDeleteOldEntriesLimit
{
  NSNumber* result = @NSUIntegerMax;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] objectForKey:HistoryDeleteOldEntriesLimitKey];
  else
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)HistoryDeleteOldEntriesLimitKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end historyDeleteOldEntriesLimit

-(BOOL) historySmartEnabled
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:HistorySmartEnabledKey];
  else
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)HistorySmartEnabledKey, (__bridge CFStringRef)LaTeXiTAppKey))).boolValue;
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
    controller.content = [value mutableCopy];
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
    controller.content = [value mutableCopy];
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
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalLeftMarginKey, (__bridge CFStringRef)LaTeXiTAppKey))).floatValue;
  return result;
}
//end marginsAdditionalLeft

-(void) setMarginsAdditionalLeft:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:AdditionalLeftMarginKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalLeftMarginKey, (__bridge CFNumberRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setMarginsAdditionalLeft:

-(CGFloat) marginsAdditionalRight
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalRightMarginKey];
  else
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalRightMarginKey, (__bridge CFStringRef)LaTeXiTAppKey))).floatValue;
  return result;
}
//end marginsAdditionalRight

-(void) setMarginsAdditionalRight:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:AdditionalRightMarginKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalRightMarginKey, (__bridge CFNumberRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setMarginsAdditionalRight:

-(CGFloat) marginsAdditionalTop
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalTopMarginKey];
  else
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalTopMarginKey, (__bridge CFStringRef)LaTeXiTAppKey))).doubleValue;
  return result;
}
//end marginsAdditionalTop

-(void) setMarginsAdditionalTop:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:AdditionalTopMarginKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalTopMarginKey, (__bridge CFNumberRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setMarginsAdditionalTop:

-(CGFloat) marginsAdditionalBottom
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalBottomMarginKey];
  else
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalBottomMarginKey, (__bridge CFStringRef)LaTeXiTAppKey))).doubleValue;
  return result;
}
//end marginsAdditionalBottom

-(void) setMarginsAdditionalBottom:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:AdditionalBottomMarginKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalBottomMarginKey, (__bridge CFNumberRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
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
  NSArray* encapsulations = self.encapsulations;
  NSUInteger selectedIndex = (NSUInteger)Clip_N(0, [self encapsulationsSelectedIndex], [encapsulations count]);
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
      self->additionalFilesController.content = value;
  else//if (!additionalFilesController)
  {
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:AdditionalFilesPathsKey];
    else
      CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalFilesPathsKey, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)LaTeXiTAppKey);
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
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsEnabledKey, (__bridge CFStringRef)LaTeXiTAppKey))).boolValue;
  return result;
}
//end synchronizationNewDocumentsEnabled

-(void) setSynchronizationNewDocumentsEnabled:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsEnabledKey];
  else
      CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsEnabledKey, (__bridge CFBooleanRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setSynchronizationNewDocumentsEnabled:

-(BOOL) synchronizationNewDocumentsSynchronizePreamble
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SynchronizationNewDocumentsSynchronizePreambleKey];
  else
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, (__bridge CFStringRef)LaTeXiTAppKey))).boolValue;
  return result;
}
//end synchronizationNewDocumentsSynchronizePreamble

-(void) setSynchronizationNewDocumentsSynchronizePreamble:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsSynchronizePreambleKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setSynchronizationNewDocumentsSynchronizePreamble:

-(BOOL) synchronizationNewDocumentsSynchronizeEnvironment
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SynchronizationNewDocumentsSynchronizeEnvironmentKey];
  else
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, (__bridge CFStringRef)LaTeXiTAppKey))).boolValue;
  return result;
}
//end synchronizationNewDocumentsSynchronizeEnvironment

-(void) setSynchronizationNewDocumentsSynchronizeEnvironment:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsSynchronizeEnvironmentKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, (__bridge CFBooleanRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setSynchronizationNewDocumentsSynchronizeEnvironment:

-(BOOL) synchronizationNewDocumentsSynchronizeBody
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SynchronizationNewDocumentsSynchronizeBodyKey];
  else
    result = ((NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, (__bridge CFStringRef)LaTeXiTAppKey))).boolValue;
  return result;
}
//end synchronizationNewDocumentsSynchronizeBody

-(void) setSynchronizationNewDocumentsSynchronizeBody:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsSynchronizeBodyKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, (__bridge const void*)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setSynchronizationNewDocumentsSynchronizeBody:

-(NSString*) synchronizationNewDocumentsPath
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:SynchronizationNewDocumentsPathKey];
  else
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsPathKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end synchronizationNewDocumentsPath

-(void) setSynchronizationNewDocumentsPath:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:SynchronizationNewDocumentsPathKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsPathKey, (__bridge CFStringRef)value, (__bridge CFStringRef)LaTeXiTAppKey);
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
      self->synchronizationAdditionalScriptsController.objectClass = [NSMutableDictionary class];
      [self->synchronizationAdditionalScriptsController setPreservesSelection:YES];
      [self->synchronizationAdditionalScriptsController bind:NSContentArrayBinding
                                                    toObject:[NSUserDefaultsController sharedUserDefaultsController]
                                                 withKeyPath:[NSUserDefaultsController adaptedKeyPath:SynchronizationAdditionalScriptsKey]
                                                     options:@{NSValueTransformerBindingOption: [DictionaryToArrayTransformer transformerWithDescriptors:nil],
                                                               NSHandlesContentAsCompoundValueBindingOption: @YES}];
    }
    else
    {
      NSDictionary* synchronizationAdditionalScripts = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationAdditionalScriptsKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
    NSArray* array = [self lazySynchronizationAdditionalScriptsControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
    result = [[DictionaryToArrayTransformer transformerWithDescriptors:nil] reverseTransformedValue:array];
  }//end if (fromControllerIfPossible)
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SynchronizationAdditionalScriptsKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationAdditionalScriptsKey, (__bridge CFStringRef)LaTeXiTAppKey));
  }//end if (!result)
  return result;
}
//end synchronizationAdditionalScriptsFromControllerIfPossible:createControllerIfNeeded:

+(NSMutableDictionary*) defaultSynchronizationAdditionalScripts
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      [NSNumber numberWithInteger:SCRIPT_SOURCE_STRING], CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [[NSNumber numberWithInteger:SYNCHRONIZATION_SCRIPT_PLACE_LOADING_PREPROCESSING] stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      [NSNumber numberWithInteger:SCRIPT_SOURCE_STRING], CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [[NSNumber numberWithInteger:SYNCHRONIZATION_SCRIPT_PLACE_LOADING_POSTPROCESSING] stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      [NSNumber numberWithInteger:SCRIPT_SOURCE_STRING], CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [[NSNumber numberWithInteger:SYNCHRONIZATION_SCRIPT_PLACE_SAVING_PREPROCESSING] stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      [NSNumber numberWithInteger:SCRIPT_SOURCE_STRING], CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [[NSNumber numberWithInteger:SYNCHRONIZATION_SCRIPT_PLACE_SAVING_POSTPROCESSING] stringValue],
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
    CFPreferencesSetAppValue((__bridge CFStringRef)LatexPaletteGroupKey, (__bridge CFNumberRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setPaletteLaTeXGroupSelectedTag:

-(NSRect) paletteLaTeXWindowFrame
{
  NSRect result = NSZeroRect;
  NSString* frameAsString = nil;
  if (self->isLaTeXiT)
    frameAsString = [[NSUserDefaults standardUserDefaults] stringForKey:LatexPaletteFrameKey];
  else
    frameAsString = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)LatexPaletteFrameKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
    CFPreferencesSetAppValue((__bridge CFStringRef)LatexPaletteDetailsStateKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
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
    CFPreferencesSetAppValue((__bridge CFStringRef)HistoryDisplayPreviewPanelKey, (__bridge CFPropertyListRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
}
//end setHistoryDisplayPreviewPanelState

#pragma mark Library

-(NSString*) libraryPath
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:LibraryPathKey];
  else
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)LibraryPathKey, (__bridge CFStringRef)LaTeXiTAppKey));
  return result;
}
//end libraryPath

-(void) setLibraryPath:(NSString*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:LibraryPathKey];
  else
    CFPreferencesSetAppValue((__bridge CFStringRef)LibraryPathKey, (__bridge const void*)value, (__bridge CFStringRef)LaTeXiTAppKey);
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
    CFPreferencesSetAppValue((__bridge CFStringRef)LibraryDisplayPreviewPanelKey, (__bridge CFBooleanRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
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
            options:@{NSHandlesContentAsCompoundValueBindingOption: @YES}];
    }
    else
    {
      NSArray* editionTextShortcuts = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)TextShortcutsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      self->editionTextShortcutsController = [[NSArrayController alloc] initWithContent:!editionTextShortcuts ? @[] : editionTextShortcuts];
    }
    [self->editionTextShortcutsController setAutomaticallyPreparesContent:NO];
    self->editionTextShortcutsController.objectClass = [NSMutableDictionary class];
    result = self->editionTextShortcutsController;
  }//end if (!self->editionTextShortcutsController && creationOptionIfNeeded)
  return result;
}
//end lazyEditionTextShortcutsControllerWithCreationIfNeeded:

-(NSArray*) editionTextShortcutsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [self lazyEditionTextShortcutsControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:TextShortcutsKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)TextShortcutsKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
        options:@{NSHandlesContentAsCompoundValueBindingOption: @YES}];
    }
    else
    {
      NSArray* preambles = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)PreamblesKey, (__bridge CFStringRef)LaTeXiTAppKey));
      self->preamblesController = [[PreamblesController alloc] initWithContent:!preambles ? @[] : preambles];
    }
    [self->preamblesController setPreservesSelection:YES];
    [self->preamblesController setAvoidsEmptySelection:YES];
    [self->preamblesController setAutomaticallyPreparesContent:NO];
    self->preamblesController.objectClass = [NSMutableDictionary class];
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
    result = [self lazyPreamblesControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:PreamblesKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)PreamblesKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
        options:@{NSHandlesContentAsCompoundValueBindingOption: @YES}];
    }
    else
    {
      NSArray* bodyTemplates = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)BodyTemplatesKey, (__bridge CFStringRef)LaTeXiTAppKey));
      self->bodyTemplatesController = [[BodyTemplatesController alloc] initWithContent:!bodyTemplates ? @[] : bodyTemplates];
    }
    [self->bodyTemplatesController setPreservesSelection:YES];
    [self->bodyTemplatesController setAvoidsEmptySelection:YES];
    [self->bodyTemplatesController setAutomaticallyPreparesContent:NO];
    self->bodyTemplatesController.objectClass = [NSMutableDictionary class];
    result = self->bodyTemplatesController;
  }//end if (!self->bodyTemplatesController && creationOptionIfNeeded)
  return result;
}
//end lazyBodyTemplatesControllerWithCreationIfNeeded:

-(NSArray*) bodyTemplatesFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [self lazyBodyTemplatesControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:BodyTemplatesKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)BodyTemplatesKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
            options:@{NSHandlesContentAsCompoundValueBindingOption: @YES}];
    }
    else
    {
      NSArray* compositionConfigurations = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)CompositionConfigurationsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      self->compositionConfigurationsController = [[CompositionConfigurationsController alloc] initWithContent:!compositionConfigurations ? @[] : compositionConfigurations];
    }
    [self->compositionConfigurationsController setPreservesSelection:YES];
    [self->compositionConfigurationsController setAvoidsEmptySelection:YES];
    [self->compositionConfigurationsController setAutomaticallyPreparesContent:YES];
    self->compositionConfigurationsController.objectClass = [NSMutableDictionary class];
    [self->compositionConfigurationsController ensureDefaultCompositionConfiguration];
    [self->compositionConfigurationsController bind:NSSelectionIndexesBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
      withKeyPath:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]
          options:@{NSValueTransformerNameBindingOption: [IndexToIndexesTransformer name]}];
    result = self->compositionConfigurationsController;
  }//end if (!self->compositionConfigurationsController && creationOptionIfNeeded)
  return result;
}
//end lazyCompositionConfigurationsControllerWithCreationIfNeeded:

-(NSArray*) compositionConfigurationsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [self lazyCompositionConfigurationsControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:CompositionConfigurationsKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)CompositionConfigurationsKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
            options:@{NSHandlesContentAsCompoundValueBindingOption: @YES}];
    }
    else
    {
      NSArray* serviceShortcuts = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceShortcutsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      self->serviceShortcutsController = [[NSArrayController alloc] initWithContent:!serviceShortcuts ? @[] : serviceShortcuts];
    }
    [self->serviceShortcutsController setAutomaticallyPreparesContent:NO];
    self->serviceShortcutsController.objectClass = [NSMutableDictionary class];
    result = self->serviceShortcutsController;
  }//end if (!self->serviceShortcutsController && creationOptionIfNeeded)
  return result;
}
//end lazyServiceShortcutsControllerWithCreationIfNeeded:

-(NSArray*) serviceShortcutsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [self lazyServiceShortcutsControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:ServiceShortcutsKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceShortcutsKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
            options:@{NSHandlesContentAsCompoundValueBindingOption: @YES}];
    }
    else
    {
      NSArray* serviceRegularExpressionFilters = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceRegularExpressionFiltersKey, (__bridge CFStringRef)LaTeXiTAppKey));
      self->serviceRegularExpressionFiltersController = [[ServiceRegularExpressionFiltersController alloc] initWithContent:!serviceRegularExpressionFilters ? @[] : serviceRegularExpressionFilters];
    }
    [self->serviceRegularExpressionFiltersController setAutomaticallyPreparesContent:NO];
    self->serviceRegularExpressionFiltersController.objectClass = [NSMutableDictionary class];
    result = self->serviceRegularExpressionFiltersController;
  }//end if (!self->serviceRegularExpressionFiltersController && creationOptionIfNeeded)
  return result;
}
//end lazyServiceRegularExpressionFiltersControllerWithCreationIfNeeded:

-(NSArray*) serviceRegularExpressionFiltersFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [self lazyServiceRegularExpressionFiltersControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:ServiceRegularExpressionFiltersKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceRegularExpressionFiltersKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
      NSArray* additionalFilesPaths = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalFilesPathsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      self->additionalFilesController = [[AdditionalFilesController alloc] initWithContent:!additionalFilesPaths ? @[] : additionalFilesPaths];
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
    result = [self lazyAdditionalFilesControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:AdditionalFilesPathsKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalFilesPathsKey, (__bridge CFStringRef)LaTeXiTAppKey));
  }
  if (!result) result = @[];
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
        options:@{NSValueTransformerNameBindingOption: [MutableTransformer name],
                NSHandlesContentAsCompoundValueBindingOption: @YES}];
    }
    else
    {
      NSArray* encapsulations = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)EncapsulationsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      self->encapsulationsController = [[EncapsulationsController alloc] initWithContent:!encapsulations ? @[] : encapsulations];
    }
    [self->encapsulationsController setAvoidsEmptySelection:YES];
    [self->encapsulationsController setAutomaticallyPreparesContent:YES];
    [self->encapsulationsController setPreservesSelection:YES];
    [self->encapsulationsController bind:NSSelectionIndexesBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
      withKeyPath:[NSUserDefaultsController adaptedKeyPath:CurrentEncapsulationIndexKey]
      options:@{NSValueTransformerNameBindingOption: [IndexToIndexesTransformer name]}];
    result = self->encapsulationsController;
  }//end if (!self->encapsulationsController && creationOptionIfNeeded)
  return result;
}
//end lazyEncapsulationsControllerWithCreationIfNeeded:

-(NSArray*) encapsulationsFromControllerIfPossible:(BOOL)fromControllerIfPossible createControllerIfNeeded:(BOOL)createControllerIfNeeded
{
  NSArray* result = nil;
  if (fromControllerIfPossible)
    result = [self lazyEncapsulationsControllerWithCreationIfNeeded:createControllerIfNeeded].arrangedObjects;
  if (!result)
  {
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] arrayForKey:EncapsulationsKey];
    else
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)EncapsulationsKey, (__bridge CFStringRef)LaTeXiTAppKey));
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
    NSString* infoPlistPath =
      [[[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"Info.plist"];
    NSURL* infoPlistURL = [NSURL fileURLWithPath:infoPlistPath];
    CFErrorRef cfStringError = nil;
    #ifdef ARC_ENABLED
    CFPropertyListRef cfInfoPlist = CFPropertyListCreateWithData(kCFAllocatorDefault,
                                                                    (CHBRIDGE CFDataRef)[NSData dataWithContentsOfURL:infoPlistURL],
                                                                    kCFPropertyListMutableContainersAndLeaves, NULL, &cfStringError);
    #else
    CFPropertyListRef cfInfoPlist = CFPropertyListCreateWithData(kCFAllocatorDefault,
                                                                    (CFDataRef)[NSData dataWithContentsOfURL:infoPlistURL],
                                                                    kCFPropertyListMutableContainersAndLeaves, NULL, &cfStringError);
    #endif
    if (cfInfoPlist && !cfStringError)
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
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_EQNARRAY], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_EQNARRAY],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_EQNARRAY_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_EQNARRAY_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:SERVICE_DELATEXIZE], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInteger:SERVICE_DELATEXIZE],
          nil];

      NSMutableDictionary* identifiersByServiceName = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN], @"serviceLatexisationAlign",
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN_CLIPBOARD], @"serviceLatexisationAlignAndPutIntoClipBoard",
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN], @"serviceLatexisationEqnarray",//redirection to Align on purpose for migration
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN_CLIPBOARD], @"serviceLatexisationEqnarrayAndPutIntoClipBoard",//redirection to Align on purpose for migration
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY], @"serviceLatexisationDisplay",
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD], @"serviceLatexisationDisplayAndPutIntoClipBoard",
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE], @"serviceLatexisationInline",
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE_CLIPBOARD], @"serviceLatexisationInlineAndPutIntoClipBoard",
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT], @"serviceLatexisationText",
        [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT_CLIPBOARD], @"serviceLatexisationTextAndPutIntoClipBoard",
        [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE], @"serviceMultiLatexisation",
        [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE_CLIPBOARD], @"serviceMultiLatexisationAndPutIntoClipBoard",
        [NSNumber numberWithInteger:SERVICE_DELATEXIZE], @"serviceDeLatexisation",
        nil];
      NSMutableDictionary* serviceNameByIdentifier = [NSMutableDictionary dictionaryWithCapacity:identifiersByServiceName.count];
      NSEnumerator* enumerator = [identifiersByServiceName.allKeys objectEnumerator];
      NSString* serviceName = nil;
      while((serviceName = [enumerator nextObject]))
        serviceNameByIdentifier[identifiersByServiceName[serviceName]] = serviceName;
      serviceNameByIdentifier[@(SERVICE_LATEXIZE_ALIGN)] = @"serviceLatexisationAlign";
      serviceNameByIdentifier[@(SERVICE_LATEXIZE_ALIGN_CLIPBOARD)] = @"serviceLatexisationAlignAndPutIntoClipBoard";

      enumerator = [currentServicesInInfoPlist objectEnumerator];
      NSDictionary* service = nil;
      BOOL didEncounterEqnarray = NO;
      while((service = [enumerator nextObject]))
      {
        NSString* message  = service[@"NSMessage"];
        NSString* shortcutDefault = service[@"NSKeyEquivalent"][@"default"];
        NSString* shortcutWhenEnabled = service[@"NSKeyEquivalent"][@"whenEnabled"];
        NSNumber* enabled = @((BOOL)(shortcutDefault && shortcutWhenEnabled && [shortcutDefault isEqualToString:shortcutWhenEnabled]));
        NSNumber* identifier = identifiersByServiceName[message];
        didEncounterEqnarray |= [message isEqualToString:@"serviceLatexisationEqnarray"] ||
                                [message isEqualToString:@"serviceLatexisationEqnarrayAndPutIntoClipBoard"];
        NSMutableDictionary* serviceEntry = !identifier ? nil : equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[identifier];
        serviceEntry[ServiceShortcutEnabledKey] = enabled;
        serviceEntry[ServiceShortcutStringKey] = (shortcutDefault ? shortcutDefault : @"");
      }//end for each service of info.plist
      NSArray* equivalentUserDefaultsToCurrentServicesInInfoPlist =
        @[equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_LATEXIZE_ALIGN)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_LATEXIZE_ALIGN_CLIPBOARD)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_LATEXIZE_DISPLAY)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_LATEXIZE_DISPLAY_CLIPBOARD)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_LATEXIZE_INLINE)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_LATEXIZE_INLINE_CLIPBOARD)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_LATEXIZE_TEXT)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_LATEXIZE_TEXT_CLIPBOARD)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_MULTILATEXIZE)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_MULTILATEXIZE_CLIPBOARD)],
          equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict[@(SERVICE_DELATEXIZE)]];          

      //build services as found in user defaults
      NSMutableArray* equivalentServicesToCurrentUserDefaults = [NSMutableArray arrayWithCapacity:6];
      NSArray* standardReturnTypes = @[NSPasteboardTypeRTFD, @"NSRTFDPboardType", (id)kUTTypeFlatRTFD,
                                        NSPasteboardTypePDF, @"NSPDFPboardType", (id)kUTTypePDF,
                                        @"NSPostScriptPboardType", @"com.adobe.encapsulated-postscript",
                                       NSPasteboardTypeTIFF, @"NSTIFFPboardType", (id)kUTTypeTIFF,
                                       NSPasteboardTypePNG, @"NSPNGPboardType", (id)kUTTypePNG,
                                       (id)kUTTypeJPEG];
      NSArray* standardSendTypes = @[NSPasteboardTypeRTF, @"NSRTFPboardType", (id)kUTTypeRTF,
                                     NSPasteboardTypePDF, @"NSPDFPboardType", (id)kUTTypePDF,
                                     NSPasteboardTypeString, @"NSStringPboardType", (id)kUTTypeUTF8PlainText];
      NSArray* multiLatexisationReturnTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", kUTTypeRTFD, nil];
      NSArray* multiLatexisationSendTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", kUTTypeRTFD, @"NSRTFPboardType", kUTTypeRTF, nil];
      NSArray* deLatexisationReturnTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", kUTTypeRTFD,
                                                                     @"NSPasteboardTypePDF", @"NSPDFPboardType", kUTTypePDF,
                                                                     @"NSPasteboardTypeRTF", @"NSRTFPboardType", kUTTypeRTF, nil];
      NSArray* deLatexisationSendTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", kUTTypeRTFD, @"NSPasteboardTypePDF", @"NSPDFPboardType", kUTTypePDF, nil];
      NSDictionary* returnTypesByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        standardReturnTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN],
        standardReturnTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN_CLIPBOARD],
        standardReturnTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY],
        standardReturnTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD],
        standardReturnTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE],
        standardReturnTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE_CLIPBOARD],
        standardReturnTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT],
        standardReturnTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT_CLIPBOARD],
        multiLatexisationReturnTypes, [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE],
        multiLatexisationReturnTypes, [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE_CLIPBOARD],
        deLatexisationReturnTypes, [NSNumber numberWithInteger:SERVICE_DELATEXIZE],
        nil];
      NSDictionary* sendTypesByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        standardSendTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN],
        standardSendTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN_CLIPBOARD],
        standardSendTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY],
        standardSendTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD],
        standardSendTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE],
        standardSendTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE_CLIPBOARD],
        standardSendTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT],
        standardSendTypes, [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT_CLIPBOARD],
        multiLatexisationSendTypes, [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE],
        multiLatexisationSendTypes, [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE_CLIPBOARD],
        deLatexisationSendTypes, [NSNumber numberWithInteger:SERVICE_DELATEXIZE],
        nil];
      NSDictionary* serviceDescriptionsByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        @"SERVICE_DESCRIPTION_ALIGN", [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN],
        @"SERVICE_DESCRIPTION_ALIGN_CLIPBOARD", [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN_CLIPBOARD],
        @"SERVICE_DESCRIPTION_DISPLAY", [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY],
        @"SERVICE_DESCRIPTION_DISPLAY_CLIPBOARD", [NSNumber numberWithInteger:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD],
        @"SERVICE_DESCRIPTION_INLINE", [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE],
        @"SERVICE_DESCRIPTION_INLINE_CLIPBOARD", [NSNumber numberWithInteger:SERVICE_LATEXIZE_INLINE_CLIPBOARD],
        @"SERVICE_DESCRIPTION_TEXT", [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT],
        @"SERVICE_DESCRIPTION_TEXT_CLIPBOARD", [NSNumber numberWithInteger:SERVICE_LATEXIZE_TEXT_CLIPBOARD],
        @"SERVICE_DESCRIPTION_MULTIPLE", [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE],
        @"SERVICE_DESCRIPTION_MULTIPLE_CLIPBOARD", [NSNumber numberWithInteger:SERVICE_MULTILATEXIZE_CLIPBOARD],
        @"SERVICE_DESCRIPTION_DELATEXISATION", [NSNumber numberWithInteger:SERVICE_DELATEXIZE],
        nil];
      
      
      NSArray* currentServiceShortcuts = self.serviceShortcuts;
      enumerator = [currentServiceShortcuts objectEnumerator];
      service = nil;
      while((service = [enumerator nextObject]))
      {
        NSNumber* serviceIdentifier  = service[ServiceShortcutIdentifierKey];
        NSString* serviceTitle       = [self serviceDescriptionForIdentifier:(service_identifier_t)serviceIdentifier.integerValue];
        NSString* menuItemName       = [@"LaTeXiT/" stringByAppendingString:serviceTitle];
        NSString* serviceMessage     = serviceNameByIdentifier[serviceIdentifier];
        NSString* shortcutString     = service[ServiceShortcutStringKey];
        BOOL      shortcutEnabled    = [service[ServiceShortcutEnabledKey] boolValue];
        NSArray*  returnTypes        = returnTypesByServiceIdentifier[serviceIdentifier];
        NSArray*  sendTypes          = sendTypesByServiceIdentifier[serviceIdentifier];
        NSString* serviceDescription = [NSString stringWithFormat:@"%@\n%@",
                                          @"SERVICE_DESCRIPTION",
                                          serviceDescriptionsByServiceIdentifier[serviceIdentifier]];

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
            [[NSNumber numberWithInteger:30000] stringValue], @"NSTimeOut",
            [NSDictionary dictionary], @"NSRequiredContext",
            nil];
          [equivalentServicesToCurrentUserDefaults addObject:serviceItemPlist];
      }//end for each service from user preferences

      if (didEncounterEqnarray || ![equivalentUserDefaultsToCurrentServicesInInfoPlist isEqualToArray:currentServiceShortcuts])
      {
        if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK)
        {
          NSAlert* alert = [NSAlert new];
          alert.messageText = NSLocalizedString(@"The current Service shortcuts of LaTeXiT do not match the ones defined in the preferences",
                                                @"The current Service shortcuts of LaTeXiT do not match the ones defined in the preferences");
          alert.informativeText = NSLocalizedString(@"__EXPLAIN_CHANGE_SHORTCUTS__", @"__EXPLAIN_CHANGE_SHORTCUTS__");
          [alert addButtonWithTitle:NSLocalizedString(@"Apply preferences",
                                                      @"Apply preferences")];
          [alert addButtonWithTitle:NSLocalizedString(@"Update preferences",
                                                      @"Update preferences")];
          [alert addButtonWithTitle:NSLocalizedString(@"Ignore", @"Ignore")].keyEquivalent = @"\033";//escape
          
          NSInteger result = [alert runModal];
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
          self.serviceShortcuts = equivalentUserDefaultsToCurrentServicesInInfoPlist;
          NSUpdateDynamicServices();
          ok = YES;
        }
        else if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS)
        {
          infoPlist[@"NSServices"] = equivalentServicesToCurrentUserDefaults;
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
            NSString* dst = infoPlistURL.path;
            if (!myStatus && src && dst && [infoPlist writeToFile:src atomically:YES])
            {
              const char* args[] = {src.fileSystemRepresentation, dst.fileSystemRepresentation, NULL};
              myStatus = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/cp", kAuthorizationFlagDefaults, (char**)args, NULL);
            }
            if (src)
              [[NSFileManager defaultManager] removeItemAtPath:src error:0];
            myStatus = myStatus ? myStatus : AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDestroyRights);
            ok = (myStatus == 0);
          }//end if (!ok)
          if (ok)
             NSUpdateDynamicServices();
          else
          {
            if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK)
            {
              NSAlert* alert = [NSAlert new];
              alert.messageText = NSLocalizedString(@"New Service shortcuts could not be set",
                                                    @"New Service shortcuts could not be set");
              alert.informativeText = NSLocalizedString(@"Authentication failed or did not allow to rewrite the <Info.plist> file inside the LaTeXiT.app bundle",
                                                        @"Authentication failed or did not allow to rewrite the <Info.plist> file inside the LaTeXiT.app bundle");
              [alert addButtonWithTitle:NSLocalizedString(@"Update preferences",@"Update preferences")];
              [alert addButtonWithTitle:NSLocalizedString(@"Ignore",@"Ignore")].keyEquivalent = @"\033";
              
              NSInteger result = [alert runModal];
              if (result == NSAlertFirstButtonReturn)
                 authenticationFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS;
              else
                 authenticationFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE;
            }
            if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE)
              ok = NO;
            else if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS)
            {
              self.serviceShortcuts = equivalentUserDefaultsToCurrentServicesInInfoPlist;
              NSUpdateDynamicServices();
              ok = YES;
            }
          }//end if (authentication did not help writing)
        }//end if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS)
      }//end if (![currentServicesInInfoPlist iEqualTo:equivalentServicesToCurrentUserDefaults])
    }//end if (cfInfoPlist)
    if (cfInfoPlist)
      CFRelease(cfInfoPlist);
  }//end if (ok)  
  return ok;
}
//end changeServiceShortcutsWithDiscrepancyFallback:authenticationFallback:

@end
