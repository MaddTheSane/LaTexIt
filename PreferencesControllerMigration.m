//
//  PreferencesControllerMigration.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "PreferencesControllerMigration.h"

#import "BodyTemplatesController.h"
#import "NSArrayExtended.h"
#import "NSMutableDictionaryExtended.h"
#import "NSWorkspaceExtended.h"
#import "Utils.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

static NSString* const Old_LaTeXiTVersionKey = @"LaTeXiT_Version";

static NSString* const Old_DragExportTypeKey             = @"LaTeXiT_DragExportTypeKey";
static NSString* const Old_DragExportJpegColorKey        = @"LaTeXiT_DragExportJpegColorKey";
static NSString* const Old_DragExportJpegQualityKey      = @"LaTeXiT_DragExportJpegQualityKey";
static NSString* const Old_DragExportScaleAsPercentKey   = @"LateXiT_DragExportScaleAsPercentKey";
static NSString* const Old_DefaultImageViewBackgroundKey = @"LaTeXiT_DefaultImageViewBackground";
static NSString* const Old_DefaultAutomaticHighContrastedPreviewBackgroundKey = @"LaTeXiT_DefaultAutomaticHighContrastedPreviewBackgroundKey";
static NSString* const Old_DefaultColorKey               = @"LaTeXiT_DefaultColorKey";
static NSString* const Old_DefaultPointSizeKey           = @"LaTeXiT_DefaultPointSizeKey";
static NSString* const Old_DefaultModeKey                = @"LaTeXiT_DefaultModeKey";

static NSString* const Old_SpellCheckingEnableKey               = @"LaTeXiT_SpellCheckingEnableKey";
static NSString* const Old_SyntaxColoringEnableKey              = @"LaTeXiT_SyntaxColoringEnableKey";
static NSString* const Old_SyntaxColoringTextForegroundColorKey = @"LaTeXiT_SyntaxColoringTextForegroundColorKey";
static NSString* const Old_SyntaxColoringTextBackgroundColorKey = @"LaTeXiT_SyntaxColoringTextBackgroundColorKey";
static NSString* const Old_SyntaxColoringCommandColorKey        = @"LaTeXiT_SyntaxColoringCommandColorKey";
static NSString* const Old_SyntaxColoringMathsColorKey          = @"LaTeXiT_SyntaxColoringMathsColorKey";
static NSString* const Old_SyntaxColoringKeywordColorKey        = @"LaTeXiT_SyntaxColoringKeywordColorKey";
static NSString* const Old_SyntaxColoringCommentColorKey        = @"LaTeXiT_SyntaxColoringCommentColorKey";
static NSString* const Old_ReducedTextAreaStateKey              = @"LaTeXiT_ReducedTextAreaStateKey";

static NSString* const Old_BodyTemplatesKey             = @"BodyTemplatesKey";
static NSString* const Old_PreamblesKey                 = @"LaTeXiT_PreamblesKey";
static NSString* const Old_DefaultFontKey               = @"LaTeXiT_DefaultFontKey";
static NSString* const Old_LatexisationSelectedPreambleIndexKey = @"LaTeXiT_LatexisationSelectedPreambleIndexKey";

