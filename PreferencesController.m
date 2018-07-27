//  PreferencesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import "PreferencesController.h"

#import "AppController.h"
#import "CompositionConfigurationManager.h"
#import "EncapsulationManager.h"
#import "EncapsulationTableView.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSPopUpButtonExtended.h"
#import "NSSegmentedControlExtended.h"
#import "LibraryManager.h"
#import "LibraryTableView.h"
#import "LineCountTextView.h"
#import "MyDocument.h"
#import "SMLSyntaxColouring.h"
#import "ServiceShortcutsTextView.h"
#import "TextShortcutsManager.h"
#import "Utils.h"

NSString* SpellCheckingDidChangeNotification = @"LaTeXiT_SpellCheckingDidChangeNotification";

NSString* GeneralToolbarItemIdentifier     = @"GeneralToolbarItem";
NSString* EditionToolbarItemIdentifier     = @"EditionToolbarItem";
NSString* PreambleToolbarItemIdentifier    = @"PreambleToolbarItem";
NSString* CompositionToolbarItemIdentifier = @"CompositionToolbarItem";
NSString* ServiceToolbarItemIdentifier     = @"ServiceToolbarItem";
NSString* AdvancedToolbarItemIdentifier    = @"AdvancedToolbarItem";
NSString* WebToolbarItemIdentifier         = @"WebToolbarItem";

NSString* DragExportTypeKey             = @"LaTeXiT_DragExportTypeKey";
NSString* DragExportJpegColorKey        = @"LaTeXiT_DragExportJpegColorKey";
NSString* DragExportJpegQualityKey      = @"LaTeXiT_DragExportJpegQualityKey";
NSString* DragExportScaleAsPercentKey   = @"LateXiT_DragExportScaleAsPercentKey";
NSString* DefaultImageViewBackgroundKey = @"LaTeXiT_DefaultImageViewBackground";
NSString* DefaultAutomaticHighContrastedPreviewBackgroundKey = @"LaTeXiT_DefaultAutomaticHighContrastedPreviewBackgroundKey";
NSString* DefaultColorKey               = @"LaTeXiT_DefaultColorKey";
NSString* DefaultPointSizeKey           = @"LaTeXiT_DefaultPointSizeKey";
NSString* DefaultModeKey                = @"LaTeXiT_DefaultModeKey";

NSString* SpellCheckingEnableKey               = @"LaTeXiT_SpellCheckingEnableKey";
NSString* SyntaxColoringEnableKey              = @"LaTeXiT_SyntaxColoringEnableKey";
NSString* SyntaxColoringTextForegroundColorKey = @"LaTeXiT_SyntaxColoringTextForegroundColorKey";
NSString* SyntaxColoringTextBackgroundColorKey = @"LaTeXiT_SyntaxColoringTextBackgroundColorKey";
NSString* SyntaxColoringCommandColorKey        = @"LaTeXiT_SyntaxColoringCommandColorKey";
NSString* SyntaxColoringMathsColorKey          = @"LaTeXiT_SyntaxColoringMathsColorKey";
NSString* SyntaxColoringKeywordColorKey        = @"LaTeXiT_SyntaxColoringKeywordColorKey";
NSString* SyntaxColoringCommentColorKey        = @"LaTeXiT_SyntaxColoringCommentColorKey";
NSString* ReducedTextAreaStateKey              = @"LaTeXiT_ReducedTextAreaStateKey";

NSString* DefaultPreambleAttributedKey = @"LaTeXiT_DefaultPreambleAttributedKey";
NSString* DefaultFontKey               = @"LaTeXiT_DefaultFontKey";

NSString* ServiceShortcutEnabledKey    = @"LaTeXiT_ServiceShortcutEnabledKey";
NSString* ServiceShortcutStringsKey    = @"LaTeXiT_ServiceShortcutStringsKey";
NSString* ServiceRespectsBaselineKey   = @"LaTeXiT_ServiceRespectsBaselineKey";
NSString* ServiceRespectsPointSizeKey  = @"LaTeXiT_ServiceRespectsPointSizeKey";
NSString* ServiceRespectsColorKey      = @"LaTeXiT_ServiceRespectsColorKey";
NSString* ServiceUsesHistoryKey        = @"LaTeXiT_ServiceUsesHistoryKey";
NSString* AdditionalTopMarginKey       = @"LaTeXiT_AdditionalTopMarginKey";
NSString* AdditionalLeftMarginKey      = @"LaTeXiT_AdditionalLeftMarginKey";
NSString* AdditionalRightMarginKey     = @"LaTeXiT_AdditionalRightMarginKey";
NSString* AdditionalBottomMarginKey    = @"LaTeXiT_AdditionalBottomMarginKey";
NSString* EncapsulationsKey            = @"LaTeXiT_EncapsulationsKey";
NSString* CurrentEncapsulationIndexKey = @"LaTeXiT_CurrentEncapsulationIndexKey";
NSString* TextShortcutsKey             = @"LaTeXiT_TextShortcutsKey";

NSString* CurrentCompositionConfigurationIndexKey    = @"LaTeXiT_CurrentCompositionConfigurationIndexKey";
NSString* CompositionConfigurationsKey               = @"LaTeXiT_CompositionConfigurationsKey";
NSString* CompositionConfigurationNameKey            = @"LaTeXiT_CompositionConfigurationNameKey";
NSString* CompositionConfigurationIsDefaultKey       = @"LaTeXiT_CompositionConfigurationIsDefaultKey";
NSString* CompositionConfigurationCompositionModeKey = @"LaTeXiT_CompositionConfigurationCompositionModeKey";
NSString* CompositionConfigurationPdfLatexPathKey    = @"LaTeXiT_CompositionConfigurationPdfLatexPathKey";
NSString* CompositionConfigurationPs2PdfPathKey      = @"LaTeXiT_CompositionConfigurationPs2PdfPathKey";
NSString* CompositionConfigurationXeLatexPathKey     = @"LaTeXiT_CompositionConfigurationXeLatexPathKey";
NSString* CompositionConfigurationLatexPathKey       = @"LaTeXiT_CompositionConfigurationLatexPathKey";
NSString* CompositionConfigurationDvipdfPathKey      = @"LaTeXiT_CompositionConfigurationDvipdfPathKey";
NSString* CompositionConfigurationGsPathKey          = @"LaTeXiT_CompositionConfigurationGsPathKey";

/*-----------------------------*/
/* deprecated in LateXiT 1.8.0 */
static NSString* CompositionModeKey           = @"LaTeXiT_CompositionModeKey";
static NSString* PdfLatexPathKey              = @"LaTeXiT_PdfLatexPathKey";
static NSString* Ps2PdfPathKey                = @"LaTeXiT_Ps2PdfPathKey";
static NSString* XeLatexPathKey               = @"LaTeXiT_XeLatexPathKey";
static NSString* LatexPathKey                 = @"LaTeXiT_LatexPathKey";
static NSString* DvipdfPathKey                = @"LaTeXiT_DvipdfPathKey";
static NSString* GsPathKey                    = @"LaTeXiT_GsPathKey";
/*-----------------------------*/

NSString* CompositionConfigurationAdditionalProcessingScriptsKey = @"LaTeXiT_CompositionConfigurationAdditionalProcessingScriptsKey";
NSString* LastEasterEggsDatesKey       = @"LaTeXiT_LastEasterEggsDatesKey";

NSString* CompositionConfigurationControllerVisibleAtStartupKey = @"CompositionConfigurationControllerVisibleAtStartupKey";
NSString* EncapsulationControllerVisibleAtStartupKey = @"EncapsulationControllerVisibleAtStartupKey";
NSString* HistoryControllerVisibleAtStartupKey       = @"HistoryControllerVisibleAtStartupKey";
NSString* LatexPalettesControllerVisibleAtStartupKey = @"LatexPalettesControllerVisibleAtStartupKey";
NSString* LibraryControllerVisibleAtStartupKey       = @"LibraryControllerVisibleAtStartupKey";
NSString* MarginControllerVisibleAtStartupKey        = @"MarginControllerVisibleAtStartupKey";

NSString* LibraryViewRowTypeKey = @"LibraryViewRowTypeKey";
NSString* LibraryDisplayPreviewPanelKey = @"LibraryDisplayPreviewPanelKey";
NSString* HistoryDisplayPreviewPanelKey = @"HistoryDisplayPreviewPanelKey";

NSString* CheckForNewVersionsKey = @"LaTeXiT_CheckForNewVersionsKey";

NSString* LatexPaletteGroupKey        = @"LaTeXiT_LatexPaletteGroupKey";
NSString* LatexPaletteFrameKey        = @"LaTeXiT_LatexPaletteFrameKey";
NSString* LatexPaletteDetailsStateKey = @"LaTeXiT_LatexPaletteDetailsStateKey";

NSString* ScriptEnabledKey               = @"LaTeXiT_ScriptEnabledKey";
NSString* ScriptSourceTypeKey            = @"LaTeXiT_ScriptSourceTypeKey";
NSString* ScriptShellKey                 = @"LaTeXiT_ScriptShellKey";
NSString* ScriptBodyKey                  = @"LaTeXiT_ScriptBodyKey";
NSString* ScriptFileKey                  = @"LaTeXiT_ScriptFileKey";

