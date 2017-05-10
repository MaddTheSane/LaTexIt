//
//  PreferencesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/03/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
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
#import "NSUserDefaultsControllerExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreamblesController.h"
#import "PreferencesControllerMigration.h"
#import "ServiceRegularExpressionFiltersController.h"
#import "SynchronizationAdditionalScriptsController.h"
#import "Utils.h"

#import <Security/Security.h>

static PreferencesController* sharedInstance = nil;

NSString* LaTeXiTAppKey = @"fr.chachatelier.pierre.LaTeXiT";
NSString* Old_LaTeXiTAppKey = @"fr.club.ktd.LaTeXiT";

NSString* LaTeXiTVersionKey = @"version";

NSString* DocumentStyleKey = @"DocumentStyle";

NSString* DragExportTypeKey                  = @"DragExportType";
NSString* DragExportJpegColorKey             = @"DragExportJpegColor";
NSString* DragExportJpegQualityKey           = @"DragExportJpegQuality";
NSString* DragExportSvgPdfToSvgPathKey       = @"DragExportSvgPdfToSvgPath";
NSString* DragExportTextExportPreambleKey    = @"DragExportTextExportPreambleKey";
NSString* DragExportTextExportEnvironmentKey = @"DragExportTextExportEnvironmentKey";
NSString* DragExportTextExportBodyKey        = @"DragExportTextExportBodyKey";
NSString* DragExportScaleAsPercentKey        = @"DragExportScaleAsPercent";
NSString* DefaultImageViewBackgroundKey      = @"DefaultImageViewBackground";
NSString* DefaultAutomaticHighContrastedPreviewBackgroundKey = @"DefaultAutomaticHighContrastedPreviewBackground";
NSString* DefaultDoNotClipPreviewKey    = @"DefaultDoNotClipPreview";
NSString* DefaultColorKey               = @"DefaultColor";
NSString* DefaultPointSizeKey           = @"DefaultPointSize";
NSString* DefaultModeKey                = @"DefaultMode";

NSString* SpellCheckingEnableKey               = @"SpellCheckingEnabled";
NSString* SyntaxColoringEnableKey              = @"SyntaxColoringEnabled";
NSString* SyntaxColoringTextForegroundColorKey = @"SyntaxColoringTextForegroundColor";
NSString* SyntaxColoringTextBackgroundColorKey = @"SyntaxColoringTextBackgroundColor";
NSString* SyntaxColoringCommandColorKey        = @"SyntaxColoringCommandColor";
NSString* SyntaxColoringMathsColorKey          = @"SyntaxColoringMathsColor";
NSString* SyntaxColoringKeywordColorKey        = @"SyntaxColoringKeywordColor";
NSString* SyntaxColoringCommentColorKey        = @"SyntaxColoringCommentColor";
NSString* ReducedTextAreaStateKey              = @"ReducedTextAreaState";

NSString* DefaultFontKey               = @"DefaultFont";
NSString* PreamblesKey                         = @"Preambles";
NSString* LatexisationSelectedPreambleIndexKey = @"LatexisationSelectedPreambleIndex";
NSString* BodyTemplatesKey                         = @"BodyTemplates";
NSString* LatexisationSelectedBodyTemplateIndexKey = @"LatexisationSelectedBodyTemplateIndexKey";

NSString* ServiceSelectedPreambleIndexKey     = @"ServiceSelectedPreambleIndex";
NSString* ServiceSelectedBodyTemplateIndexKey = @"ServiceSelectedBodyTemplateIndexKey";
NSString* ServiceShortcutsKey                 = @"ServiceShortcuts";
NSString* ServiceShortcutEnabledKey           = @"enabled";
NSString* ServiceShortcutClipBoardOptionKey   = @"clipBoardOption";
NSString* ServiceShortcutStringKey            = @"string";
NSString* ServiceShortcutIdentifierKey        = @"identifier";

NSString* ServiceRespectsBaselineKey      = @"ServiceRespectsBaseline";
NSString* ServiceRespectsPointSizeKey     = @"ServiceRespectsPointSize";
NSString* ServicePointSizeFactorKey       = @"ServicePointSizeFactor";
NSString* ServiceRespectsColorKey         = @"ServiceRespectsColor";
NSString* ServiceUsesHistoryKey           = @"ServiceUsesHistory";
NSString* ServiceRegularExpressionFiltersKey         = @"ServiceRegularExpressionFilters";
NSString* ServiceRegularExpressionFilterEnabledKey   = @"ServiceRegularExpressionFilterEnabled";
NSString* ServiceRegularExpressionFilterInputPatternKey     = @"ServiceRegularExpressionFilterInputPattern";
NSString* ServiceRegularExpressionFilterOutputPatternKey    = @"ServiceRegularExpressionFilterOutputPattern";

NSString* AdditionalTopMarginKey          = @"AdditionalTopMargin";
NSString* AdditionalLeftMarginKey         = @"AdditionalLeftMargin";
NSString* AdditionalRightMarginKey        = @"AdditionalRightMargin";
NSString* AdditionalBottomMarginKey       = @"AdditionalBottomMargin";
NSString* EncapsulationsEnabledKey        = @"EncapsulationsEnabled";
NSString* EncapsulationsKey               = @"Encapsulations";
NSString* CurrentEncapsulationIndexKey    = @"CurrentEncapsulationIndex";
NSString* TextShortcutsKey                = @"TextShortcuts";

NSString* EditionTabKeyInsertsSpacesEnabledKey = @"EditionTabKeyInsertsSpacesEnabled";
NSString* EditionTabKeyInsertsSpacesCountKey   = @"EditionTabKeyInsertsSpacesCount";

NSString* CompositionConfigurationsKey             = @"CompositionConfigurations";
NSString* CompositionConfigurationDocumentIndexKey = @"CompositionConfigurationDocumentIndexKey";

NSString* HistoryDeleteOldEntriesEnabledKey = @"HistoryDeleteOldEntriesEnabled";
NSString* HistoryDeleteOldEntriesLimitKey   = @"HistoryDeleteOldEntriesLimit";
NSString* HistorySmartEnabledKey            = @"HistorySmartEnabled";

NSString* LastEasterEggsDatesKey       = @"LastEasterEggsDates";

NSString* CompositionConfigurationsControllerVisibleAtStartupKey = @"CompositionConfigurationsControllerVisibleAtStartup";
NSString* EncapsulationsControllerVisibleAtStartupKey = @"EncapsulationsControllerVisibleAtStartup";
NSString* HistoryControllerVisibleAtStartupKey       = @"HistoryControllerVisibleAtStartup";
NSString* LatexPalettesControllerVisibleAtStartupKey = @"LatexPalettesControllerVisibleAtStartup";
NSString* LibraryControllerVisibleAtStartupKey       = @"LibraryControllerVisibleAtStartup";
NSString* MarginControllerVisibleAtStartupKey        = @"MarginControllerVisibleAtStartup";
NSString* AdditionalFilesWindowControllerVisibleAtStartupKey = @"AdditionalFilesWindowControllerVisibleAtStartup";