static NSString* const Old_ServiceSelectedPreambleIndexKey = @"LaTeXiT_ServiceSelectedPreambleIndexKey";
static NSString* const Old_ServiceShortcutEnabledKey       = @"LaTeXiT_ServiceShortcutEnabledKey";
static NSString* const Old_ServiceShortcutStringsKey       = @"LaTeXiT_ServiceShortcutStringsKey";
static NSString* const Old_ServiceRespectsBaselineKey      = @"LaTeXiT_ServiceRespectsBaselineKey";
static NSString* const Old_ServiceRespectsPointSizeKey     = @"LaTeXiT_ServiceRespectsPointSizeKey";
static NSString* const Old_ServicePointSizeFactorKey       = @"LaTeXiT_ServicePointSizeFactorKey";
static NSString* const Old_ServiceRespectsColorKey         = @"LaTeXiT_ServiceRespectsColorKey";
static NSString* const Old_ServiceUsesHistoryKey           = @"LaTeXiT_ServiceUsesHistoryKey";
static NSString* const Old_AdditionalTopMarginKey          = @"LaTeXiT_AdditionalTopMarginKey";
static NSString* const Old_AdditionalLeftMarginKey         = @"LaTeXiT_AdditionalLeftMarginKey";
static NSString* const Old_AdditionalRightMarginKey        = @"LaTeXiT_AdditionalRightMarginKey";
static NSString* const Old_AdditionalBottomMarginKey       = @"LaTeXiT_AdditionalBottomMarginKey";
static NSString* const Old_EncapsulationsKey               = @"LaTeXiT_EncapsulationsKey";
static NSString* const Old_CurrentEncapsulationIndexKey    = @"LaTeXiT_CurrentEncapsulationIndexKey";
static NSString* const Old_TextShortcutsKey                = @"LaTeXiT_TextShortcutsKey";


static NSString* const Old_CompositionConfigurationsKey               = @"LaTeXiT_CompositionConfigurationsKey";
static NSString* const Old_CurrentCompositionConfigurationIndexKey    = @"LaTeXiT_CurrentCompositionConfigurationIndexKey";

static NSString* const Old_LastEasterEggsDatesKey       = @"LaTeXiT_LastEasterEggsDatesKey";

static NSString* const Old_CompositionConfigurationsControllerVisibleAtStartupKey = @"CompositionConfigurationsControllerVisibleAtStartupKey";
static NSString* const Old_EncapsulationsControllerVisibleAtStartupKey = @"EncapsulationsControllerVisibleAtStartupKey";
static NSString* const Old_HistoryControllerVisibleAtStartupKey       = @"HistoryControllerVisibleAtStartupKey";
static NSString* const Old_LatexPalettesControllerVisibleAtStartupKey = @"LatexPalettesControllerVisibleAtStartupKey";
static NSString* const Old_LibraryControllerVisibleAtStartupKey       = @"LibraryControllerVisibleAtStartupKey";
static NSString* const Old_MarginControllerVisibleAtStartupKey        = @"MarginControllerVisibleAtStartupKey";
static NSString* const Old_AdditionalFilesWindowControllerVisibleAtStartupKey = @"AdditionalFilesWindowControllerVisibleAtStartupKey";

static NSString* const Old_LibraryViewRowTypeKey         = @"LibraryViewRowTypeKey";
static NSString* const Old_LibraryDisplayPreviewPanelKey = @"LibraryDisplayPreviewPanelKey";
static NSString* const Old_HistoryDisplayPreviewPanelKey = @"HistoryDisplayPreviewPanelKey";

NSString* const Old_CheckForNewVersionsKey = @"LaTeXiT_CheckForNewVersionsKey";

static NSString* const Old_LatexPaletteGroupKey        = @"LaTeXiT_LatexPaletteGroupKey";
static NSString* const Old_LatexPaletteFrameKey        = @"LaTeXiT_LatexPaletteFrameKey";
static NSString* const Old_LatexPaletteDetailsStateKey = @"LaTeXiT_LatexPaletteDetailsStateKey";

static NSString* const Old_UseLoginShellKey               = @"LaTeXiT_UseLoginShellKey";

static NSString* const Old_ShowWhiteColorWarningKey       = @"LaTeXiT_ShowWhiteColorWarningKey";