NSString* SomePathDidChangeNotification        = @"SomePathDidChangeNotification"; //changing the path to an executable (like pdflatex)
NSString* CompositionModeDidChangeNotification = @"CompositionModeDidChangeNotification";
NSString* CurrentCompositionConfigurationDidChangeNotification = @"CurrentCompositionConfigurationDidChangeNotification";

@interface PreferencesController (PrivateAPI)
-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification;
-(void) _updateButtonStates:(NSNotification*)notification;
-(void) tableViewSelectionDidChange:(NSNotification*)notification;
-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode  contextInfo:(void*)contextInfo;
@end

@implementation PreferencesController

static NSAttributedString* factoryDefaultPreamble = nil;
static PreferencesController* sharedController = nil;

+(PreferencesController*) sharedController
{
  return sharedController;
}

+(NSDictionary*) defaultAdditionalScript
{
  return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], ScriptEnabledKey,
                                               [NSNumber numberWithInt:SCRIPT_SOURCE_STRING], ScriptSourceTypeKey,
                                               @"/bin/sh", ScriptShellKey,
                                               @"", ScriptBodyKey,
                                               @"", ScriptFileKey,
                                               nil];
}

+(NSDictionary*) defaultAdditionalScripts
{
  NSDictionary* noScript = [self defaultAdditionalScript];
  return [NSDictionary dictionaryWithObjectsAndKeys:noScript, [NSString stringWithFormat:@"%d",SCRIPT_PLACE_PREPROCESSING],
                                                    noScript, [NSString stringWithFormat:@"%d",SCRIPT_PLACE_MIDDLEPROCESSING],
                                                    noScript, [NSString stringWithFormat:@"%d",SCRIPT_PLACE_POSTPROCESSING],
                                                    nil];
}

+(id) currentCompositionConfigurationObjectForKey:(id)key
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  int compositionConfigurationIndex = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
  NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
  NSDictionary* configuration = [compositionConfigurations objectAtIndex:compositionConfigurationIndex];
  return [configuration objectForKey:key];
}

+(void) currentCompositionConfigurationSetObject:(id)object forKey:(id)key
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  int compositionConfigurationIndex = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
  NSMutableArray* compositionConfigurations = [NSMutableArray arrayWithArray:[userDefaults arrayForKey:CompositionConfigurationsKey]];
  NSMutableDictionary* compositionConfiguration = [NSMutableDictionary dictionaryWithDictionary:[compositionConfigurations objectAtIndex:compositionConfigurationIndex]];
  [compositionConfiguration setObject:object forKey:key];
  [compositionConfigurations replaceObjectAtIndex:compositionConfigurationIndex withObject:compositionConfiguration];
  [userDefaults setObject:compositionConfigurations forKey:CompositionConfigurationsKey];
}

+(void) initialize
{
  NSFont* defaultFont = [NSFont fontWithName:@"Monaco" size:12];
  if (!defaultFont)
    defaultFont = [NSFont userFontOfSize:0];
  NSData* defaultFontAsData = [defaultFont data];

  if (!factoryDefaultPreamble)
  {
    NSString* factoryDefaultPreambleString = [NSString stringWithFormat:
      @"\\documentclass[10pt]{article}\n"\
      @"\\usepackage{color} %%%@\n"\
      @"\\usepackage{amssymb} %%maths\n"\
      @"\\usepackage{amsmath} %%maths\n"\
      @"\\usepackage[utf8]{inputenc} %%%@\n",
      NSLocalizedString(@"used for font color", @"used for font color"),
      NSLocalizedString(@"useful to type directly accentuated characters",
                        @"useful to type directly accentuated characters")];
    NSDictionary* attributes = [NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName];
    factoryDefaultPreamble = [[NSAttributedString alloc] initWithString:factoryDefaultPreambleString attributes:attributes];
  }

  NSData* factoryDefaultPreambleData =
    [factoryDefaultPreamble RTFFromRange:NSMakeRange(0, [factoryDefaultPreamble length]) documentAttributes:nil];

  NSNumber* numberYes = [NSNumber numberWithBool:YES];

  NSMutableDictionary* additionalProcessingScripts = [NSMutableDictionary dictionaryWithDictionary:[self defaultAdditionalScripts]];
                                                      
  NSDictionary* defaultCompositionConfiguration =
    [NSDictionary dictionaryWithObjectsAndKeys:
       NSLocalizedString(@"default", @"default"), CompositionConfigurationNameKey,
       [NSNumber numberWithBool:YES], CompositionConfigurationIsDefaultKey,
       [NSNumber numberWithInt:COMPOSITION_MODE_PDFLATEX], CompositionConfigurationCompositionModeKey,
       @"", CompositionConfigurationPdfLatexPathKey,
       @"", CompositionConfigurationXeLatexPathKey,
       @"", CompositionConfigurationLatexPathKey,
       @"", CompositionConfigurationDvipdfPathKey,
       @"", CompositionConfigurationGsPathKey,
       @"", CompositionConfigurationPs2PdfPathKey,
       additionalProcessingScripts, CompositionConfigurationAdditionalProcessingScriptsKey,
       nil];

  NSMutableArray* defaultTextShortcuts = [NSMutableArray array];
  {
    NSString*  textShortcutsPlistPath = [[NSBundle mainBundle] pathForResource:@"textShortcuts" ofType:@"plist"];
    NSData*    dataTextShortcutsPlist = [NSData dataWithContentsOfFile:textShortcutsPlistPath];
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    NSString* errorString = nil;
    NSDictionary* plist = [NSPropertyListSerialization propertyListFromData:dataTextShortcutsPlist
                                                           mutabilityOption:NSPropertyListImmutable
                                                                     format:&format errorDescription:&errorString];
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

  NSDictionary* defaults =
    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:EXPORT_FORMAT_PDF], DragExportTypeKey,
                                               [[NSColor whiteColor] data],      DragExportJpegColorKey,
                                               [NSNumber numberWithFloat:100],   DragExportJpegQualityKey,
                                               [NSNumber numberWithFloat:100],   DragExportScaleAsPercentKey,
                                               [[NSColor whiteColor] data],      DefaultImageViewBackgroundKey,
                                               [NSNumber numberWithBool:NO],     DefaultAutomaticHighContrastedPreviewBackgroundKey,
                                               [[NSColor  blackColor]   data],   DefaultColorKey,
                                               [NSNumber numberWithDouble:36.0], DefaultPointSizeKey,
                                               [NSNumber numberWithInt:LATEX_MODE_EQNARRAY], DefaultModeKey,
                                               [NSNumber numberWithBool:YES], SpellCheckingEnableKey,
                                               [NSNumber numberWithBool:YES], SyntaxColoringEnableKey,
                                               [[NSColor blackColor]   data], SyntaxColoringTextForegroundColorKey,
                                               [[NSColor whiteColor]   data], SyntaxColoringTextBackgroundColorKey,
                                               [[NSColor blueColor]    data], SyntaxColoringCommandColorKey,
                                               [[NSColor magentaColor] data], SyntaxColoringMathsColorKey,
                                               [[NSColor blueColor]    data], SyntaxColoringKeywordColorKey,
                                               [NSNumber numberWithInt:NSOffState], ReducedTextAreaStateKey,
                                               [[NSColor colorWithCalibratedRed:0 green:128./255. blue:64./255. alpha:1] data], SyntaxColoringCommentColorKey,
                                               factoryDefaultPreambleData, DefaultPreambleAttributedKey,
                                               defaultFontAsData, DefaultFontKey,
                                               [NSArray arrayWithObjects:numberYes, numberYes, numberYes, numberYes, numberYes, numberYes, nil], ServiceShortcutEnabledKey,
                                               [NSArray arrayWithObjects:@"", @"", @"", @"", @"", @"", nil], ServiceShortcutStringsKey,
                                               [NSNumber numberWithBool:YES], ServiceRespectsBaselineKey,
                                               [NSNumber numberWithBool:YES], ServiceRespectsPointSizeKey,
                                               [NSNumber numberWithBool:YES], ServiceRespectsColorKey,
                                               [NSNumber numberWithBool:NO], ServiceUsesHistoryKey,
                                               [NSNumber numberWithFloat:0], AdditionalTopMarginKey,
                                               [NSNumber numberWithFloat:0], AdditionalLeftMarginKey,
                                               [NSNumber numberWithFloat:0], AdditionalRightMarginKey,
                                               [NSNumber numberWithFloat:0], AdditionalBottomMarginKey,
                                               [NSArray arrayWithObjects:@"@", @"#", @"\\label{@}", @"\\ref{@}", @"$#$",
                                                                         @"\\[#\\]", @"\\begin{equation}#\\label{@}\\end{equation}",
                                                                         nil], EncapsulationsKey,
                                               [NSNumber numberWithUnsignedInt:0], CurrentEncapsulationIndexKey,
                                               defaultTextShortcuts, TextShortcutsKey,
                                               [NSArray arrayWithObject:defaultCompositionConfiguration], CompositionConfigurationsKey,
                                               [NSNumber numberWithUnsignedInt:0], CurrentCompositionConfigurationIndexKey,
                                               [NSNumber numberWithBool:YES], CheckForNewVersionsKey,
                                               [NSNumber numberWithBool:NO], CompositionConfigurationControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], EncapsulationControllerVisibleAtStartupKey,
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
                                               nil];

  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults registerDefaults:defaults];
  
  //from version >= 1.6.0, the export format is no more stored as a string but with an number
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
    else
      exportFormat = [NSNumber numberWithInt:EXPORT_FORMAT_PDF];
    [userDefaults setObject:exportFormat forKey:DragExportTypeKey];
  }
  
  //from version >= 1.7.0, one service has been added at the beginning
  //from version >= 1.8.1, one service has been added at the end
  //from version >= 1.13.0, one service has been added at the end
  NSMutableArray* serviceShortcutStrings = [NSMutableArray arrayWithArray:[userDefaults arrayForKey:ServiceShortcutStringsKey]];
  while ([serviceShortcutStrings count] < 4)
    [serviceShortcutStrings insertObject:@"" atIndex:0];
  while ([serviceShortcutStrings count] < 5)
    [serviceShortcutStrings addObject:@""];
  while ([serviceShortcutStrings count] < 6)
    [serviceShortcutStrings addObject:@""];
  [userDefaults setObject:serviceShortcutStrings forKey:ServiceShortcutStringsKey];
  NSMutableArray* serviceShortcutEnabled = [NSMutableArray arrayWithArray:[userDefaults arrayForKey:ServiceShortcutEnabledKey]];
  while ([serviceShortcutEnabled count] < 4)
    [serviceShortcutEnabled insertObject:numberYes atIndex:0];
  while ([serviceShortcutEnabled count] < 5)
    [serviceShortcutEnabled addObject:numberYes];
  while ([serviceShortcutEnabled count] < 6)
    [serviceShortcutEnabled addObject:numberYes];
  [userDefaults setObject:serviceShortcutEnabled forKey:ServiceShortcutEnabledKey];
  
  //ensure at least one default config
  NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
  int      currentCompositionConfigurationIndex = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
  if (![compositionConfigurations count])
    compositionConfigurations = [NSArray arrayWithObject:defaultCompositionConfiguration];
  currentCompositionConfigurationIndex = MIN((int)[compositionConfigurations count]-1, currentCompositionConfigurationIndex);
  [userDefaults setObject:compositionConfigurations forKey:CompositionConfigurationsKey];
  [userDefaults setInteger:currentCompositionConfigurationIndex forKey:CurrentCompositionConfigurationIndexKey];
  
  //from version >= 1.8.0, the initial composition configuration is deported into the default config
  id object = nil;
  if ((object = [userDefaults objectForKey:CompositionModeKey]))
  {
    [self currentCompositionConfigurationSetObject:object forKey:CompositionConfigurationCompositionModeKey];
    [userDefaults removeObjectForKey:CompositionModeKey];
  }
  if ((object = [userDefaults objectForKey:PdfLatexPathKey]))
  {
    [self currentCompositionConfigurationSetObject:object forKey:CompositionConfigurationPdfLatexPathKey];
    [userDefaults removeObjectForKey:PdfLatexPathKey];
  }
  if ((object = [userDefaults objectForKey:XeLatexPathKey]))
  {
    [self currentCompositionConfigurationSetObject:object forKey:CompositionConfigurationXeLatexPathKey];
    [userDefaults removeObjectForKey:XeLatexPathKey];
  }
  if ((object = [userDefaults objectForKey:LatexPathKey]))
  {
    [self currentCompositionConfigurationSetObject:object forKey:CompositionConfigurationLatexPathKey];
    [userDefaults removeObjectForKey:LatexPathKey];
  }
  if ((object = [userDefaults objectForKey:DvipdfPathKey]))
  {
    [self currentCompositionConfigurationSetObject:object forKey:CompositionConfigurationDvipdfPathKey];
    [userDefaults removeObjectForKey:DvipdfPathKey];
  }
  if ((object = [userDefaults objectForKey:GsPathKey]))
  {
    [self currentCompositionConfigurationSetObject:object forKey:CompositionConfigurationGsPathKey];
    [userDefaults removeObjectForKey:GsPathKey];
  }
  if ((object = [userDefaults objectForKey:Ps2PdfPathKey]))
  {
    [self currentCompositionConfigurationSetObject:object forKey:CompositionConfigurationPs2PdfPathKey];
    [userDefaults removeObjectForKey:Ps2PdfPathKey];
  }
}