NSString* LibraryPathKey                = @"LibraryPath";
NSString* LibraryViewRowTypeKey         = @"LibraryViewRowType";
NSString* LibraryDisplayPreviewPanelKey = @"LibraryDisplayPreviewPanel";
NSString* HistoryDisplayPreviewPanelKey = @"HistoryDisplayPreviewPanel";

NSString* LatexPaletteGroupKey        = @"LatexPaletteGroup";
NSString* LatexPaletteFrameKey        = @"LatexPaletteFrame";
NSString* LatexPaletteDetailsStateKey = @"LatexPaletteDetailsState";

NSString* ShowWhiteColorWarningKey       = @"ShowWhiteColorWarning";

NSString* CompositionModeDidChangeNotification = @"CompositionModeDidChangeNotification";
NSString* CurrentCompositionConfigurationDidChangeNotification = @"CurrentCompositionConfigurationDidChangeNotification";

NSString* CompositionConfigurationNameKey                        = @"name";
NSString* CompositionConfigurationIsDefaultKey                   = @"isDefault";
NSString* CompositionConfigurationCompositionModeKey             = @"compositionMode";
NSString* CompositionConfigurationUseLoginShellKey               = @"useLoginShell";
NSString* CompositionConfigurationPdfLatexPathKey                = @"pdfLatexPath";
NSString* CompositionConfigurationPsToPdfPathKey                 = @"psToPdfPath";
NSString* CompositionConfigurationXeLatexPathKey                 = @"xeLatexPath";
NSString* CompositionConfigurationLatexPathKey                   = @"latexPath";
NSString* CompositionConfigurationDviPdfPathKey                  = @"dviPdfPath";
NSString* CompositionConfigurationGsPathKey                      = @"gsPath";
NSString* CompositionConfigurationProgramArgumentsKey            = @"programArguments";
NSString* CompositionConfigurationAdditionalProcessingScriptsKey = @"additionalProcessingScripts";
NSString* CompositionConfigurationAdditionalProcessingScriptEnabledKey = @"enabled";
NSString* CompositionConfigurationAdditionalProcessingScriptTypeKey    = @"sourceType";
NSString* CompositionConfigurationAdditionalProcessingScriptPathKey    = @"file";
NSString* CompositionConfigurationAdditionalProcessingScriptShellKey   = @"shell";
NSString* CompositionConfigurationAdditionalProcessingScriptContentKey = @"body";

NSString* AdditionalFilesPathsKey = @"AdditionalFilesPaths";

NSString* SynchronizationNewDocumentsEnabledKey = @"SynchronizationNewDocumentsEnabled";
NSString* SynchronizationNewDocumentsSynchronizePreambleKey = @"SynchronizationNewDocumentsSynchronizePreamble";
NSString* SynchronizationNewDocumentsSynchronizeEnvironmentKey = @"SynchronizationNewDocumentsSynchronizeEnvironment";
NSString* SynchronizationNewDocumentsSynchronizeBodyKey = @"SynchronizationNewDocumentsSynchronizeBody";
NSString* SynchronizationNewDocumentsPathKey = @"SynchronizationNewDocumentsPath";
NSString* SynchronizationAdditionalScriptsKey = @"SynchronizationAdditionalScripts";

@interface PreferencesController (PrivateAPI)
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
  result = [(__bridge NSString*)identifier isEqualToString:LaTeXiTAppKey];
  #else
  result = [(NSString*)identifier isEqualToString:LaTeXiTAppKey];
  #endif
  return result;
}
//end isLaTeXiT