static NSString* const Old_CompositionConfigurationNameKey                        = @"LaTeXiT_CompositionConfigurationNameKey";
static NSString* const Old_CompositionConfigurationIsDefaultKey                   = @"LaTeXiT_CompositionConfigurationIsDefaultKey";
static NSString* const Old_CompositionConfigurationCompositionModeKey             = @"LaTeXiT_CompositionConfigurationCompositionModeKey";
static NSString* const Old_CompositionConfigurationPdfLatexPathKey                = @"LaTeXiT_CompositionConfigurationPdfLatexPathKey";
static NSString* const Old_CompositionConfigurationPs2PdfPathKey                  = @"LaTeXiT_CompositionConfigurationPs2PdfPathKey";
static NSString* const Old_CompositionConfigurationXeLatexPathKey                 = @"LaTeXiT_CompositionConfigurationXeLatexPathKey";
static NSString* const Old_CompositionConfigurationLuaLatexPathKey                = @"LaTeXiT_CompositionConfigurationLuaLatexPathKey";
static NSString* const Old_CompositionConfigurationLatexPathKey                   = @"LaTeXiT_CompositionConfigurationLatexPathKey";
static NSString* const Old_CompositionConfigurationDvipdfPathKey                  = @"LaTeXiT_CompositionConfigurationDvipdfPathKey";
static NSString* const Old_CompositionConfigurationGsPathKey                      = @"LaTeXiT_CompositionConfigurationGsPathKey";
static NSString* const Old_CompositionConfigurationAdditionalProcessingScriptsKey = @"LaTeXiT_CompositionConfigurationAdditionalProcessingScriptsKey";
static NSString* const Old_CompositionConfigurationAdditionalProcessingScriptsEnabledKey = @"LaTeXiT_ScriptEnabledKey";
static NSString* const Old_CompositionConfigurationAdditionalProcessingScriptsTypeKey    = @"LaTeXiT_ScriptSourceTypeKey";
static NSString* const Old_CompositionConfigurationAdditionalProcessingScriptsPathKey    = @"LaTeXiT_ScriptFileKey";
static NSString* const Old_CompositionConfigurationAdditionalProcessingScriptsShellKey   = @"LaTeXiT_ScriptShellKey";
static NSString* const Old_CompositionConfigurationAdditionalProcessingScriptsContentKey = @"LaTeXiT_ScriptBodyKey";

@interface PreferencesController (MigrationPrivateAPI)
-(void) migrateCompositionConfigurations;
-(void) migrateServiceShortcuts;
@end

@implementation PreferencesController (Migration)

+(NSArray*) oldKeys
{
  return @[Old_LaTeXiTVersionKey,
            Old_DragExportTypeKey,
            Old_DragExportJpegColorKey,
            Old_DragExportJpegQualityKey,
            Old_DragExportScaleAsPercentKey,
            Old_DefaultImageViewBackgroundKey,
            Old_DefaultAutomaticHighContrastedPreviewBackgroundKey,
            Old_DefaultColorKey,
            Old_DefaultPointSizeKey,
            Old_DefaultModeKey,
            Old_SpellCheckingEnableKey,
            Old_SyntaxColoringEnableKey,
            Old_SyntaxColoringTextForegroundColorKey,
            Old_SyntaxColoringTextBackgroundColorKey,
            Old_SyntaxColoringCommandColorKey,
            Old_SyntaxColoringMathsColorKey,
            Old_SyntaxColoringKeywordColorKey,
            Old_SyntaxColoringCommentColorKey,
            Old_ReducedTextAreaStateKey,
            Old_BodyTemplatesKey,
            Old_PreamblesKey,
            Old_DefaultFontKey,
            Old_LatexisationSelectedPreambleIndexKey,
            Old_ServiceSelectedPreambleIndexKey,
            Old_ServiceShortcutEnabledKey,
            Old_ServiceShortcutStringsKey,
            Old_ServiceRespectsBaselineKey,
            Old_ServiceRespectsPointSizeKey,
            Old_ServicePointSizeFactorKey,
            Old_ServiceRespectsColorKey,
            Old_ServiceUsesHistoryKey,
            Old_AdditionalTopMarginKey,
            Old_AdditionalLeftMarginKey,
            Old_AdditionalRightMarginKey,
            Old_AdditionalBottomMarginKey,
            Old_EncapsulationsKey,
            Old_CurrentEncapsulationIndexKey,
            Old_TextShortcutsKey,
            Old_CompositionConfigurationsKey,
            Old_CurrentCompositionConfigurationIndexKey,
            Old_LastEasterEggsDatesKey,
            Old_CompositionConfigurationsControllerVisibleAtStartupKey,
            Old_EncapsulationsControllerVisibleAtStartupKey,
            Old_HistoryControllerVisibleAtStartupKey,
            Old_LatexPalettesControllerVisibleAtStartupKey,
            Old_LibraryControllerVisibleAtStartupKey,
            Old_MarginControllerVisibleAtStartupKey,
            Old_AdditionalFilesWindowControllerVisibleAtStartupKey,
            Old_LibraryViewRowTypeKey,
            Old_LibraryDisplayPreviewPanelKey,
            Old_HistoryDisplayPreviewPanelKey,
            Old_CheckForNewVersionsKey,
            Old_LatexPaletteGroupKey,
            Old_LatexPaletteFrameKey,
            Old_LatexPaletteDetailsStateKey,
            Old_UseLoginShellKey,
            Old_ShowWhiteColorWarningKey,
            Old_CompositionConfigurationNameKey,
            Old_CompositionConfigurationIsDefaultKey,
            Old_CompositionConfigurationCompositionModeKey,
            Old_CompositionConfigurationPdfLatexPathKey,
            Old_CompositionConfigurationPs2PdfPathKey,
            Old_CompositionConfigurationXeLatexPathKey,
            Old_CompositionConfigurationLuaLatexPathKey,
            Old_CompositionConfigurationLatexPathKey,
            Old_CompositionConfigurationDvipdfPathKey,
            Old_CompositionConfigurationGsPathKey,
            Old_CompositionConfigurationAdditionalProcessingScriptsKey,
            Old_CompositionConfigurationAdditionalProcessingScriptsEnabledKey,
            Old_CompositionConfigurationAdditionalProcessingScriptsTypeKey,
            Old_CompositionConfigurationAdditionalProcessingScriptsPathKey,
            Old_CompositionConfigurationAdditionalProcessingScriptsShellKey,
            Old_CompositionConfigurationAdditionalProcessingScriptsContentKey];
}
//end oldKeys