-(id) init
{
  if (![super initWithWindowNibName:@"Preferences"])
    return nil;
  sharedController = self;
  toolbarItems = [[NSMutableDictionary alloc] init];
  warningImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:@"warning"]];
  shortcutTextView = [[ServiceShortcutsTextView alloc] initWithFrame:NSMakeRect(0,0,10,10)];
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [warningImage release];
  [toolbarItems release];
  [exampleSyntaxColouring release];
  [applyPreambleToLibraryAlert release];
  [shortcutTextView release];
  [super dealloc];
}

-(NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
  return [NSArray arrayWithObjects:GeneralToolbarItemIdentifier,  EditionToolbarItemIdentifier,
                                   PreambleToolbarItemIdentifier, CompositionToolbarItemIdentifier,
                                   ServiceToolbarItemIdentifier,  AdvancedToolbarItemIdentifier,
                                   WebToolbarItemIdentifier, nil];
}

-(NSArray*) toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
  return [self toolbarDefaultItemIdentifiers:toolbar];
}

-(NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar*)toolbar
{
  return [self toolbarDefaultItemIdentifiers:toolbar];
}
 
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
  NSToolbarItem* item = [toolbarItems objectForKey:itemIdentifier];
  if (!item)
  {
    item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    
    NSString* label = nil;
    NSString* imagePath = nil;
    if ([itemIdentifier isEqualToString:GeneralToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"generalToolbarItem" ofType:@"tiff"];
      label = NSLocalizedString(@"General", @"General");
    }
    else if ([itemIdentifier isEqualToString:EditionToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"editionToolbarItem" ofType:@"tiff"];
      label = NSLocalizedString(@"Edition", @"Edition");
    }
    else if ([itemIdentifier isEqualToString:PreambleToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"preambleToolbarItem" ofType:@"tiff"];
      label = NSLocalizedString(@"Preamble", @"Preamble");
    }
    else if ([itemIdentifier isEqualToString:CompositionToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"compositionToolbarItem" ofType:@"tiff"];
      label = NSLocalizedString(@"Composition", @"Composition");
    }
    else if ([itemIdentifier isEqualToString:ServiceToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"serviceToolbarItem" ofType:@"tiff"];
      label = NSLocalizedString(@"Service", @"Service");
    }
    else if ([itemIdentifier isEqualToString:AdvancedToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"advancedToolbarItem" ofType:@"tiff"];
      label = NSLocalizedString(@"Advanced", @"Advanced");
    }
    else if ([itemIdentifier isEqualToString:WebToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"webToolbarItem" ofType:@"tiff"];
      label = NSLocalizedString(@"Web", @"Web");
    }
    [item setLabel:label];
    [item setImage:[[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease]];

    [item setTarget:self];
    [item setAction:@selector(toolbarHit:)];
    [toolbarItems setObject:item forKey:itemIdentifier];
  }
  return item;
}

-(IBAction) toolbarHit:(id)sender
{
  NSView* view = nil;
  NSString* itemIdentifier = [sender itemIdentifier];

  if ([itemIdentifier isEqualToString:GeneralToolbarItemIdentifier])
    view = generalView;
  else if ([itemIdentifier isEqualToString:EditionToolbarItemIdentifier])
    view = editionView;
  else if ([itemIdentifier isEqualToString:PreambleToolbarItemIdentifier])
    view = preambleView;
  else if ([itemIdentifier isEqualToString:CompositionToolbarItemIdentifier])
    view = compositionView;
  else if ([itemIdentifier isEqualToString:ServiceToolbarItemIdentifier])
    view = serviceView;
  else if ([itemIdentifier isEqualToString:AdvancedToolbarItemIdentifier])
    view = advancedView;
  else if ([itemIdentifier isEqualToString:WebToolbarItemIdentifier])
    view = webView;

  NSWindow* window = [self window];
  NSView*   contentView = [window contentView];
  if (view != contentView)
  {
    NSRect oldContentFrame = contentView ? [contentView frame] : NSZeroRect;
    NSRect newContentFrame = [view frame];
    NSRect newFrame = [window frame];
    newFrame.size.width  += (newContentFrame.size.width  - oldContentFrame.size.width);
    newFrame.size.height += (newContentFrame.size.height - oldContentFrame.size.height);
    newFrame.origin.y    -= (newContentFrame.size.height - oldContentFrame.size.height);
    [[window contentView] retain];
    [emptyView setFrame:newContentFrame];
    [window setContentView:emptyView];
    [window setFrame:newFrame display:YES animate:YES];
    [[window contentView] retain];
    [window setContentView:view];
  }
  
  //useful for font selection
  [window makeFirstResponder:nil];
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if ([fontManager delegate] == self)
    [fontManager setDelegate:nil];
}
//end toolbarHit:

-(void) awakeFromNib
{
  NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"preferencesToolbar"];
  [toolbar setDelegate:self];
  NSWindow* window = [self window];
  [window setToolbar:toolbar];
  #ifndef PANTHER
  [window setShowsToolbarButton:NO];
  #endif
  [toolbar setSelectedItemIdentifier:GeneralToolbarItemIdentifier];
  [self toolbarHit:[toolbarItems objectForKey:[toolbar selectedItemIdentifier]]];
  [toolbar release];
  
  exampleSyntaxColouring = [[SMLSyntaxColouring alloc] initWithTextView:exampleTextView];
}

