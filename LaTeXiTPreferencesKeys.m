/*
 *  LaTeXiTPreferencesKey.m
 *  LaTeXiT
 *
 *  Created by Pierre Chatelier on 25/09/08.
 *  Copyright 2008 LAIC. All rights reserved.
 *
 */

#include "LaTeXiTPreferencesKeys.h"

NSString* LaTeXiTVersionKey = @"LaTeXiT_Version";

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

NSString* PreamblesKey                 = @"LaTeXiT_PreamblesKey";
NSString* DefaultFontKey               = @"LaTeXiT_DefaultFontKey";
NSString* LatexisationSelectedPreambleIndexKey = @"LaTeXiT_LatexisationSelectedPreambleIndexKey";

NSString* ServiceSelectedPreambleIndexKey = @"LaTeXiT_ServiceSelectedPreambleIndexKey";
NSString* ServiceShortcutEnabledKey       = @"LaTeXiT_ServiceShortcutEnabledKey";
NSString* ServiceShortcutStringsKey       = @"LaTeXiT_ServiceShortcutStringsKey";
NSString* ServiceRespectsBaselineKey      = @"LaTeXiT_ServiceRespectsBaselineKey";
NSString* ServiceRespectsPointSizeKey     = @"LaTeXiT_ServiceRespectsPointSizeKey";
NSString* ServicePointSizeFactorKey       = @"LaTeXiT_ServicePointSizeFactorKey";
NSString* ServiceRespectsColorKey         = @"LaTeXiT_ServiceRespectsColorKey";
NSString* ServiceUsesHistoryKey           = @"LaTeXiT_ServiceUsesHistoryKey";
NSString* AdditionalTopMarginKey          = @"LaTeXiT_AdditionalTopMarginKey";
NSString* AdditionalLeftMarginKey         = @"LaTeXiT_AdditionalLeftMarginKey";
NSString* AdditionalRightMarginKey        = @"LaTeXiT_AdditionalRightMarginKey";
NSString* AdditionalBottomMarginKey       = @"LaTeXiT_AdditionalBottomMarginKey";
NSString* EncapsulationsKey               = @"LaTeXiT_EncapsulationsKey";
NSString* CurrentEncapsulationIndexKey    = @"LaTeXiT_CurrentEncapsulationIndexKey";
NSString* TextShortcutsKey                = @"LaTeXiT_TextShortcutsKey";

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

NSString* UseLoginShellKey               = @"LaTeXiT_UseLoginShellKey";
NSString* ScriptEnabledKey               = @"LaTeXiT_ScriptEnabledKey";
NSString* ScriptSourceTypeKey            = @"LaTeXiT_ScriptSourceTypeKey";
NSString* ScriptShellKey                 = @"LaTeXiT_ScriptShellKey";
NSString* ScriptBodyKey                  = @"LaTeXiT_ScriptBodyKey";
NSString* ScriptFileKey                  = @"LaTeXiT_ScriptFileKey";

NSString* ShowWhiteColorWarningKey       = @"LaTeXiT_ShowWhiteColorWarningKey";

NSString* SomePathDidChangeNotification        = @"SomePathDidChangeNotification"; //changing the path to an executable (like pdflatex)
NSString* CompositionModeDidChangeNotification = @"CompositionModeDidChangeNotification";
NSString* CurrentCompositionConfigurationDidChangeNotification = @"CurrentCompositionConfigurationDidChangeNotification";