-(void) migratePreferences
{
  NSString* oldLatexitVersion = nil;
  NSString* newLatexitVersion = nil;
  if (self->isLaTeXiT)
  {
    oldLatexitVersion = [[NSUserDefaults standardUserDefaults] stringForKey:Old_LaTeXiTVersionKey];
    newLatexitVersion = [[NSUserDefaults standardUserDefaults] stringForKey:LaTeXiTVersionKey];
  }
  else
  {
    oldLatexitVersion = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)Old_LaTeXiTVersionKey, (__bridge CFStringRef)LaTeXiTAppKey));
    newLatexitVersion = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)LaTeXiTVersionKey, (__bridge CFStringRef)LaTeXiTAppKey));
  }

  
  if ([oldLatexitVersion compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending)
  {//migration
    [self replaceKey:Old_ShowWhiteColorWarningKey withKey:ShowWhiteColorWarningKey];
    [self replaceKey:Old_AdditionalBottomMarginKey withKey:AdditionalBottomMarginKey];
    [self replaceKey:Old_AdditionalLeftMarginKey withKey:AdditionalLeftMarginKey];
    [self replaceKey:Old_AdditionalRightMarginKey withKey:AdditionalRightMarginKey];
    [self replaceKey:Old_AdditionalTopMarginKey withKey:AdditionalTopMarginKey];
    
    [self migrateCompositionConfigurations];
    
    [self replaceKey:Old_CurrentEncapsulationIndexKey withKey:CurrentEncapsulationIndexKey];
    [self replaceKey:Old_DefaultAutomaticHighContrastedPreviewBackgroundKey withKey:DefaultAutomaticHighContrastedPreviewBackgroundKey];
    [self replaceKey:Old_DefaultColorKey withKey:DefaultColorKey];
    [self replaceKey:Old_DefaultFontKey withKey:DefaultFontKey];
    [self replaceKey:Old_DefaultImageViewBackgroundKey withKey:DefaultImageViewBackgroundKey];
    [self replaceKey:Old_DefaultModeKey withKey:DefaultModeKey];
    [self replaceKey:Old_DefaultPointSizeKey withKey:DefaultPointSizeKey];
    [self replaceKey:Old_DragExportJpegColorKey withKey:DragExportJpegColorKey];
    [self replaceKey:Old_DragExportJpegQualityKey withKey:DragExportJpegQualityKey];
    [self replaceKey:Old_DragExportScaleAsPercentKey withKey:DragExportScaleAsPercentKey];
    [self replaceKey:Old_DragExportTypeKey withKey:DragExportTypeKey];
    [self replaceKey:Old_EncapsulationsKey withKey:EncapsulationsKey];
    [self replaceKey:Old_LatexisationSelectedPreambleIndexKey withKey:LatexisationSelectedPreambleIndexKey];
    [self replaceKey:Old_PreamblesKey withKey:PreamblesKey];
    [self replaceKey:Old_ReducedTextAreaStateKey withKey:ReducedTextAreaStateKey];
    [self replaceKey:Old_ServicePointSizeFactorKey withKey:ServicePointSizeFactorKey];
    [self replaceKey:Old_ServiceRespectsBaselineKey withKey:ServiceRespectsBaselineKey];
    [self replaceKey:Old_ServiceRespectsColorKey withKey:ServiceRespectsColorKey];
    [self replaceKey:Old_ServiceRespectsPointSizeKey withKey:ServiceRespectsPointSizeKey];
    [self replaceKey:Old_ServiceSelectedPreambleIndexKey withKey:ServiceSelectedPreambleIndexKey];

    [self migrateServiceShortcuts];

    [self replaceKey:Old_ServiceUsesHistoryKey withKey:ServiceUsesHistoryKey];
    
    [self replaceKey:Old_SpellCheckingEnableKey withKey:SpellCheckingEnableKey];
    [self replaceKey:Old_SyntaxColoringCommandColorKey withKey:SyntaxColoringCommandColorKey];
    [self replaceKey:Old_SyntaxColoringCommentColorKey withKey:SyntaxColoringCommentColorKey];
    [self replaceKey:Old_SyntaxColoringEnableKey withKey:SyntaxColoringEnableKey];
    [self replaceKey:Old_SyntaxColoringKeywordColorKey withKey:SyntaxColoringKeywordColorKey];
    [self replaceKey:Old_SyntaxColoringMathsColorKey withKey:SyntaxColoringMathsColorKey];
    [self replaceKey:Old_SyntaxColoringTextBackgroundColorKey withKey:SyntaxColoringTextBackgroundColorKey];
    [self replaceKey:Old_SyntaxColoringTextForegroundColorKey withKey:SyntaxColoringTextForegroundColorKey];
    [self replaceKey:Old_TextShortcutsKey withKey:TextShortcutsKey];

    [self replaceKey:Old_CompositionConfigurationsControllerVisibleAtStartupKey withKey:CompositionConfigurationsControllerVisibleAtStartupKey];
    [self replaceKey:Old_EncapsulationsControllerVisibleAtStartupKey withKey:EncapsulationsControllerVisibleAtStartupKey];
    [self replaceKey:Old_HistoryControllerVisibleAtStartupKey withKey:HistoryControllerVisibleAtStartupKey];
    [self replaceKey:Old_LatexPalettesControllerVisibleAtStartupKey withKey:LatexPalettesControllerVisibleAtStartupKey];
    [self replaceKey:Old_LibraryControllerVisibleAtStartupKey withKey:LibraryControllerVisibleAtStartupKey];
    [self replaceKey:Old_MarginControllerVisibleAtStartupKey withKey:MarginControllerVisibleAtStartupKey];
    [self replaceKey:Old_AdditionalFilesWindowControllerVisibleAtStartupKey withKey:AdditionalFilesWindowControllerVisibleAtStartupKey];

    [self replaceKey:Old_HistoryDisplayPreviewPanelKey withKey:HistoryDisplayPreviewPanelKey];

    [self replaceKey:Old_LibraryViewRowTypeKey withKey:LibraryViewRowTypeKey];
    [self replaceKey:Old_LibraryDisplayPreviewPanelKey withKey:LibraryDisplayPreviewPanelKey];
    
    [self replaceKey:Old_LatexPaletteGroupKey withKey:LatexPaletteGroupKey];
    [self replaceKey:Old_LatexPaletteFrameKey withKey:LatexPaletteFrameKey];
    [self replaceKey:Old_LatexPaletteDetailsStateKey withKey:LatexPaletteDetailsStateKey];

    [self replaceKey:Old_LastEasterEggsDatesKey withKey:LastEasterEggsDatesKey];

    [self replaceKey:Old_LaTeXiTVersionKey withKey:LaTeXiTVersionKey];
  }//end if ([latexitVersion compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending)
  
  if (!newLatexitVersion || ([newLatexitVersion compare:@"2.0.1" options:NSNumericSearch] == NSOrderedAscending))
    [self replaceKey:Old_BodyTemplatesKey withKey:BodyTemplatesKey];
  
  if (!newLatexitVersion || ([newLatexitVersion compare:@"2.1.0" options:NSNumericSearch] == NSOrderedAscending))
  {
    NSMutableArray* servicesItems = nil;
    if (self->isLaTeXiT)
      servicesItems = [NSMutableArray arrayWithArray:
      [[NSUserDefaults standardUserDefaults] objectForKey:ServiceShortcutsKey]];
    else
      #ifdef ARC_ENABLED
      servicesItems = [NSMutableArray arrayWithArray:
        CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey)) ];
      #else
      servicesItems = [NSMutableArray arrayWithArray:
        [(NSArray*)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)ServiceShortcutsKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey) autorelease]];
      #endif
    NSUInteger count = [servicesItems count];
    while(count--)
    {
      NSDictionary* serviceItem = [servicesItems objectAtIndex:count];
      if ([[serviceItem objectForKey:ServiceShortcutIdentifierKey] integerValue] == SERVICE_LATEXIZE_EQNARRAY)
      {
        [servicesItems replaceObjectAtIndex:count withObject:
          [NSDictionary dictionaryWithObjectsAndKeys:
            [serviceItem objectForKey:ServiceShortcutEnabledKey], ServiceShortcutEnabledKey,
            [serviceItem objectForKey:ServiceShortcutStringKey], ServiceShortcutStringKey,
            [NSNumber numberWithInteger:SERVICE_LATEXIZE_ALIGN], ServiceShortcutIdentifierKey,
            [serviceItem objectForKey:ServiceShortcutClipBoardOptionKey], ServiceShortcutClipBoardOptionKey,
            nil]];
      }
    }//end for each serviceItem
    if (self->isLaTeXiT)
      [[NSUserDefaults standardUserDefaults] setObject:servicesItems forKey:ServiceShortcutsKey];
    else
      CFPreferencesSetAppValue((__bridge CFStringRef)ServiceShortcutsKey, (__bridge CFPropertyListRef)servicesItems, (__bridge CFStringRef)LaTeXiTAppKey);
    if (self.latexisationLaTeXMode == LATEX_MODE_EQNARRAY)
      self.latexisationLaTeXMode = LATEX_MODE_ALIGN;

    NSArrayController* localBodyTemplatesController = [self bodyTemplatesController];
    NSEnumerator* enumerator = [localBodyTemplatesController.arrangedObjects objectEnumerator];
    NSDictionary* entry = nil;
    BOOL foundEqnarray = NO;
    while(!foundEqnarray && ((entry = [enumerator nextObject])))
      foundEqnarray |= [entry[@"name"] isEqualToString:@"eqnarray*"];
    if (!foundEqnarray)
      [localBodyTemplatesController addObject:[[localBodyTemplatesController class] bodyTemplateDictionaryEncodedForEnvironment:@"eqnarray*"]];
  }//end if (!newLatexitVersion || ([newLatexitVersion compare:@"2.1.0" options:NSNumericSearch] == NSOrderedAscending))
  
  if (self->isLaTeXiT)
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[[NSWorkspace sharedWorkspace] applicationVersion] forKey:LaTeXiTVersionKey];
  }
}
//end migratePreferences