//initializes the controls with default values
-(void) windowDidLoad
{
  NSPoint topLeftPoint   = [[self window] frame].origin;
  topLeftPoint.y += [[self window] frame].size.height;
  [[self window] setFrameAutosaveName:@"preferences"];
  [[self window] setFrameTopLeftPoint:topLeftPoint];

  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  [dragExportPopupFormat selectItemWithTag:[userDefaults integerForKey:DragExportTypeKey]];
  [self dragExportPopupFormatDidChange:dragExportPopupFormat];
  
  [dragExportScaleAsPercentTextField setFloatValue:[userDefaults floatForKey:DragExportScaleAsPercentKey]];

  [defaultImageViewBackgroundColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:DefaultImageViewBackgroundKey]]];
  
  [[defaultModeSegmentedControl cell] setTag:LATEX_MODE_EQNARRAY forSegment:0];
  [[defaultModeSegmentedControl cell] setTag:LATEX_MODE_DISPLAY forSegment:1];
  [[defaultModeSegmentedControl cell] setTag:LATEX_MODE_INLINE  forSegment:2];
  [[defaultModeSegmentedControl cell] setTag:LATEX_MODE_TEXT  forSegment:3];
  [defaultModeSegmentedControl selectSegmentWithTag:[userDefaults integerForKey:DefaultModeKey]];
  [defaultPointSizeTextField setDoubleValue:[userDefaults floatForKey:DefaultPointSizeKey]];
  [defaultColorColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:DefaultColorKey]]];

  [spellCheckingButton setState:([userDefaults boolForKey:SpellCheckingEnableKey] ? NSOnState : NSOffState)];
  [enableSyntaxColoringButton setState:([userDefaults boolForKey:SyntaxColoringEnableKey]  ? NSOnState : NSOffState)];
  [syntaxColoringTextForegroundColorColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:SyntaxColoringTextForegroundColorKey]]];
  [syntaxColoringTextBackgroundColorColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:SyntaxColoringTextBackgroundColorKey]]];
  [syntaxColoringCommandColorColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:SyntaxColoringCommandColorKey]]];
  [syntaxColoringMathsColorColorWell   setColor:[NSColor colorWithData:[userDefaults dataForKey:SyntaxColoringMathsColorKey]]];
  [syntaxColoringKeywordColorColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:SyntaxColoringKeywordColorKey]]];
  [syntaxColoringCommentColorColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:SyntaxColoringCommentColorKey]]];
  [self changeSyntaxColoringConfiguration:enableSyntaxColoringButton];
  
  [reduceTextAreaButton setState:[userDefaults integerForKey:ReducedTextAreaStateKey]];

  //[preambleTextView setDelegate:self];//No ! preambleTextView's delegate is itself to manage forbidden lines
  //[preambleTextView setForbiddenLine:0 forbidden:YES];//finally, the user is allowed to modify
  //[preambleTextView setForbiddenLine:1 forbidden:YES];//finally, the user is allowed to modify
  NSData* attributedStringData = [userDefaults objectForKey:DefaultPreambleAttributedKey];
  NSAttributedString* attributedString = [[[NSAttributedString alloc] initWithRTF:attributedStringData documentAttributes:NULL] autorelease];
  [[preambleTextView textStorage] setAttributedString:attributedString];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];
  [[preambleTextView syntaxColouring] recolourCompleteDocument];

  [self changeFont:self];//updates font textfield
  
  [pdfLatexTextField        setDelegate:self];
  [xeLatexTextField         setDelegate:self];
  [latexTextField           setDelegate:self];
  [dvipdfTextField          setDelegate:self];
  [gsTextField              setDelegate:self];
  [ps2pdfTextField          setDelegate:self];

  [scriptsScriptSelectionTextField       setDelegate:self];
  [scriptsScriptDefinitionShellTextField setDelegate:self];
  [scriptsScriptDefinitionBodyTextView   setDelegate:self];
  [scriptsScriptDefinitionBodyTextView   setFont:[NSFont fontWithName:@"Monaco" size:12.]];
  [self changeScriptsConfiguration:nil];

  [serviceRespectsPointSizeMatrix selectCellWithTag:([userDefaults boolForKey:ServiceRespectsPointSizeKey] ? 1 : 0)];
  [serviceRespectsColorMatrix     selectCellWithTag:([userDefaults boolForKey:ServiceRespectsColorKey]     ? 1 : 0)];
  [serviceRespectsBaselineButton  setState:([userDefaults boolForKey:ServiceRespectsBaselineKey]  ? NSOnState : NSOffState)];
  [serviceUsesHistoryButton       setState:([userDefaults boolForKey:ServiceUsesHistoryKey]  ? NSOnState : NSOffState)];
  [serviceWarningLinkBackButton   setHidden:([serviceRespectsBaselineButton state] == NSOffState)];
  [serviceWarningShortcutConflict setHidden:YES];
  
  [additionalTopMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
  [additionalTopMarginTextField setDelegate:self];
  [additionalLeftMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
  [additionalLeftMarginTextField setDelegate:self];
  [additionalRightMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
  [additionalRightMarginTextField setDelegate:self];
  [additionalBottomMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
  [additionalBottomMarginTextField setDelegate:self];
  
  [checkForNewVersionsButton setState:([userDefaults boolForKey:CheckForNewVersionsKey] ? NSOnState : NSOffState)];
  
  [self controlTextDidEndEditing:nil];
  [self _updateButtonStates:nil];
    
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(textDidChange:)
                             name:NSTextDidChangeNotification object:preambleTextView];
  [notificationCenter addObserver:self selector:@selector(textDidChange:)
                             name:FontDidChangeNotification object:preambleTextView];
  [notificationCenter addObserver:self selector:@selector(tableViewSelectionDidChange:)
                             name:NSTableViewSelectionDidChangeNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(_userDefaultsDidChangeNotification:)
                             name:NSUserDefaultsDidChangeNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(_updateButtonStates:)
                             name:NSTableViewSelectionDidChangeNotification object:encapsulationTableView];
  [notificationCenter addObserver:self selector:@selector(_updateButtonStates:)
                             name:NSTableViewSelectionDidChangeNotification object:textShortcutsTableView];
  [notificationCenter addObserver:self selector:@selector(_updateButtonStates:)
                             name:NSTableViewSelectionDidChangeNotification object:compositionConfigurationTableView];
  [notificationCenter addObserver:self selector:@selector(_updateButtonStates:)
                             name:CompositionConfigurationsDidChangeNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(_updateButtonStates:)
                             name:CurrentCompositionConfigurationDidChangeNotification object:nil];
}

-(void) windowWillClose:(NSNotification *)aNotification
{
  //useful for font selection
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if ([fontManager delegate] == self)
    [fontManager setDelegate:nil];
}

//image exporting
-(IBAction) openOptionsForDragExport:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [dragExportJpegQualitySlider setFloatValue:[userDefaults floatForKey:DragExportJpegQualityKey]];
  [dragExportJpegQualityTextField setFloatValue:[dragExportJpegQualitySlider floatValue]];
  [dragExportJpegColorWell setColor:[NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]]];
  [NSApp runModalForWindow:dragExportOptionsPane];
}

//close option pane of the image export
-(IBAction) closeOptionsPane:(id)sender
{
  if ([sender tag] == 0) //OK
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setFloat:[dragExportJpegQualitySlider floatValue] forKey:DragExportJpegQualityKey];
    [userDefaults setObject:[[dragExportJpegColorWell color] data] forKey:DragExportJpegColorKey];
  }
  [NSApp stopModal];
  [dragExportOptionsPane orderOut:self];
}

-(IBAction) dragExportJpegQualitySliderDidChange:(id)sender
{
  [dragExportJpegQualityTextField setFloatValue:[sender floatValue]];
}

//when the export format changes, it may show a warning about JPEG
-(IBAction) dragExportPopupFormatDidChange:(id)sender
{
  BOOL allowOptions = NO;
  export_format_t exportFormat = [sender selectedTag];
  if (exportFormat == EXPORT_FORMAT_JPEG)
  {
    allowOptions = YES;
    [dragExportJpegWarning setHidden:NO];
  }
  else
  {
    allowOptions = NO;
    [dragExportJpegWarning setHidden:YES];
  }
  
  [dragExportOptionsButton setEnabled:allowOptions];
  [[NSUserDefaults standardUserDefaults] setInteger:exportFormat forKey:DragExportTypeKey];
}

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok  = YES;
  if ([sender tag] == EXPORT_FORMAT_EPS)
    ok = [[AppController appController] isGsAvailable];
  else if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[AppController appController] isGsAvailable] && [[AppController appController] isPs2PdfAvailable];
  return ok;
}