+(void) initialize
{
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
    [NSDictionary dictionaryWithObjectsAndKeys:!currentVersion ? @"" : currentVersion, LaTeXiTVersionKey,
                                               [NSNumber numberWithInt:DOCUMENT_STYLE_NORMAL], DocumentStyleKey,
                                               [NSNumber numberWithInt:EXPORT_FORMAT_PDF], DragExportTypeKey,
                                               [[NSColor whiteColor] colorAsData],      DragExportJpegColorKey,
                                               [NSNumber numberWithFloat:100],   DragExportJpegQualityKey,
                                               @"", DragExportSvgPdfToSvgPathKey,
                                               [NSNumber numberWithBool:YES], DragExportTextExportPreambleKey,
                                               [NSNumber numberWithBool:YES], DragExportTextExportEnvironmentKey,
                                               [NSNumber numberWithBool:YES], DragExportTextExportBodyKey,
                                               [NSNumber numberWithFloat:100],   DragExportScaleAsPercentKey,
                                               [[NSColor whiteColor] colorAsData],      DefaultImageViewBackgroundKey,
                                               [NSNumber numberWithBool:NO],     DefaultAutomaticHighContrastedPreviewBackgroundKey,
                                               [NSNumber numberWithBool:NO],     DefaultDoNotClipPreviewKey,
                                               [[NSColor  blackColor]   colorAsData],   DefaultColorKey,
                                               [NSNumber numberWithDouble:36.0], DefaultPointSizeKey,
                                               [NSNumber numberWithInt:LATEX_MODE_ALIGN], DefaultModeKey,
                                               [NSNumber numberWithBool:YES], SpellCheckingEnableKey,
                                               [NSNumber numberWithBool:YES], SyntaxColoringEnableKey,
                                               [[NSColor blackColor]   colorAsData], SyntaxColoringTextForegroundColorKey,
                                               [[NSColor whiteColor]   colorAsData], SyntaxColoringTextBackgroundColorKey,
                                               [[NSColor blueColor]    colorAsData], SyntaxColoringCommandColorKey,
                                               [[NSColor magentaColor] colorAsData], SyntaxColoringMathsColorKey,
                                               [[NSColor blueColor]    colorAsData], SyntaxColoringKeywordColorKey,
                                               [NSNumber numberWithBool:YES], EditionTabKeyInsertsSpacesEnabledKey,
                                               [NSNumber numberWithUnsignedInt:2], EditionTabKeyInsertsSpacesCountKey,                                               
                                               [NSNumber numberWithInt:NSOffState], ReducedTextAreaStateKey,
                                               [[NSColor colorWithCalibratedRed:0 green:128./255. blue:64./255. alpha:1] colorAsData], SyntaxColoringCommentColorKey,
                                               [[NSFont fontWithName:@"Monaco" size:12] data], DefaultFontKey,
                                               factoryDefaultsPreambles, PreamblesKey,
                                               factoryDefaultsBodyTemplates, BodyTemplatesKey,
                                               [NSNumber numberWithUnsignedInt:0], LatexisationSelectedPreambleIndexKey,
                                               [NSNumber numberWithUnsignedInt:0], ServiceSelectedPreambleIndexKey,
                                               [NSNumber numberWithInt:-1], LatexisationSelectedBodyTemplateIndexKey,//none
                                               [NSNumber numberWithInt:-1], ServiceSelectedBodyTemplateIndexKey,//none
                                               [NSArray arrayWithObjects:
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE_CLIPBOARD], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT_CLIPBOARD], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_MULTILATEXIZE], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
                                                   [NSNumber numberWithInt:SERVICE_MULTILATEXIZE_CLIPBOARD], ServiceShortcutIdentifierKey,
                                                   nil],
                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES], ServiceShortcutEnabledKey,
                                                   @"", ServiceShortcutStringKey,
                                                   [NSNumber numberWithInt:SERVICE_DELATEXIZE], ServiceShortcutIdentifierKey,
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
                                               [NSNumber numberWithUnsignedInt:0], CurrentEncapsulationIndexKey,
                                               defaultTextShortcuts, TextShortcutsKey,
                                               [NSArray arrayWithObjects:[CompositionConfigurationsController defaultCompositionConfigurationDictionary], nil],
                                                 CompositionConfigurationsKey,
                                               [NSNumber numberWithUnsignedInt:0], CompositionConfigurationDocumentIndexKey,
                                               [NSNumber numberWithBool:NO], CompositionConfigurationsControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], HistoryDeleteOldEntriesEnabledKey,
                                               [NSNumber numberWithInt:30], HistoryDeleteOldEntriesLimitKey,
                                               [NSNumber numberWithBool:NO], HistorySmartEnabledKey,
                                               [NSNumber numberWithBool:NO], EncapsulationsControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], HistoryControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], LatexPalettesControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], LibraryControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], MarginControllerVisibleAtStartupKey,
                                               [NSNumber numberWithInt:LIBRARY_ROW_IMAGE_AND_TEXT], LibraryViewRowTypeKey,
                                               [NSNumber numberWithBool:YES], LibraryDisplayPreviewPanelKey,
                                               [NSNumber numberWithBool:NO], HistoryDisplayPreviewPanelKey,
                                               [NSNumber numberWithInt:0], LatexPaletteGroupKey,
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
      CFPropertyListRef oldPlistRef = CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)Old_LaTeXiTAppKey);
      if (oldPlistRef)
      {
        CFPreferencesSetAppValue((CFStringRef)key, (CFPropertyListRef)oldPlistRef, (CFStringRef)LaTeXiTAppKey);
        CFPreferencesSetAppValue((CFStringRef)key, 0, (CFStringRef)Old_LaTeXiTAppKey);
        CFRelease(oldPlistRef);
      }
    }//end for each default
    CFPreferencesAppSynchronize((CFStringRef)Old_LaTeXiTAppKey);
    CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
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
      CFPropertyListRef plistRef = CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)LaTeXiTAppKey);
      if (plistRef)
        CFRelease(plistRef);
      else
        CFPreferencesSetAppValue((CFStringRef)key, (CFPropertyListRef)value, (CFStringRef)LaTeXiTAppKey);
    }//end for each default
    CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
  }//end if (userDefaults)

  //from version >= 1.6.0, the export format is no more stored as a string but with a number
  id exportFormat = [userDefaults objectForKey:DragExportTypeKey];
  if ([exportFormat isKindOfClass:[NSString class]])
  {
    exportFormat = [exportFormat lowercaseString];
    if ([exportFormat isEqualToString:@"pdf"])
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_PDF];
    else if ([exportFormat isEqualToString:@"eps"])
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_EPS];
    else if ([exportFormat isEqualToString:@"tiff"])
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_TIFF];
    else if ([exportFormat isEqualToString:@"png"])
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_PNG];
    else if ([exportFormat isEqualToString:@"jpeg"])
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_JPEG];
    else if ([exportFormat isEqualToString:@"svg"])
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_SVG];
    else if ([exportFormat isEqualToString:@"text"])
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_TEXT];
    else
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_PDF];
    [userDefaults setObject:exportFormat forKey:DragExportTypeKey];
  }
}
//end initialize

-(id) init
{
  if (!((self = [super init])))
    return nil;
  self->isLaTeXiT = [[self class] isLaTeXiT];
  [self migratePreferences];
  CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
  self->exportFormatCurrentSession = [self exportFormatPersistent];
  [[NSUserDefaultsController sharedUserDefaultsController]
    addObserver:self forKeyPath:[NSUserDefaultsController adaptedKeyPath:DragExportTypeKey] options:0 context:nil];
  [self observeValueForKeyPath:DragExportTypeKey ofObject:[NSUserDefaultsController sharedUserDefaultsController] change:nil context:nil];
  return self;
}
//end init

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:[NSUserDefaultsController adaptedKeyPath:DragExportTypeKey]])
    [self setExportFormatCurrentSession:[self exportFormatPersistent]];
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[NSUserDefaultsController adaptedKeyPath:DragExportTypeKey]];
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((CFStringRef)LaTeXiTVersionKey, (CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CFStringRef)LaTeXiTVersionKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((CFStringRef)DragExportTypeKey, (__bridge CFNumberRef)[NSNumber numberWithInt:value], (CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DragExportTypeKey, [NSNumber numberWithInt:value], (CFStringRef)LaTeXiTAppKey);
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

-(NSData*) exportJpegBackgroundColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:DragExportJpegColorKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportJpegColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)DragExportJpegColorKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((CFStringRef)DragExportJpegColorKey, (__bridge const void*)value, (CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DragExportJpegColorKey, value, (CFStringRef)LaTeXiTAppKey);
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
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportJpegQualityKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)DragExportJpegQualityKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((CFStringRef)DragExportJpegQualityKey, (__bridge const void*)[NSNumber numberWithFloat:value], (CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DragExportJpegQualityKey, [NSNumber numberWithFloat:value], (CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportJpegQualityPercent:

-(NSString*) exportSvgPdfToSvgPath
{
  NSString* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] stringForKey:DragExportSvgPdfToSvgPathKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportSvgPdfToSvgPathKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CFStringRef)DragExportSvgPdfToSvgPathKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((CFStringRef)DragExportSvgPdfToSvgPathKey, (__bridge const void*)value, (CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DragExportSvgPdfToSvgPathKey, value, (CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportSvgPdfToSvgPath:

-(BOOL) exportTextExportPreamble
{
  BOOL result = NO;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DragExportTextExportPreambleKey];
  else
    #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportTextExportPreambleKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)DragExportTextExportPreambleKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportTextExportPreambleKey, (__bridge const void*)[NSNumber numberWithBool:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DragExportTextExportPreambleKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportTextExportEnvironmentKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)DragExportTextExportEnvironmentKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportTextExportEnvironmentKey, (__bridge const void*)[NSNumber numberWithBool:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DragExportTextExportEnvironmentKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportTextExportBodyKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)DragExportTextExportBodyKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportTextExportBodyKey, (__bridge const void*)[NSNumber numberWithBool:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DragExportTextExportBodyKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DragExportScaleAsPercentKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)DragExportScaleAsPercentKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)DragExportScaleAsPercentKey, (__bridge const void*)[NSNumber numberWithFloat:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DragExportScaleAsPercentKey, [NSNumber numberWithFloat:value], (CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setExportScalePercent:

-(BOOL) doNotClipPreview
{
  BOOL result = 0;
  NSNumber* number = nil;
  if (self->isLaTeXiT)
    number = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultDoNotClipPreviewKey];
  else
    #ifdef ARC_ENABLED
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultDoNotClipPreviewKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)DefaultDoNotClipPreviewKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)DefaultDoNotClipPreviewKey, (__bridge const void*)[NSNumber numberWithBool:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DefaultDoNotClipPreviewKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
    #endif
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
    result = CFPreferencesGetAppIntegerValue((CFStringRef)DefaultModeKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)DefaultModeKey, (__bridge const void*)[NSNumber numberWithInt:mode], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)DefaultModeKey, [NSNumber numberWithInt:mode], (CFStringRef)LaTeXiTAppKey);
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
    number = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultPointSizeKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    number = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)DefaultPointSizeKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)DefaultColorKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
  CFIndex result = DOCUMENT_STYLE_NORMAL;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] integerForKey:DocumentStyleKey];
  else
  {
    Boolean ok = NO;
    result = CFPreferencesGetAppIntegerValue((CFStringRef)DocumentStyleKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
    CFPreferencesSetAppValue((CFStringRef)DocumentStyleKey, (CFNumberRef)[NSNumber numberWithInt:documentStyle], (CFStringRef)LaTeXiTAppKey);
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
    result = CFPreferencesGetAppBooleanValue((CFStringRef)ReducedTextAreaStateKey, (CFStringRef)LaTeXiTAppKey, &ok) && ok;
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultImageViewBackgroundKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)DefaultImageViewBackgroundKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    result = CFPreferencesGetAppBooleanValue((CFStringRef)DefaultAutomaticHighContrastedPreviewBackgroundKey, (CFStringRef)LaTeXiTAppKey, &ok) && ok;
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultFontKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)DefaultFontKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionFontData

-(void) setEditionFontData:(NSData*)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:DefaultFontKey];
  else
    CFPreferencesSetAppValue((CFStringRef)DefaultFontKey, (CFDataRef)value, (CFStringRef)LaTeXiTAppKey);
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
    result = CFPreferencesGetAppBooleanValue((CFStringRef)SyntaxColoringEnableKey, (CFStringRef)LaTeXiTAppKey, &ok) && ok;
  }
  return result;
}
//end editionSyntaxColoringEnabled

-(NSData*) editionSyntaxColoringTextForegroundColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:SyntaxColoringTextForegroundColorKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SyntaxColoringTextForegroundColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)SyntaxColoringTextForegroundColorKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringTextForegroundColorData

-(NSColor*) editionSyntaxColoringTextForegroundColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringTextForegroundColorData]];
  return result;
}
//end editionSyntaxColoringTextForegroundColor

-(NSData*) editionSyntaxColoringTextBackgroundColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:SyntaxColoringTextBackgroundColorKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SyntaxColoringTextBackgroundColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)SyntaxColoringTextBackgroundColorKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringTextBackgroundColorData

-(NSColor*) editionSyntaxColoringTextBackgroundColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringTextBackgroundColorData]];
  return result;
}
//end editionSyntaxColoringTextBackgroundColor

-(NSData*) editionSyntaxColoringCommandColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:SyntaxColoringCommandColorKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SyntaxColoringCommandColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)SyntaxColoringCommandColorKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringCommandColorData

-(NSColor*) editionSyntaxColoringCommandColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringCommandColorData]];
  return result;
}
//end editionSyntaxColoringCommandColor

-(NSData*) editionSyntaxColoringCommentColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:SyntaxColoringCommentColorKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SyntaxColoringCommentColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)SyntaxColoringCommentColorKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringCommentColorData

-(NSColor*) editionSyntaxColoringCommentColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringCommentColorData]];
  return result;
}
//end editionSyntaxColoringCommentColor

-(NSData*) editionSyntaxColoringKeywordColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:SyntaxColoringKeywordColorKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SyntaxColoringKeywordColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)SyntaxColoringKeywordColorKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringKeywordColorData

-(NSColor*) editionSyntaxColoringKeywordColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringKeywordColorData]];
  return result;
}
//end editionSyntaxColoringKeywordColor

-(NSData*) editionSyntaxColoringMathsColorData
{
  NSData* result = nil;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] dataForKey:SyntaxColoringMathsColorKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SyntaxColoringMathsColorKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)SyntaxColoringMathsColorKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
    #endif
  return result;
}
//end editionSyntaxColoringMathsColorData