-(void) removeKey:(NSString*)key
{
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
  else//!if (!self->isLaTeXiT)
    CFPreferencesSetAppValue((CFStringRef)key, NULL, (CFStringRef)LaTeXiTAppKey);
}
//end removeKey:

-(void) replaceKey:(NSString*)oldKey withKey:(NSString*)newKey
{
  if (self->isLaTeXiT)
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    id value = [userDefaults objectForKey:oldKey];
    if (value)
    {
      [userDefaults removeObjectForKey:oldKey];
      [userDefaults setObject:value forKey:newKey];
    }
  }
  else//!if (!self->isLaTeXiT)
  {
    #ifdef ARC_ENABLED
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)oldKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #else
    id value = NSMakeCollectable((id)CFPreferencesCopyAppValue((CHBRIDGE CFStringRef)oldKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey));
    #endif
    if (value)
    {
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)oldKey, 0, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #ifdef ARC_ENABLED
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)newKey, (CHBRIDGE CFPropertyListRef)value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      
      #else
      CFPreferencesSetAppValue((CHBRIDGE CFStringRef)newKey, value, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
      #endif
      #ifdef ARC_ENABLED
      #else
      [value release];
      #endif
    }
  }//end if (!self->isLaTeXiT)
}
//end replaceKey:withKey:

-(void) migrateCompositionConfigurations
{
  BOOL useLoginShell = self->isLaTeXiT ? [[NSUserDefaults standardUserDefaults] boolForKey:Old_UseLoginShellKey] :
                       CFPreferencesGetAppBooleanValue((CHBRIDGE CFStringRef)Old_UseLoginShellKey, (CHBRIDGE CFStringRef)LaTeXiTAppKey, 0);
  [self replaceKey:Old_CompositionConfigurationsKey withKey:CompositionConfigurationsKey];
  [self replaceKey:Old_CurrentCompositionConfigurationIndexKey withKey:CompositionConfigurationDocumentIndexKey];
  NSMutableArray* newCompositionConfigurations = [self.compositionConfigurations deepMutableCopy];
  for(NSMutableDictionary* compositionConfiguration in newCompositionConfigurations)
  {
    [compositionConfiguration replaceKey:Old_CompositionConfigurationCompositionModeKey withKey:CompositionConfigurationCompositionModeKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationIsDefaultKey withKey:CompositionConfigurationIsDefaultKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationNameKey withKey:CompositionConfigurationNameKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationAdditionalProcessingScriptsKey withKey:CompositionConfigurationAdditionalProcessingScriptsKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationPdfLatexPathKey withKey:CompositionConfigurationPdfLatexPathKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationPs2PdfPathKey withKey:CompositionConfigurationPsToPdfPathKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationXeLatexPathKey withKey:CompositionConfigurationXeLatexPathKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationLuaLatexPathKey withKey:CompositionConfigurationLuaLatexPathKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationLatexPathKey withKey:CompositionConfigurationLatexPathKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationDvipdfPathKey withKey:CompositionConfigurationDviPdfPathKey];
    [compositionConfiguration replaceKey:Old_CompositionConfigurationGsPathKey withKey:CompositionConfigurationGsPathKey];
    compositionConfiguration[CompositionConfigurationUseLoginShellKey] = @(useLoginShell);
    NSMutableDictionary* additionalScripts = compositionConfiguration[CompositionConfigurationAdditionalProcessingScriptsKey];
    for(NSMutableDictionary* additionalScript in additionalScripts.allValues)
    {
      [additionalScript replaceKey:Old_CompositionConfigurationAdditionalProcessingScriptsEnabledKey
                           withKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey];
      [additionalScript replaceKey:Old_CompositionConfigurationAdditionalProcessingScriptsTypeKey
                           withKey:CompositionConfigurationAdditionalProcessingScriptTypeKey];
      [additionalScript replaceKey:Old_CompositionConfigurationAdditionalProcessingScriptsPathKey
                           withKey:CompositionConfigurationAdditionalProcessingScriptPathKey];
      [additionalScript replaceKey:Old_CompositionConfigurationAdditionalProcessingScriptsShellKey
                           withKey:CompositionConfigurationAdditionalProcessingScriptShellKey];
      [additionalScript replaceKey:Old_CompositionConfigurationAdditionalProcessingScriptsContentKey
                           withKey:CompositionConfigurationAdditionalProcessingScriptContentKey];
    }//end for each script
  }//end for each compositionConfiguration
  
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:newCompositionConfigurations forKey:CompositionConfigurationsKey];
  else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)CompositionConfigurationsKey, (CHBRIDGE CFPropertyListRef)newCompositionConfigurations, (CHBRIDGE CFStringRef)LaTeXiTAppKey);

  //[self replaceKey:Old_UseLoginShellKey withKey:UseLoginShellKey];
}
//end migrateCompositionConfigurations