//handles default color, point size, and mode
-(IBAction) changeDefaultGeneralConfig:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == defaultImageViewBackgroundColorWell)
  {
    NSColor* color = [defaultImageViewBackgroundColorWell color];
    [userDefaults setObject:[color data] forKey:DefaultImageViewBackgroundKey];
  }
  else if (sender == defaultColorColorWell)
    [userDefaults setObject:[[defaultColorColorWell color] data] forKey:DefaultColorKey];
  else if (sender == defaultPointSizeTextField)
    [userDefaults setFloat:[defaultPointSizeTextField doubleValue] forKey:DefaultPointSizeKey];
  else if (sender == defaultModeSegmentedControl)
    [userDefaults setInteger:[[defaultModeSegmentedControl cell] tagForSegment:[defaultModeSegmentedControl selectedSegment]]
                      forKey:DefaultModeKey];
}

//updates the user defaults as the user is typing. Not very efficient, but textDidEndEditing was not working properly
-(void)textDidChange:(NSNotification *)aNotification
{
  if ([aNotification object] == preambleTextView)
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSAttributedString* attributedString = [preambleTextView textStorage];
    [userDefaults setObject:[attributedString RTFFromRange:NSMakeRange(0, [attributedString length]) documentAttributes:nil]
                     forKey:DefaultPreambleAttributedKey];
  }
  else if ([aNotification object] == scriptsScriptDefinitionBodyTextView)
    [self changeScriptsConfiguration:scriptsScriptDefinitionBodyTextView];
}

-(IBAction) changeSpellChecking:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == spellCheckingButton)
  {
    [userDefaults setBool:([spellCheckingButton state] == NSOnState) forKey:SpellCheckingEnableKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SpellCheckingDidChangeNotification object:nil];
  }
}

-(IBAction) changeSyntaxColoringConfiguration:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == enableSyntaxColoringButton)
  {
    BOOL enabled = ([sender state] == NSOnState);
    [syntaxColoringCommandColorColorWell setEnabled:enabled];
    [syntaxColoringMathsColorColorWell   setEnabled:enabled];
    [syntaxColoringKeywordColorColorWell setEnabled:enabled];
    [syntaxColoringCommentColorColorWell setEnabled:enabled];
    [userDefaults setBool:enabled forKey:SyntaxColoringEnableKey];
  }
  else if (sender == syntaxColoringTextForegroundColorColorWell)
    [userDefaults setObject:[[sender color] data] forKey:SyntaxColoringTextForegroundColorKey];
  else if (sender == syntaxColoringTextBackgroundColorColorWell)
    [userDefaults setObject:[[sender color] data] forKey:SyntaxColoringTextBackgroundColorKey];
  else if (sender == syntaxColoringCommandColorColorWell)
    [userDefaults setObject:[[sender color] data] forKey:SyntaxColoringCommandColorKey];
  else if (sender == syntaxColoringMathsColorColorWell)
    [userDefaults setObject:[[sender color] data] forKey:SyntaxColoringMathsColorKey];
  else if (sender == syntaxColoringKeywordColorColorWell)
    [userDefaults setObject:[[sender color] data] forKey:SyntaxColoringKeywordColorKey];
  else if (sender == syntaxColoringCommentColorColorWell)
    [userDefaults setObject:[[sender color] data] forKey:SyntaxColoringCommentColorKey];
  [[preambleTextView syntaxColouring] setColours];
  [[preambleTextView syntaxColouring] recolourCompleteDocument];
  [preambleTextView setNeedsDisplay:YES];
  [exampleSyntaxColouring setColours];
  [exampleSyntaxColouring recolourCompleteDocument];
  [exampleTextView setNeedsDisplay:YES];
  [[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(resetSyntaxColoring)];
}
//end changeSyntaxColoringConfiguration:

-(IBAction) changeReduceTextArea:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setInteger:[sender state] forKey:ReducedTextAreaStateKey];
  //change the area size
  NSEnumerator* documentsEnumerator = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
  MyDocument* myDocument = nil;
  while ((myDocument = [documentsEnumerator nextObject]))
    [myDocument setReducedTextArea:([userDefaults integerForKey:ReducedTextAreaStateKey] == NSOnState)];
}
//end changeReduceTextArea:

-(IBAction) resetDefaultPreamble:(id)sender
{
  [[preambleTextView textStorage] setAttributedString:factoryDefaultPreamble];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];
  [[preambleTextView syntaxColouring] recolourCompleteDocument];
  [preambleTextView setNeedsDisplay:YES];
}
//end resetDefaultPreamble:

-(IBAction) selectFont:(id)sender
{
  [[self window] makeFirstResponder:nil]; //to remove first responder from the preambleview
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  [fontManager orderFrontFontPanel:self];
  [fontManager setDelegate:self]; //the delegate will be reset in tabView:willSelectTabViewItem: or windowWillClose:
}

-(void) changeFont:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSFont* oldFont = [NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]];
  NSFont* newFont = (sender && (sender != self)) ? [sender convertFont:oldFont] : oldFont;
  [userDefaults setObject:[newFont data] forKey:DefaultFontKey];
  [fontTextField setStringValue:[NSString stringWithFormat:@"%@ %@", [newFont fontName], [NSNumber numberWithFloat:[newFont pointSize]]]];
  [fontTextField setNeedsDisplay:YES];

  NSMutableAttributedString* example = [exampleTextView textStorage];
  [example addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [example length])];

  //if sender is nil or self, this "changeFont:" only updates fontTextField, but should not modify preambleTextView
  if (sender && (sender != self))
  {
    NSMutableAttributedString* preamble = [preambleTextView textStorage];
    [preamble addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [preamble length])];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];

    NSMutableAttributedString* example = [exampleTextView textStorage];
    [example addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [example length])];
    
    NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
    [documents makeObjectsPerformSelector:@selector(setFont:) withObject:newFont];
  }
}

-(IBAction) applyPreambleToOpenDocuments:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
  [documents makeObjectsPerformSelector:@selector(setPreamble:) withObject:[[[preambleTextView textStorage] mutableCopy] autorelease]];
  [documents makeObjectsPerformSelector:@selector(setFont:) withObject:[NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]]];
}

-(IBAction) applyPreambleToLibrary:(id)sender
{
  if (!applyPreambleToLibraryAlert)
  {
    applyPreambleToLibraryAlert = [[NSAlert alloc] init];
    [applyPreambleToLibraryAlert setMessageText:NSLocalizedString(@"Do you really want to apply that preamble to the library items ?",
                                                                  @"Do you really want to apply that preamble to the library items ?")];
    [applyPreambleToLibraryAlert setInformativeText:
      NSLocalizedString(@"Their old preamble will be overwritten. If it was a special preamble that had been tuned to generate them, it will be lost.",
                        @"Their old preamble will be overwritten. If it was a special preamble that had been tuned to generate them, it will be lost.")];
    [applyPreambleToLibraryAlert setAlertStyle:NSWarningAlertStyle];
    [applyPreambleToLibraryAlert addButtonWithTitle:NSLocalizedString(@"Apply", @"Apply")];
    [applyPreambleToLibraryAlert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
  }
  int choice = [applyPreambleToLibraryAlert runModal];
  if (choice == NSAlertFirstButtonReturn)
  {
    NSArray* historyItems = [[LibraryManager sharedManager] allValues];
    [historyItems makeObjectsPerformSelector:@selector(setPreamble:)
                                  withObject:[[[preambleTextView textStorage] mutableCopy] autorelease]];
  }
}

-(IBAction) changeCompositionMode:(id)sender
{
  if (sender == compositionMatrix)
  {
    composition_mode_t mode = (composition_mode_t) [[sender selectedCell] tag];
    [pdfLatexTextField setEnabled:(mode == COMPOSITION_MODE_PDFLATEX)];
    [pdfLatexButton    setEnabled:(mode == COMPOSITION_MODE_PDFLATEX)];
    [xeLatexTextField  setEnabled:(mode == COMPOSITION_MODE_XELATEX)];
    [xeLatexButton     setEnabled:(mode == COMPOSITION_MODE_XELATEX)];
    [latexTextField    setEnabled:(mode == COMPOSITION_MODE_LATEXDVIPDF)];
    [latexButton       setEnabled:(mode == COMPOSITION_MODE_LATEXDVIPDF)];
    [dvipdfTextField   setEnabled:(mode == COMPOSITION_MODE_LATEXDVIPDF)];
    [dvipdfButton      setEnabled:(mode == COMPOSITION_MODE_LATEXDVIPDF)];
    [self controlTextDidEndEditing:nil];
    [PreferencesController currentCompositionConfigurationSetObject:[NSNumber numberWithInt:mode]
                                                             forKey:CompositionConfigurationCompositionModeKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:CompositionModeDidChangeNotification object:self];
  }
}

//opens a panel to let the user select a file, as the new path
-(IBAction) changePath:(id)sender
{
  int tag = [sender tag];
  NSTextField* textField = nil;
  switch(tag)
  {
    case 0 : textField = pdfLatexTextField; break;
    case 1 : textField = xeLatexTextField; break;
    case 2 : textField = latexTextField; break;
    case 3 : textField = dvipdfTextField; break;
    case 4 : textField = gsTextField; break;
    case 5 : textField = ps2pdfTextField; break;
    default: break;
  }
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setResolvesAliases:NO];
  NSString* filename = [textField stringValue];
  NSString* path = filename ? filename : @"";
  path = [[NSFileManager defaultManager] fileExistsAtPath:path] ? [path stringByDeletingLastPathComponent] : nil;
  [openPanel beginSheetForDirectory:path file:[filename lastPathComponent] types:nil modalForWindow:[self window] modalDelegate:self
                           didEndSelector:@selector(didEndOpenPanel:returnCode:contextInfo:) contextInfo:textField];
}