-(NSColor*) editionSyntaxColoringMathsColor
{
  NSColor* result = [NSColor colorWithData:[self editionSyntaxColoringMathsColorData]];
  return result;
}
//end editionSyntaxColoringMathsColor

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
    result = CFPreferencesGetAppBooleanValue((CFStringRef)EditionTabKeyInsertsSpacesEnabledKey, (CFStringRef)LaTeXiTAppKey, &ok) && ok;
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
    result = [CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)EditionTabKeyInsertsSpacesCountKey, (__bridge CFStringRef)LaTeXiTAppKey)) unsignedIntValue];
    #else
    result = [[NSMakeCollectable((NSData*)CFPreferencesCopyAppValue((CFStringRef)EditionTabKeyInsertsSpacesCountKey, (CFStringRef)LaTeXiTAppKey)) autorelease]unsignedIntValue];
    #endif
  return result;
}
//end editionTabKeyInsertsSpacesCount

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
    result = CFPreferencesGetAppIntegerValue((CFStringRef)LatexisationSelectedPreambleIndexKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
    result = CFPreferencesGetAppIntegerValue((CFStringRef)ServiceSelectedPreambleIndexKey, (CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end preambleServiceIndex

-(NSAttributedString*) preambleDocumentAttributedString
{
  NSAttributedString* result = nil;
  NSArray* preambles = [self preambles];
  NSInteger      preambleDocumentIndex = [self preambleDocumentIndex];
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
  NSArray* preambles = [self preambles];
  NSInteger      preambleServiceIndex = [self preambleServiceIndex];
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
    result = CFPreferencesGetAppIntegerValue((CFStringRef)LatexisationSelectedBodyTemplateIndexKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
    result = CFPreferencesGetAppIntegerValue((CFStringRef)ServiceSelectedBodyTemplateIndexKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)CompositionConfigurationsKey, (__bridge CFArrayRef)value, (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)CompositionConfigurationsKey, value, (CFStringRef)LaTeXiTAppKey);
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
    result = (result2 == NSNotFound) ? -1 : (signed)result2;
  }
  else
  {
    Boolean ok = NO;
    if (self->isLaTeXiT)
      result = [[NSUserDefaults standardUserDefaults] integerForKey:CompositionConfigurationDocumentIndexKey];
    else
      result = CFPreferencesGetAppIntegerValue((CFStringRef)CompositionConfigurationDocumentIndexKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((__bridge CFStringRef)CompositionConfigurationDocumentIndexKey, (__bridge const void*)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CFStringRef)CompositionConfigurationDocumentIndexKey, [NSNumber numberWithInt:value], (CFStringRef)LaTeXiTAppKey);
      #endif
  }//end if (!compositionsController)
}
//end setCompositionConfigurationsDocumentIndex:

-(NSDictionary*) compositionConfigurationDocument
{
  NSDictionary* result = nil;
  NSArray* configurations = [self compositionConfigurations];
  NSUInteger selectedIndex = (NSUInteger)Clip_N(0, [self compositionConfigurationsDocumentIndex], [configurations count]);
  result = (selectedIndex < [configurations count]) ? [configurations objectAtIndex:selectedIndex] : nil;
  return result;
}
//end compositionConfigurationDocument

-(void) setCompositionConfigurationDocument:(NSDictionary*)value
{
  NSMutableArray* configurations = [[self compositionConfigurations] mutableCopy];
  NSUInteger selectedIndex = (NSUInteger)Clip_N(0, [self compositionConfigurationsDocumentIndex], [configurations count]);
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
  NSMutableDictionary* configuration = [[self compositionConfigurationDocument] deepMutableCopy];
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
    result = [CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceUsesHistoryKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)ServiceUsesHistoryKey, (CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
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
    result = [CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)HistoryDeleteOldEntriesEnabledKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)HistoryDeleteOldEntriesEnabledKey, (CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
    #endif
  return result;
}
//end historyDeleteOldEntriesEnabled

-(NSNumber*) historyDeleteOldEntriesLimit
{
  NSNumber* result = [NSNumber numberWithUnsignedInteger:NSUIntegerMax];
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] objectForKey:HistoryDeleteOldEntriesLimitKey];
  else
    #ifdef ARC_ENABLED
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)HistoryDeleteOldEntriesLimitKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)HistoryDeleteOldEntriesLimitKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    result = [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)HistorySmartEnabledKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)HistorySmartEnabledKey, (CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
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
  }//end switch((service_identifier_t)[identifier intValue])
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
    CFPreferencesSetAppValue((CFStringRef)ServiceShortcutsKey, (CFPropertyListRef)value, (CFStringRef)LaTeXiTAppKey);
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
    CFPreferencesSetAppValue((CFStringRef)ServiceRegularExpressionFiltersKey, (CFPropertyListRef)value, (CFStringRef)LaTeXiTAppKey);
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
    result = [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalLeftMarginKey, (__bridge CFStringRef)LaTeXiTAppKey)) floatValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)AdditionalLeftMarginKey, (CFStringRef)LaTeXiTAppKey)) autorelease] floatValue];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalLeftMarginKey, (__bridge CFNumberRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)AdditionalLeftMarginKey, [NSNumber numberWithFloat:value], (CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setMarginsAdditionalLeft:

-(CGFloat) marginsAdditionalRight
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalRightMarginKey];
  else
    #ifdef ARC_ENABLED
    result = [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalRightMarginKey, (__bridge CFStringRef)LaTeXiTAppKey)) floatValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)AdditionalRightMarginKey, (CFStringRef)LaTeXiTAppKey)) autorelease] floatValue];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalRightMarginKey, (__bridge CFNumberRef)[NSNumber numberWithFloat:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)AdditionalRightMarginKey, [NSNumber numberWithFloat:value], (CFStringRef)LaTeXiTAppKey);
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
    result = [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalTopMarginKey, (__bridge CFStringRef)LaTeXiTAppKey)) floatValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)AdditionalTopMarginKey, (CFStringRef)LaTeXiTAppKey)) autorelease] floatValue];
    #endif
  return result;
}
//end marginsAdditionalTop

-(void) setMarginsAdditionalTop:(CGFloat)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:AdditionalTopMarginKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalTopMarginKey, (__bridge CFNumberRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)AdditionalTopMarginKey, [NSNumber numberWithFloat:value], (CFStringRef)LaTeXiTAppKey);
    #endif
}
//end setMarginsAdditionalTop:

-(CGFloat) marginsAdditionalBottom
{
  CGFloat result = 0;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalBottomMarginKey];
  else
    #ifdef ARC_ENABLED
    result = [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalBottomMarginKey, (__bridge CFStringRef)LaTeXiTAppKey)) floatValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)AdditionalBottomMarginKey, (CFStringRef)LaTeXiTAppKey)) autorelease] floatValue];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalBottomMarginKey, (__bridge const void*)[NSNumber numberWithFloat:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)AdditionalBottomMarginKey, [NSNumber numberWithFloat:value], (CFStringRef)LaTeXiTAppKey);
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
    result = CFPreferencesGetAppIntegerValue((CFStringRef)EncapsulationsEnabledKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
    result = CFPreferencesGetAppIntegerValue((CFStringRef)CurrentEncapsulationIndexKey, (CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end encapsulationsSelectedIndex

-(NSString*) encapsulationSelected
{
  NSString* result = nil;
  NSArray* encapsulations = [self encapsulations];
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
      [self->additionalFilesController setContent:value];
  else//if (!additionalFilesController)
  {
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:value forKey:AdditionalFilesPathsKey];
    else
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((__bridge CFStringRef)AdditionalFilesPathsKey, (__bridge const void*)value, (__bridge CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CFStringRef)AdditionalFilesPathsKey, value, (CFStringRef)LaTeXiTAppKey);
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
    result = [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsEnabledKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)SynchronizationNewDocumentsEnabledKey, (CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
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
      CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsEnabledKey, (__bridge CFBooleanRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
      #else
      CFPreferencesSetAppValue((CFStringRef)SynchronizationNewDocumentsEnabledKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
      #endif
}
//end setSynchronizationNewDocumentsEnabled:

-(BOOL) synchronizationNewDocumentsSynchronizePreamble
{
  BOOL result = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:SynchronizationNewDocumentsSynchronizePreambleKey];
  else
    #ifdef ARC_ENABLED
    [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
    #else
    [(NSNumber*)CFPreferencesCopyAppValue((CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, (CFStringRef)LaTeXiTAppKey) boolValue];
    #endif
  return result;
}
//end synchronizationNewDocumentsSynchronizePreamble

-(void) setSynchronizationNewDocumentsSynchronizePreamble:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:SynchronizationNewDocumentsSynchronizePreambleKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, (__bridge const void*)[NSNumber numberWithBool:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)SynchronizationNewDocumentsSynchronizePreambleKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    result = [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, (CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, (__bridge CFBooleanRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)SynchronizationNewDocumentsSynchronizeEnvironmentKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    result = [(NSNumber*)CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, (__bridge CFStringRef)LaTeXiTAppKey)) boolValue];
    #else
    result = [[NSMakeCollectable((NSNumber*)CFPreferencesCopyAppValue((CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, (CFStringRef)LaTeXiTAppKey)) autorelease] boolValue];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, (__bridge const void*)[NSNumber numberWithBool:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)SynchronizationNewDocumentsSynchronizeBodyKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationNewDocumentsPathKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CFStringRef)SynchronizationNewDocumentsPathKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)SynchronizationNewDocumentsPathKey, (__bridge CFStringRef)value, (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)SynchronizationNewDocumentsPathKey, value, (CFStringRef)LaTeXiTAppKey);
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
                                                               [NSNumber numberWithBool:YES], NSHandlesContentAsCompoundValueBindingOption,
                                                               nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSDictionary* synchronizationAdditionalScripts = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationAdditionalScriptsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSDictionary* synchronizationAdditionalScripts = [NSMakeCollectable((NSDictionary*)CFPreferencesCopyAppValue((CFStringRef)SynchronizationAdditionalScriptsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)SynchronizationAdditionalScriptsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSDictionary*)CFPreferencesCopyAppValue((CFStringRef)SynchronizationAdditionalScriptsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
      #endif
  }//end if (!result)
  return result;
}
//end synchronizationAdditionalScriptsFromControllerIfPossible:createControllerIfNeeded:

+(NSMutableDictionary*) defaultSynchronizationAdditionalScripts
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      [NSNumber numberWithInt:SCRIPT_SOURCE_STRING], CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [[NSNumber numberWithInt:SYNCHRONIZATION_SCRIPT_PLACE_LOADING_PREPROCESSING] stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      [NSNumber numberWithInt:SCRIPT_SOURCE_STRING], CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [[NSNumber numberWithInt:SYNCHRONIZATION_SCRIPT_PLACE_LOADING_POSTPROCESSING] stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      [NSNumber numberWithInt:SCRIPT_SOURCE_STRING], CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [[NSNumber numberWithInt:SYNCHRONIZATION_SCRIPT_PLACE_SAVING_PREPROCESSING] stringValue],
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], CompositionConfigurationAdditionalProcessingScriptEnabledKey,
      [NSNumber numberWithInt:SCRIPT_SOURCE_STRING], CompositionConfigurationAdditionalProcessingScriptTypeKey,
      @"", CompositionConfigurationAdditionalProcessingScriptPathKey,
      @"/bin/sh", CompositionConfigurationAdditionalProcessingScriptShellKey,
      @"", CompositionConfigurationAdditionalProcessingScriptContentKey,
      nil], [[NSNumber numberWithInt:SYNCHRONIZATION_SCRIPT_PLACE_SAVING_POSTPROCESSING] stringValue],
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
    result = CFPreferencesGetAppIntegerValue((CFStringRef)LatexPaletteGroupKey, (CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end paletteLaTeXGroupSelectedTag

-(void) setPaletteLaTeXGroupSelectedTag:(NSInteger)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:LatexPaletteGroupKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)LatexPaletteGroupKey, (__bridge CFNumberRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)LatexPaletteGroupKey, [NSNumber numberWithInt:value], (CFStringRef)LaTeXiTAppKey);
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
    frameAsString = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)LatexPaletteFrameKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    frameAsString = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CFStringRef)LatexPaletteFrameKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((CFStringRef)LatexPaletteFrameKey, (CFStringRef)NSStringFromRect(value), (CFStringRef)LaTeXiTAppKey);
}
//end setPaletteLaTeXWindowFrame:

-(BOOL) paletteLaTeXDetailsOpened
{
  BOOL result = NO;
  Boolean ok = NO;
  if (self->isLaTeXiT)
    result = [[NSUserDefaults standardUserDefaults] boolForKey:LatexPaletteDetailsStateKey];
  else
    result = CFPreferencesGetAppBooleanValue((CFStringRef)LatexPaletteDetailsStateKey, (CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end paletteLaTeXDetailsOpened

-(void) setPaletteLaTeXDetailsOpened:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:LatexPaletteDetailsStateKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)LatexPaletteDetailsStateKey, (__bridge const void*)[NSNumber numberWithBool:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)LatexPaletteDetailsStateKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    result = CFPreferencesGetAppBooleanValue((CFStringRef)HistoryDisplayPreviewPanelKey, (CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end historyDisplayPreviewPanelState

-(void) setHistoryDisplayPreviewPanelState:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:HistoryDisplayPreviewPanelKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)HistoryDisplayPreviewPanelKey, (__bridge const void*)[NSNumber numberWithBool:value], (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)HistoryDisplayPreviewPanelKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)LibraryPathKey, (__bridge CFStringRef)LaTeXiTAppKey));
    #else
    result = [NSMakeCollectable((NSString*)CFPreferencesCopyAppValue((CFStringRef)LibraryPathKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    CFPreferencesSetAppValue((__bridge CFStringRef)LibraryPathKey, (__bridge const void*)value, (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)LibraryPathKey, value, (CFStringRef)LaTeXiTAppKey);
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
    result = CFPreferencesGetAppBooleanValue((CFStringRef)LibraryDisplayPreviewPanelKey, (CFStringRef)LaTeXiTAppKey, &ok);
  return result;
}
//end libraryDisplayPreviewPanelState

-(void) setLibraryDisplayPreviewPanelState:(BOOL)value
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:LibraryDisplayPreviewPanelKey];
  else
    #ifdef ARC_ENABLED
    CFPreferencesSetAppValue((__bridge CFStringRef)LibraryDisplayPreviewPanelKey, (__bridge CFBooleanRef)@(value), (__bridge CFStringRef)LaTeXiTAppKey);
    #else
    CFPreferencesSetAppValue((CFStringRef)LibraryDisplayPreviewPanelKey, [NSNumber numberWithBool:value], (CFStringRef)LaTeXiTAppKey);
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
    result =  (library_row_t)CFPreferencesGetAppIntegerValue((CFStringRef)LibraryViewRowTypeKey, (CFStringRef)LaTeXiTAppKey, &ok);
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
            options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* editionTextShortcuts = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)TextShortcutsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* editionTextShortcuts = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)TextShortcutsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)TextShortcutsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)TextShortcutsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
        options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* preambles = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)PreamblesKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* preambles =[NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)PreamblesKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)PreamblesKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)PreamblesKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
        options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* bodyTemplates = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)BodyTemplatesKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* bodyTemplates = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)BodyTemplatesKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)BodyTemplatesKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)BodyTemplatesKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
            options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* compositionConfigurations = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)CompositionConfigurationsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* compositionConfigurations = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)CompositionConfigurationsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)CompositionConfigurationsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)CompositionConfigurationsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
            options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* serviceShortcuts = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceShortcutsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* serviceShortcuts = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)ServiceShortcutsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceShortcutsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)ServiceShortcutsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
            options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* serviceRegularExpressionFilters = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceRegularExpressionFiltersKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* serviceRegularExpressionFilters = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)ServiceRegularExpressionFiltersKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)ServiceRegularExpressionFiltersKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)ServiceRegularExpressionFiltersKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      NSArray* additionalFilesPaths = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalFilesPathsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* additionalFilesPaths = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)AdditionalFilesPathsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)AdditionalFilesPathsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)AdditionalFilesPathsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
                [NSNumber numberWithBool:YES], NSHandlesContentAsCompoundValueBindingOption, nil]];
    }
    else
    {
      #ifdef ARC_ENABLED
      NSArray* encapsulations = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)EncapsulationsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      NSArray* encapsulations = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)EncapsulationsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
      result = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)EncapsulationsKey, (__bridge CFStringRef)LaTeXiTAppKey));
      #else
      result = [NSMakeCollectable((NSArray*)CFPreferencesCopyAppValue((CFStringRef)EncapsulationsKey, (CFStringRef)LaTeXiTAppKey)) autorelease];
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
    NSString* infoPlistPath =
      [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"Info.plist"];
    NSURL* infoPlistURL = [NSURL fileURLWithPath:infoPlistPath];
    CFErrorRef cfStringError = nil;
    #ifdef ARC_ENABLED
    CFPropertyListRef cfInfoPlist = CFPropertyListCreateWithData(kCFAllocatorDefault,
                                                                    (__bridge CFDataRef)[NSData dataWithContentsOfURL:infoPlistURL],
                                                                    kCFPropertyListMutableContainersAndLeaves, NULL, &cfStringError);
    #else
    CFPropertyListRef cfInfoPlist = CFPropertyListCreateFromXMLData(kCFAllocatorDefault,
                                                                    (CFDataRef)[NSData dataWithContentsOfURL:infoPlistURL],
                                                                    kCFPropertyListMutableContainersAndLeaves, &cfStringError);
    #endif
    if (cfInfoPlist && !cfStringError)
    {
      //build services as found in info.plist
      #ifdef ARC_ENABLED
      NSMutableDictionary* infoPlist = (__bridge NSMutableDictionary*) cfInfoPlist;
      NSArray* currentServicesInInfoPlist = [[infoPlist objectForKey:@"NSServices"] mutableCopy];
      #else
      NSMutableDictionary* infoPlist = (NSMutableDictionary*) cfInfoPlist;
      NSArray* currentServicesInInfoPlist = [[[infoPlist objectForKey:@"NSServices"] mutableCopy] autorelease];
      #endif
      NSMutableDictionary* equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict =
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_EQNARRAY], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_EQNARRAY],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_EQNARRAY_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_EQNARRAY_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_MULTILATEXIZE], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:NO], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_MULTILATEXIZE],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_MULTILATEXIZE_CLIPBOARD], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            [NSNumber numberWithBool:YES], ServiceShortcutClipBoardOptionKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_MULTILATEXIZE_CLIPBOARD],
          [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:SERVICE_DELATEXIZE], ServiceShortcutIdentifierKey,
            [NSNumber numberWithBool:NO], ServiceShortcutEnabledKey,
            @"", ServiceShortcutStringKey,
            nil], [NSNumber numberWithInt:SERVICE_DELATEXIZE],
          nil];

      NSMutableDictionary* identifiersByServiceName = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN], @"serviceLatexisationAlign",
        [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD], @"serviceLatexisationAlignAndPutIntoClipBoard",
        [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN], @"serviceLatexisationEqnarray",//redirection to Align on purpose for migration
        [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD], @"serviceLatexisationEqnarrayAndPutIntoClipBoard",//redirection to Align on purpose for migration
        [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY], @"serviceLatexisationDisplay",
        [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD], @"serviceLatexisationDisplayAndPutIntoClipBoard",
        [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE], @"serviceLatexisationInline",
        [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE_CLIPBOARD], @"serviceLatexisationInlineAndPutIntoClipBoard",
        [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT], @"serviceLatexisationText",
        [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT_CLIPBOARD], @"serviceLatexisationTextAndPutIntoClipBoard",
        [NSNumber numberWithInt:SERVICE_MULTILATEXIZE], @"serviceMultiLatexisation",
        [NSNumber numberWithInt:SERVICE_MULTILATEXIZE_CLIPBOARD], @"serviceMultiLatexisationAndPutIntoClipBoard",
        [NSNumber numberWithInt:SERVICE_DELATEXIZE], @"serviceDeLatexisation",
        nil];
      NSMutableDictionary* serviceNameByIdentifier = [NSMutableDictionary dictionaryWithCapacity:[identifiersByServiceName count]];
      NSEnumerator* enumerator = [[identifiersByServiceName allKeys] objectEnumerator];
      NSString* serviceName = nil;
      while((serviceName = [enumerator nextObject]))
        [serviceNameByIdentifier setObject:serviceName forKey:[identifiersByServiceName objectForKey:serviceName]];
      [serviceNameByIdentifier setObject:@"serviceLatexisationAlign" forKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN]];
      [serviceNameByIdentifier setObject:@"serviceLatexisationAlignAndPutIntoClipBoard" forKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD]];

      enumerator = [currentServicesInInfoPlist objectEnumerator];
      NSDictionary* service = nil;
      BOOL didEncounterEqnarray = NO;
      while((service = [enumerator nextObject]))
      {
        NSString* message  = [service objectForKey:@"NSMessage"];
        NSString* shortcutDefault = [[service objectForKey:@"NSKeyEquivalent"] objectForKey:@"default"];
        NSString* shortcutWhenEnabled = [[service objectForKey:@"NSKeyEquivalent"] objectForKey:@"whenEnabled"];
        NSNumber* enabled = [NSNumber numberWithBool:
                              (shortcutDefault && shortcutWhenEnabled && [shortcutDefault isEqualToString:shortcutWhenEnabled])];
        NSNumber* identifier = [identifiersByServiceName objectForKey:message];
        didEncounterEqnarray |= [message isEqualToString:@"serviceLatexisationEqnarray"] ||
                                [message isEqualToString:@"serviceLatexisationEqnarrayAndPutIntoClipBoard"];
        NSMutableDictionary* serviceEntry = !identifier ? nil : [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:identifier];
        [serviceEntry setObject:enabled forKey:ServiceShortcutEnabledKey];
        [serviceEntry setObject:(shortcutDefault ? shortcutDefault : @"") forKey:ServiceShortcutStringKey];
      }//end for each service of info.plist
      NSArray* equivalentUserDefaultsToCurrentServicesInInfoPlist =
        [NSArray arrayWithObjects:
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE_CLIPBOARD]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT_CLIPBOARD]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_MULTILATEXIZE]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_MULTILATEXIZE_CLIPBOARD]],
          [equivalentUserDefaultsToCurrentServicesInInfoPlistAsDict objectForKey:[NSNumber numberWithInt:SERVICE_DELATEXIZE]],
          nil];          

      //build services as found in user defaults
      NSMutableArray* equivalentServicesToCurrentUserDefaults = [NSMutableArray arrayWithCapacity:6];
      NSArray* standardReturnTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", @"com.apple.flat-rtfd",
                                        @"NSPasteboardTypePDF", @"NSPDFPboardType", @"com.adobe.pdf",
                                        @"NSPostScriptPboardType", @"com.adobe.encapsulated-postscript",
                                        @"NSPasteboardTypeTIFF", @"NSTIFFPboardType", @"public.tiff",
                                        @"NSPNGPboardType", @"public.png",
                                        @"public.jpeg", nil];
      NSArray* standardSendTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTF", @"NSRTFPboardType", @"public.rtf",
                                        @"NSPasteboardTypePDF", @"NSPDFPboardType", @"com.adobe.pdf",
                                        @"NSPasteboardTypeString", @"NSStringPboardType", @"public.utf8-plain-text", nil];
      NSArray* multiLatexisationReturnTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", @"com.apple.flat-rtfd", nil];
      NSArray* multiLatexisationSendTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", @"com.apple.flat-rtfd", @"NSRTFPboardType", @"public.rtf", nil];
      NSArray* deLatexisationReturnTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", @"com.apple.flat-rtfd",
                                                                     @"NSPasteboardTypePDF", @"NSPDFPboardType", @"com.adobe.pdf",
                                                                     @"NSPasteboardTypeRTF", @"NSRTFPboardType", @"public.rtf", nil];
      NSArray* deLatexisationSendTypes = [NSArray arrayWithObjects:@"NSPasteboardTypeRTFD", @"NSRTFDPboardType", @"com.apple.flat-rtfd", @"NSPasteboardTypePDF", @"NSPDFPboardType", @"com.adobe.pdf", nil];
      NSDictionary* returnTypesByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        standardReturnTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN],
        standardReturnTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD],
        standardReturnTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY],
        standardReturnTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD],
        standardReturnTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE],
        standardReturnTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE_CLIPBOARD],
        standardReturnTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT],
        standardReturnTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT_CLIPBOARD],
        multiLatexisationReturnTypes, [NSNumber numberWithInt:SERVICE_MULTILATEXIZE],
        multiLatexisationReturnTypes, [NSNumber numberWithInt:SERVICE_MULTILATEXIZE_CLIPBOARD],
        deLatexisationReturnTypes, [NSNumber numberWithInt:SERVICE_DELATEXIZE],
        nil];
      NSDictionary* sendTypesByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        standardSendTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN],
        standardSendTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD],
        standardSendTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY],
        standardSendTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD],
        standardSendTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE],
        standardSendTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE_CLIPBOARD],
        standardSendTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT],
        standardSendTypes, [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT_CLIPBOARD],
        multiLatexisationSendTypes, [NSNumber numberWithInt:SERVICE_MULTILATEXIZE],
        multiLatexisationSendTypes, [NSNumber numberWithInt:SERVICE_MULTILATEXIZE_CLIPBOARD],
        deLatexisationSendTypes, [NSNumber numberWithInt:SERVICE_DELATEXIZE],
        nil];
      NSDictionary* serviceDescriptionsByServiceIdentifier = [NSDictionary dictionaryWithObjectsAndKeys:
        @"SERVICE_DESCRIPTION_ALIGN", [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN],
        @"SERVICE_DESCRIPTION_ALIGN_CLIPBOARD", [NSNumber numberWithInt:SERVICE_LATEXIZE_ALIGN_CLIPBOARD],
        @"SERVICE_DESCRIPTION_DISPLAY", [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY],
        @"SERVICE_DESCRIPTION_DISPLAY_CLIPBOARD", [NSNumber numberWithInt:SERVICE_LATEXIZE_DISPLAY_CLIPBOARD],
        @"SERVICE_DESCRIPTION_INLINE", [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE],
        @"SERVICE_DESCRIPTION_INLINE_CLIPBOARD", [NSNumber numberWithInt:SERVICE_LATEXIZE_INLINE_CLIPBOARD],
        @"SERVICE_DESCRIPTION_TEXT", [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT],
        @"SERVICE_DESCRIPTION_TEXT_CLIPBOARD", [NSNumber numberWithInt:SERVICE_LATEXIZE_TEXT_CLIPBOARD],
        @"SERVICE_DESCRIPTION_MULTIPLE", [NSNumber numberWithInt:SERVICE_MULTILATEXIZE],
        @"SERVICE_DESCRIPTION_MULTIPLE_CLIPBOARD", [NSNumber numberWithInt:SERVICE_MULTILATEXIZE_CLIPBOARD],
        @"SERVICE_DESCRIPTION_DELATEXISATION", [NSNumber numberWithInt:SERVICE_DELATEXIZE],
        nil];
      
      
      NSArray* currentServiceShortcuts = [self serviceShortcuts];
      enumerator = [currentServiceShortcuts objectEnumerator];
      service = nil;
      while((service = [enumerator nextObject]))
      {
        NSNumber* serviceIdentifier  = [service objectForKey:ServiceShortcutIdentifierKey];
        NSString* serviceTitle       = [self serviceDescriptionForIdentifier:(service_identifier_t)[serviceIdentifier intValue]];
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
            [@30000 stringValue], @"NSTimeOut",
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
          [[alert addButtonWithTitle:NSLocalizedString(@"Ignore", @"Ignore")] setKeyEquivalent:@"\033"];//escape
          
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
              const char* args[] = {[src UTF8String], [dst UTF8String], NULL};
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
              [[alert addButtonWithTitle:NSLocalizedString(@"Ignore",@"Ignore")] setKeyEquivalent:@"\033"];
              
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
              [self setServiceShortcuts:equivalentUserDefaultsToCurrentServicesInInfoPlist];
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