-(void) migrateServiceShortcuts
{
  NSArray* oldServiceShortcutsEnabled = nil;
  NSArray* oldServiceShortcutsStrings = nil;
  if (self->isLaTeXiT)
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    oldServiceShortcutsEnabled = [userDefaults arrayForKey:Old_ServiceShortcutEnabledKey];
    oldServiceShortcutsStrings = [userDefaults arrayForKey:Old_ServiceShortcutStringsKey];
  }
  else
  {
    oldServiceShortcutsEnabled = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)Old_ServiceShortcutEnabledKey, (__bridge CFStringRef)LaTeXiTAppKey));
    oldServiceShortcutsStrings = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)Old_ServiceShortcutStringsKey, (__bridge CFStringRef)LaTeXiTAppKey));
  }
  
  NSMutableArray* newServiceShortcuts = [NSMutableArray arrayWithCapacity:6];
  NSUInteger count = MIN(6U, MIN([oldServiceShortcutsEnabled count], [oldServiceShortcutsEnabled count]));
  NSUInteger i = 0;
  for(i = 0 ; i<count ; ++i)
    [newServiceShortcuts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
      [oldServiceShortcutsEnabled objectAtIndex:i], ServiceShortcutEnabledKey,
      [oldServiceShortcutsStrings objectAtIndex:i], ServiceShortcutStringKey,
      @(i+((count == 3) ? 1 : 0)), ServiceShortcutIdentifierKey,
      nil]];
  if ([newServiceShortcuts count] == 3)
    [newServiceShortcuts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
      [oldServiceShortcutsEnabled objectAtIndex:i], ServiceShortcutEnabledKey,
      [oldServiceShortcutsStrings objectAtIndex:i], ServiceShortcutStringKey,
      @(SERVICE_LATEXIZE_EQNARRAY), ServiceShortcutIdentifierKey,
      nil]];
  if ([newServiceShortcuts count] == 4)
    [newServiceShortcuts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
      @YES, ServiceShortcutEnabledKey,
      @"", ServiceShortcutStringKey,
      @(SERVICE_MULTILATEXIZE), ServiceShortcutIdentifierKey,
      nil]];
  if ([newServiceShortcuts count] == 5)
    [newServiceShortcuts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
      @YES, ServiceShortcutEnabledKey,
      @"", ServiceShortcutStringKey,
      @(SERVICE_DELATEXIZE), ServiceShortcutIdentifierKey,
      nil]];
  [self removeKey:Old_ServiceShortcutEnabledKey];
  [self removeKey:Old_ServiceShortcutStringsKey];
  if (self->isLaTeXiT)
    [[NSUserDefaults standardUserDefaults] setObject:newServiceShortcuts forKey:ServiceShortcutsKey];
  else
    CFPreferencesSetAppValue((CHBRIDGE CFStringRef)ServiceShortcutsKey, (CHBRIDGE CFPropertyListRef)newServiceShortcuts, (CHBRIDGE CFStringRef)LaTeXiTAppKey);
}
//end migrateServiceShortcuts

@end