-(void) didEndOpenPanel:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if ((returnCode == NSOKButton) && contextInfo)
  {
    NSTextField* textField = (NSTextField*) contextInfo;
    NSArray* filenames = [openPanel filenames];
    if (filenames && [filenames count])
    {
      NSString* path = [filenames objectAtIndex:0];
      [textField setStringValue:path];
      NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
      [notificationCenter postNotificationName:NSControlTextDidChangeNotification object:textField];
      [notificationCenter postNotificationName:NSControlTextDidEndEditingNotification object:textField];
    }
  }
}

-(void) controlTextDidChange:(NSNotification*)aNotification
{
  NSTextField* textField = [aNotification object];
  if (textField == pdfLatexTextField)
    didChangePdfLatexTextField = YES;
  else if (textField == xeLatexTextField)
    didChangeXeLatexTextField = YES;
  else if (textField == latexTextField)
    didChangeLatexTextField = YES;
  else if (textField == dvipdfTextField)
    didChangeDvipdfTextField = YES;
  else if (textField == gsTextField)
    didChangeGsTextField = YES;
  else if (textField == ps2pdfTextField)
    didChangePs2PdfTextField = YES;
}

-(void) controlTextDidEndEditing:(NSNotification*)aNotification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSTextField* textField = [aNotification object];
  void* userInfo = [aNotification userInfo];
  BOOL isDirectory = NO;

  NSArray* pathTextFields =
    [NSArray arrayWithObjects:pdfLatexTextField, xeLatexTextField, latexTextField, dvipdfTextField, gsTextField, ps2pdfTextField,
                              scriptsScriptSelectionTextField, nil];

  //if it is a path textfield, color in red in case of invalid file
  if (!textField)//check all
  {
    NSEnumerator* enumerator = [pathTextFields objectEnumerator];
    NSTextField* theTextField = nil;
    while((theTextField = [enumerator nextObject]))
    {
      BOOL fileSeemsOk = [[NSFileManager defaultManager] fileExistsAtPath:[theTextField stringValue] isDirectory:&isDirectory] &&
                         !isDirectory;
      [theTextField setTextColor:(fileSeemsOk || ![theTextField isEnabled] ? [NSColor blackColor] : [NSColor redColor])];
    }
  }
  else if ([pathTextFields containsObject:textField])
  {
    BOOL fileSeemsOk = [[NSFileManager defaultManager] fileExistsAtPath:[textField stringValue] isDirectory:&isDirectory] &&
                       !isDirectory;
    [textField setTextColor:(fileSeemsOk ? [NSColor blackColor] : [NSColor redColor])];
  }
  
  if (textField == dragExportScaleAsPercentTextField)
  {
    [userDefaults setFloat:[textField floatValue] forKey:DragExportScaleAsPercentKey];
  }
  else if (textField == pdfLatexTextField)
  {
    if (didChangePdfLatexTextField)
    {
      [PreferencesController currentCompositionConfigurationSetObject:[textField stringValue]
                                                               forKey:CompositionConfigurationPdfLatexPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangePdfLatexTextField = NO;
  }
  else if (textField == xeLatexTextField)
  {
    if (didChangeXeLatexTextField)
    {
      [PreferencesController currentCompositionConfigurationSetObject:[textField stringValue]
                                                               forKey:CompositionConfigurationXeLatexPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangeXeLatexTextField = NO;
  }
  else if (textField == latexTextField)
  {
    if (didChangeLatexTextField)
    {
      [PreferencesController currentCompositionConfigurationSetObject:[textField stringValue]
                                                               forKey:CompositionConfigurationLatexPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangeLatexTextField = NO;
  }
  else if (textField == dvipdfTextField)
  {
    if (didChangeDvipdfTextField)
    {
      [PreferencesController currentCompositionConfigurationSetObject:[textField stringValue]
                                                               forKey:CompositionConfigurationDvipdfPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangeDvipdfTextField = NO;
  }
  else if (textField == gsTextField)
  {
    if (didChangeGsTextField)
    {
      [PreferencesController currentCompositionConfigurationSetObject:[textField stringValue]
                                                               forKey:CompositionConfigurationGsPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
      
      //export to EPS needs ghostscript to be available
      export_format_t exportFormat = [userDefaults integerForKey:DragExportTypeKey];
      if (exportFormat == EXPORT_FORMAT_EPS && ![[AppController appController] isGsAvailable])
      {
        [userDefaults setInteger:EXPORT_FORMAT_PDF forKey:DragExportTypeKey];
        [dragExportPopupFormat selectItemWithTag:[userDefaults integerForKey:DragExportTypeKey]];
        [self dragExportPopupFormatDidChange:dragExportPopupFormat];
      }
      else if (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS &&
               (![[AppController appController] isGsAvailable] || ![[AppController appController] isPs2PdfAvailable]))
      {
        [userDefaults setInteger:EXPORT_FORMAT_PDF forKey:DragExportTypeKey];
        [dragExportPopupFormat selectItemWithTag:[userDefaults integerForKey:DragExportTypeKey]];
        [self dragExportPopupFormatDidChange:dragExportPopupFormat];
      }
    }
    didChangeGsTextField = NO;
  }
  else if (textField == ps2pdfTextField)
  {
    if (didChangePs2PdfTextField)
    {
      [PreferencesController currentCompositionConfigurationSetObject:[textField stringValue]
                                                               forKey:CompositionConfigurationPs2PdfPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
      
      //export to PDF_NO_EMBEDDED_FONTS needs ps2Pdf to be available
      export_format_t exportFormat = [userDefaults integerForKey:DragExportTypeKey];
      if (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS &&
          (![[AppController appController] isGsAvailable] || ![[AppController appController] isPs2PdfAvailable]))
      {
        [userDefaults setInteger:EXPORT_FORMAT_PDF forKey:DragExportTypeKey];
        [dragExportPopupFormat selectItemWithTag:[userDefaults integerForKey:DragExportTypeKey]];
        [self dragExportPopupFormatDidChange:dragExportPopupFormat];
      }
    }
    didChangePs2PdfTextField = NO;
  }
  else if (textField == additionalTopMarginTextField)
    [userDefaults setFloat:[additionalTopMarginTextField floatValue] forKey:AdditionalTopMarginKey];
  else if (textField == additionalLeftMarginTextField)
    [userDefaults setFloat:[additionalLeftMarginTextField floatValue] forKey:AdditionalLeftMarginKey];
  else if (textField == additionalRightMarginTextField)
    [userDefaults setFloat:[additionalRightMarginTextField floatValue] forKey:AdditionalRightMarginKey];
  else if (textField == additionalBottomMarginTextField)
    [userDefaults setFloat:[additionalBottomMarginTextField floatValue] forKey:AdditionalBottomMarginKey];
  else if ((textField == scriptsScriptSelectionTextField) && !(userInfo == self))
    [self changeScriptsConfiguration:scriptsScriptSelectionTextField];
  else if ((textField == scriptsScriptDefinitionShellTextField) && !(userInfo == self))
    [self changeScriptsConfiguration:scriptsScriptDefinitionShellTextField];
}

-(IBAction) changeServiceConfiguration:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == serviceRespectsPointSizeMatrix)
    [userDefaults setBool:([[serviceRespectsPointSizeMatrix selectedCell] tag] == 1) forKey:ServiceRespectsPointSizeKey];
  else if (sender == serviceRespectsColorMatrix)
    [userDefaults setBool:([[serviceRespectsColorMatrix selectedCell] tag] == 1) forKey:ServiceRespectsColorKey];
  else if (sender == serviceRespectsBaselineButton)
  {
    BOOL selected = ([serviceRespectsBaselineButton state] == NSOnState);
    [serviceWarningLinkBackButton setHidden:!selected];
    [userDefaults setBool:selected forKey:ServiceRespectsBaselineKey];
  }
  else if (sender == serviceUsesHistoryButton)
    [userDefaults setBool:([serviceUsesHistoryButton state] == NSOnState) forKey:ServiceUsesHistoryKey];
}

-(IBAction) gotoPreferencePane:(id)sender
{
  int tag = sender ? [sender tag] : -1;
  if (tag == 0)
  {
    [self selectPreferencesPaneWithItemIdentifier:GeneralToolbarItemIdentifier];
    [[self window] makeFirstResponder:defaultPointSizeTextField];
  }
  else if (tag == 1)
  {
    [self selectPreferencesPaneWithItemIdentifier:GeneralToolbarItemIdentifier];
    [[self window] makeFirstResponder:defaultColorColorWell];
  }
}

-(IBAction) changeAdditionalMargin:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == additionalTopMarginTextField)
    [userDefaults setFloat:[additionalTopMarginTextField floatValue] forKey:AdditionalTopMarginKey];
  else if (sender == additionalLeftMarginTextField)
    [userDefaults setFloat:[additionalLeftMarginTextField floatValue] forKey:AdditionalLeftMarginKey];
  else if (sender == additionalRightMarginTextField)
    [userDefaults setFloat:[additionalRightMarginTextField floatValue] forKey:AdditionalRightMarginKey];
  else if (sender == additionalBottomMarginTextField)
    [userDefaults setFloat:[additionalBottomMarginTextField floatValue] forKey:AdditionalBottomMarginKey];
}

-(IBAction) newEncapsulation:(id)sender
{
  [[EncapsulationManager sharedManager] newEncapsulation];
  [encapsulationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[encapsulationTableView numberOfRows]-1]
                      byExtendingSelection:NO];
}

-(IBAction) removeSelectedEncapsulations:(id)sender
{
  [[EncapsulationManager sharedManager] removeEncapsulationIndexes:[encapsulationTableView selectedRowIndexes]];
}

-(IBAction) newTextShortcut:(id)sender
{
  [[TextShortcutsManager sharedManager] newTextShortcut];
  [textShortcutsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[textShortcutsTableView numberOfRows]-1]
                    byExtendingSelection:NO];
}

-(IBAction) removeSelectedTextShortcuts:(id)sender
{
  [[TextShortcutsManager sharedManager] removeTextShortcutsIndexes:[textShortcutsTableView selectedRowIndexes]];
}

-(IBAction) newCompositionConfiguration:(id)sender
{
  [[CompositionConfigurationManager sharedManager] newCompositionConfiguration];
  [compositionConfigurationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[compositionConfigurationTableView numberOfRows]-1]
                      byExtendingSelection:NO];
}

-(IBAction) removeSelectedCompositionConfigurations:(id)sender
{
  [[CompositionConfigurationManager sharedManager] removeCompositionConfigurationIndexes:[compositionConfigurationTableView selectedRowIndexes]];
}

-(IBAction) checkForUpdatesChange:(id)sender
{
  [[NSUserDefaults standardUserDefaults] setBool:([sender state] == NSOnState) forKey:CheckForNewVersionsKey];
}

-(IBAction) checkNow:(id)sender
{
  [[AppController appController] checkUpdates:self];
}

-(IBAction) gotoWebSite:(id)sender
{
  [[AppController appController] openWebSite:self];
}

-(void) selectPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier
{
  [[[self window] toolbar] setSelectedItemIdentifier:itemIdentifier];
  [self toolbarHit:[toolbarItems objectForKey:itemIdentifier]];
}

-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification
{
  //the MarginController may change the margins defaults, so this notification is useful for synchronizing
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [additionalTopMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
  [additionalLeftMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
  [additionalRightMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
  [additionalBottomMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
}

-(void) _updateButtonStates:(NSNotification*)notification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (!notification || ([notification object] == textShortcutsTableView))
    [removeTextShortcutsButton setEnabled:([textShortcutsTableView selectedRow] >= 0)];
  else if ([notification object] == encapsulationTableView)
    [removeEncapsulationButton setEnabled:([encapsulationTableView selectedRow] >= 0)];
  else if ([notification object] == compositionConfigurationTableView)
  {
    int selectedRow = [compositionConfigurationTableView selectedRow];
    NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
    NSDictionary* selectedConfiguration =
      (selectedRow >= 0) && (selectedRow < (int)[compositionConfigurations count])
        ? [compositionConfigurations objectAtIndex:selectedRow] : nil;
    NSNumber* isDefaultCompositionConfiguration = selectedConfiguration
      ? [selectedConfiguration objectForKey:CompositionConfigurationIsDefaultKey] : [NSNumber numberWithBool:YES];
    [compositionConfigurationRemoveButton setEnabled:(selectedRow >= 0) && ![isDefaultCompositionConfiguration boolValue]];
  }
  if (!notification || [[notification name] isEqualToString:CurrentCompositionConfigurationDidChangeNotification])
  {
    NSNumber* isDefaultCompositionConfiguration =
      [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationIsDefaultKey];
    [compositionConfigurationRemoveButton setEnabled:![isDefaultCompositionConfiguration boolValue]];
    [compositionSelectionPopUpButton selectItemWithTag:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
    [compositionMatrix selectCellWithTag:
      [[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationCompositionModeKey] intValue]];
    [pdfLatexTextField        setStringValue:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPdfLatexPathKey]];
    [xeLatexTextField         setStringValue:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationXeLatexPathKey]];
    [latexTextField           setStringValue:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationLatexPathKey]];
    [dvipdfTextField          setStringValue:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey]];
    [gsTextField              setStringValue:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey]];
    [ps2pdfTextField          setStringValue:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPs2PdfPathKey]];
    [self changeCompositionMode:compositionMatrix];//to update enable state of the buttons just above (here in the code)
    [self changeScriptsConfiguration:nil];
  }
    
  if (!notification || [[notification name] isEqualToString:CompositionConfigurationsDidChangeNotification])
  {
    [compositionSelectionPopUpButton removeAllItems];
    NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
    unsigned int i = 0;
    for(i = 0 ; i<[compositionConfigurations count] ; ++i)
    {
      NSString* title = [[compositionConfigurations objectAtIndex:i] objectForKey:CompositionConfigurationNameKey];
      [[compositionSelectionPopUpButton menu] addItemWithTitle:title action:nil keyEquivalent:@""];
      [[compositionSelectionPopUpButton lastItem] setTag:i];
    }
    [[compositionSelectionPopUpButton menu] addItem:[NSMenuItem separatorItem]];
    [[compositionSelectionPopUpButton menu] addItemWithTitle:
      NSLocalizedString(@"Edit configurations list...", @"Edit configurations list...") action:nil keyEquivalent:@""];
    [[compositionSelectionPopUpButton lastItem] setTag:-1];
    [compositionSelectionPopUpButton selectItemWithTag:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
  }
}

//useful to avoid some bad connections in Interface builder
-(IBAction) nullAction:(id)sender
{
}

//data source of the shortcut/scripts tableview
-(int) numberOfRowsInTableView:(NSTableView *)aTableView
{
  int nbRows = 0;
  if (aTableView == serviceShortcutsTableView)//6 rows for the 6 services
    nbRows = 6;
  else if (aTableView == scriptsTableView)//3 rows for the 3 processings
    nbRows = 3;
  return nbRows;
}

-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  id object = nil;
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  
  if (aTableView == serviceShortcutsTableView)
  {
    NSString* identifier = [aTableColumn identifier];
    if ([identifier isEqualToString:@"enabled"])
      object = [[userDefaults objectForKey:ServiceShortcutEnabledKey] objectAtIndex:rowIndex];
    else if ([identifier isEqualToString:@"description"])
      object = [[NSArray arrayWithObjects:
                   NSLocalizedString(@"Typeset LaTeX Maths eqnarray", @"Typeset LaTeX Maths eqnarray"), 
                   NSLocalizedString(@"Typeset LaTeX Maths display" , @"Typeset LaTeX Maths display"),
                   NSLocalizedString(@"Typeset LaTeX Maths inline"  , @"Typeset LaTeX Maths inline"),
                   NSLocalizedString(@"Typeset LaTeX Text"          , @"Typeset LaTeX Text"),
                   NSLocalizedString(@"Detect and typeset equations", @"Detect and typeset equations"),
                   NSLocalizedString(@"Un-latexize the equations"   , @"Un-latexize the equations"),
                   nil] objectAtIndex:rowIndex];
    else if ([identifier isEqualToString:@"shortcut"])
    {
      NSString* string = [[[userDefaults objectForKey:ServiceShortcutStringsKey] objectAtIndex:rowIndex] uppercaseString];
      const unichar lastCharacter = (string && ![string isEqualToString:@""]) ? [string characterAtIndex:[string length]-1] : '\0';
      const unichar shift = 0x21e7;
      const unichar command = 0x2318;
      const unichar tab[] = {shift, command, lastCharacter};
      int begin = [[NSCharacterSet letterCharacterSet] characterIsMember:lastCharacter] ? 0 : 1;
      object = lastCharacter ? [NSString stringWithCharacters:tab+begin length:3-begin] : @"";
    }
    else if ([identifier isEqualToString:@"warning"])
    {
      NSTableColumn* enabledColumn = [aTableView tableColumnWithIdentifier:@"enabled"];
      NSTableColumn* shortcutColumn = [aTableView tableColumnWithIdentifier:@"shortcut"];
      NSNumber* currentEnabled  = [[aTableView delegate] tableView:aTableView objectValueForTableColumn:enabledColumn row:rowIndex];
      NSString* currentShortcut = [[aTableView delegate] tableView:aTableView objectValueForTableColumn:shortcutColumn row:rowIndex];
      BOOL conflict = NO;
      int i = 0;
      for(i = 0 ; [currentEnabled boolValue] && !conflict && i<[aTableView numberOfRows] ; ++i)
      {
         NSNumber* enabled =  [[aTableView delegate] tableView:aTableView objectValueForTableColumn:enabledColumn row:i];
         NSString* shortcut = [[aTableView delegate] tableView:aTableView objectValueForTableColumn:shortcutColumn row:i];
         conflict |= (i != rowIndex) && [enabled boolValue] && currentShortcut && ![currentShortcut isEqualToString:@""] &&
                                        [currentShortcut isEqualToString:shortcut];
      }

      object = conflict ? warningImage : nil;
      [serviceWarningShortcutConflict setHidden:!conflict && [serviceWarningShortcutConflict isHidden]];
    }
  }
  else if (aTableView == scriptsTableView)
  {
    NSString* placeAsString = [NSString stringWithFormat:@"%d",rowIndex];
    NSDictionary* additionalProcessingScripts =
      [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
    NSDictionary* script = [additionalProcessingScripts objectForKey:placeAsString];
    if ([[aTableColumn identifier] isEqualToString:@"scriptPlace"])
    {
      NSArray* labels = [NSArray arrayWithObjects:NSLocalizedString(@"Pre-processing", @"Pre-processing"),
                                                  NSLocalizedString(@"Middle-processing", @"Middle-processing"),
                                                  NSLocalizedString(@"Post-processing", @"Post-processing"),
                                                  nil];
      object = [labels objectAtIndex:rowIndex];
    }
    else if ([[aTableColumn identifier] isEqualToString:@"scriptEnabled"])
      object = [script objectForKey:ScriptEnabledKey];
  }
  return object;
}

-(void) tableView:(NSTableView *)aTableView setObjectValue:(id)value forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (aTableView == serviceShortcutsTableView)
  {
    latex_mode_t latex_mode = latexModeForIndex(rowIndex);
    int index = indexOfLatexMode(latex_mode);

    NSString* identifier = [aTableColumn identifier];
    if ([identifier isEqualToString:@"enabled"])
    {
      NSMutableArray* shortcutEnabled = [NSMutableArray arrayWithArray:[userDefaults objectForKey:ServiceShortcutEnabledKey]];
      [shortcutEnabled replaceObjectAtIndex:index withObject:value];
      [userDefaults setObject:shortcutEnabled forKey:ServiceShortcutEnabledKey];
    }
    else if ([identifier isEqualToString:@"shortcut"])
    {
      NSMutableArray* shorcutStrings = [NSMutableArray arrayWithArray:[userDefaults objectForKey:ServiceShortcutStringsKey]];
      NSString* valueToStore = ((value != nil) && ![value isEqualToString:@""])
                                 ? [value substringWithRange:NSMakeRange([value length]-1, 1)] : @"";
      [shorcutStrings replaceObjectAtIndex:index withObject:valueToStore];
      [userDefaults setObject:shorcutStrings forKey:ServiceShortcutStringsKey];
    }

    [[AppController appController] changeServiceShortcuts];
  
    [serviceWarningShortcutConflict setHidden:YES];
    [aTableView reloadData];
  }
  else if (aTableView == scriptsTableView)
  {
    script_place_t scriptPlace = rowIndex;
    NSString* placeAsString = [NSString stringWithFormat:@"%d",scriptPlace];
    NSMutableDictionary* mutableAdditionalProcessingScripts =
      [NSMutableDictionary dictionaryWithDictionary:
        [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationAdditionalProcessingScriptsKey]];
    NSMutableDictionary* script =
      [NSMutableDictionary dictionaryWithDictionary:
        [mutableAdditionalProcessingScripts objectForKey:placeAsString]];
    [script setObject:value forKey:ScriptEnabledKey];
    [mutableAdditionalProcessingScripts setObject:script forKey:placeAsString];
    [PreferencesController currentCompositionConfigurationSetObject:mutableAdditionalProcessingScripts
                                                             forKey:CompositionConfigurationAdditionalProcessingScriptsKey];
    [self changeScriptsConfiguration:aTableView];
  }
}

-(void) tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  if (aTableView ==  serviceShortcutsTableView)
  {
    NSString* identifier = [aTableColumn identifier];
    if ([identifier isEqualToString:@"shortcut"])
      [aCell setPlaceholderString:NSLocalizedString(@"none", @"none")];
  }
}

-(id) windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject
{
  return (anObject == serviceShortcutsTableView) ? shortcutTextView : nil;
}

-(IBAction) changeScriptsConfiguration:(id)sender
{
  NSMutableDictionary* mutableAdditionalProcessingScripts =
    [NSMutableDictionary dictionaryWithDictionary:
      [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationAdditionalProcessingScriptsKey]];

  int selectedScript = [scriptsTableView selectedRow];
  script_place_t place = (selectedScript < 0) ? SCRIPT_SOURCE_STRING : selectedScript;
  NSString* placeAsString = [NSString stringWithFormat:@"%d",place];
  NSMutableDictionary* script =
    (selectedScript < 0) ? nil
                         : [NSMutableDictionary dictionaryWithDictionary:[mutableAdditionalProcessingScripts objectForKey:placeAsString]];

  [scriptsSourceTypePopUpButton          setEnabled:(script != nil)];
  [scriptsScriptSelectionTextField       setEnabled:(script != nil)];
  [scriptsScriptSelectionButton          setEnabled:(script != nil)];
  [scriptsScriptDefinitionShellTextField setEnabled:(script != nil)];
  [scriptsScriptDefinitionBodyTextView   setEditable:(script != nil)];
  [scriptsScriptSelectionBox  setHidden:([scriptsSourceTypePopUpButton selectedTag] == SCRIPT_SOURCE_STRING)];
  [scriptsScriptDefinitionBox setHidden:([scriptsSourceTypePopUpButton selectedTag] == SCRIPT_SOURCE_FILE)];

  if (!sender || (sender == scriptsTableView))
  {
    [scriptsTableView reloadData];
    if (script)
    {
      [scriptsSourceTypePopUpButton          selectItemWithTag:[[script objectForKey:ScriptSourceTypeKey] intValue]];
      [scriptsScriptSelectionBox  setHidden:([scriptsSourceTypePopUpButton selectedTag] == SCRIPT_SOURCE_STRING)];
      [scriptsScriptDefinitionBox setHidden:([scriptsSourceTypePopUpButton selectedTag] == SCRIPT_SOURCE_FILE)];
      [scriptsScriptSelectionTextField       setStringValue:[script objectForKey:ScriptFileKey]];
      [scriptsScriptDefinitionShellTextField setStringValue:[script objectForKey:ScriptShellKey]];
      [scriptsScriptDefinitionBodyTextView   setString:[script objectForKey:ScriptBodyKey]];
      NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
      [notificationCenter postNotificationName:NSControlTextDidEndEditingNotification object:scriptsScriptSelectionTextField
                                      userInfo:(void*)self];
    }
  }

  if (sender == scriptsSourceTypePopUpButton)
    [script setObject:[NSNumber numberWithInt:[sender selectedTag]] forKey:ScriptSourceTypeKey];

  if (sender == scriptsScriptSelectionTextField)
    [script setObject:[sender stringValue] forKey:ScriptFileKey];

  if (sender == scriptsScriptDefinitionShellTextField)
    [script setObject:[sender stringValue] forKey:ScriptShellKey];

  if (sender == scriptsScriptDefinitionBodyTextView)
    [script setObject:[sender string] forKey:ScriptBodyKey];

  if (script)
  {
    [mutableAdditionalProcessingScripts setObject:script forKey:placeAsString];
    [PreferencesController currentCompositionConfigurationSetObject:mutableAdditionalProcessingScripts
                                                             forKey:CompositionConfigurationAdditionalProcessingScriptsKey];
  }
}

-(void) tableViewSelectionDidChange:(NSNotification*)notification
{
  if ([notification object] == scriptsTableView)
    [self changeScriptsConfiguration:scriptsTableView];
}

-(IBAction) selectScript:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setResolvesAliases:NO];
  NSString* filename = [scriptsScriptSelectionTextField stringValue];
  NSString* path = filename ? filename : @"";
  path = [[NSFileManager defaultManager] fileExistsAtPath:path] ? [path stringByDeletingLastPathComponent] : nil;
  [openPanel beginSheetForDirectory:path file:[filename lastPathComponent] types:nil modalForWindow:[self window] modalDelegate:self
                           didEndSelector:@selector(didEndOpenPanel:returnCode:contextInfo:)
                              contextInfo:scriptsScriptSelectionTextField];
}

-(IBAction) showScriptHelp:(id)sender
{
  if (![scriptsHelpPanel isVisible])
  {
    [scriptsHelpPanel center];
    [scriptsHelpPanel makeKeyAndOrderFront:sender];
  }
}

-(IBAction) changeCompositionSelection:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender)
  {
    if ([sender selectedTag] == -1) //modify configurations
    {
      int index = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
      [compositionConfigurationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
      [[NSNotificationCenter defaultCenter]
        postNotificationName:NSTableViewSelectionDidChangeNotification object:compositionConfigurationTableView];
      [NSApp beginSheet:compositionSelectionPanel modalForWindow:[self window] modalDelegate:self
         didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    }
    else //update the pane with the current composition configuration
    {
      [userDefaults setInteger:[sender selectedTag] forKey:CurrentCompositionConfigurationIndexKey];
      [[NSNotificationCenter defaultCenter]
        postNotificationName:CurrentCompositionConfigurationDidChangeNotification object:compositionSelectionPopUpButton];
    }
  }
}

-(IBAction) closeCompositionSelectionPanel:(id)sender
{
  [compositionSelectionPanel endEditingFor:nil];
  [NSApp endSheet:compositionSelectionPanel];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setInteger:[[compositionConfigurationTableView selectedRowIndexes] lastIndex]
                    forKey:CurrentCompositionConfigurationIndexKey];
  [[NSNotificationCenter defaultCenter] postNotificationName:CurrentCompositionConfigurationDidChangeNotification
                                                      object:compositionSelectionPopUpButton];
}

-(void)sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode  contextInfo:(void*)contextInfo
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [compositionSelectionPopUpButton selectItemWithTag:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
  [sheet orderOut:self];
}

@end
