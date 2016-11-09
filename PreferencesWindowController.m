//  PreferencesWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import "PreferencesWindowController.h"

#import "AdditionalFilesController.h"
#import "AppController.h"
#import "BodyTemplatesController.h"
#import "BodyTemplatesTableView.h"
#import "BoolTransformer.h"
#import "ComposedTransformer.h"
#import "CompositionConfigurationsController.h"
#import "CompositionConfigurationsProgramArgumentsTableView.h"
#import "EncapsulationsTableView.h"
#import "ExportFormatOptionsPanes.h"
#import "FileExistsTransformer.h"
#import "FilePathLocalizedTransformer.h"
#import "FolderExistsTransformer.h"
#import "ImageAndTextCell.h"
#import "IsEqualToTransformer.h"
#import "IsInTransformer.h"
#import "IsNotEqualToTransformer.h"
#import "KeyedUnarchiveFromDataTransformer.h"
#import "LatexitEquation.h"
#import "LibraryEquation.h"
#import "LibraryManager.h"
#import "LibraryView.h"
#import "LineCountTextView.h"
#import "LogicTransformer.h"
#import "MyDocument.h"
#import "NSButtonExtended.h"
#import "NSColorExtended.h"
#import "NSDictionaryExtended.h"
#import "NSFontExtended.h"
#import "NSMutableArrayExtended.h"
#import "NSNumberIntegerShiftTransformer.h"
#import "NSObjectExtended.h"
#import "NSPopUpButtonExtended.h"
#import "NSSegmentedControlExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSViewExtended.h"
#import "ObjectTransformer.h"
#import "Plugin.h"
#import "PluginsManager.h"
#import "PreamblesController.h"
#import "PreamblesTableView.h"
#import "ServiceRegularExpressionFiltersController.h"
#import "ServiceRegularExpressionFiltersTableView.h"
#import "ServiceShortcutsTableView.h"
#import "ServiceShortcutsTextView.h"
#import "SynchronizationAdditionalScriptsController.h"
#import "TextViewWithPlaceHolder.h"
#import "Utils.h"
#import "AdditionalFilesTableView.h"

#import "RegexKitLite.h"
#import <Sparkle/Sparkle.h>

#ifndef NSAppKitVersionNumber10_4
#define NSAppKitVersionNumber10_4 824
#endif

NSString* GeneralToolbarItemIdentifier     = @"GeneralToolbarItemIdentifier";
NSString* EditionToolbarItemIdentifier     = @"EditionToolbarItemIdentifier";
NSString* TemplatesToolbarItemIdentifier   = @"TemplatesToolbarItemIdentifier";
NSString* CompositionToolbarItemIdentifier = @"CompositionToolbarItemIdentifier";
NSString* LibraryToolbarItemIdentifier     = @"LibraryToolbarItemIdentifier";
NSString* HistoryToolbarItemIdentifier     = @"HistoryToolbarItemIdentifier";
NSString* ServiceToolbarItemIdentifier     = @"ServiceToolbarItemIdentifier";
NSString* AdvancedToolbarItemIdentifier    = @"AdvancedToolbarItemIdentifier";
NSString* WebToolbarItemIdentifier         = @"WebToolbarItemIdentifier";
NSString* PluginsToolbarItemIdentifier     = @"PluginsToolbarItemIdentifier";

@interface PreferencesWindowController () <ExportFormatOptionsDelegate>
-(IBAction) nilAction:(id)sender;
-(IBAction) changePath:(id)sender;
-(void) afterAwakeFromNib:(id)object;
-(void) updateProgramArgumentsToolTips;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;
-(void) tableViewSelectionDidChange:(NSNotification*)notification;
-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) didEndOpenPanel:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) _preamblesValueResetDefault:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
-(void) textDidChange:(NSNotification*)notification;
@end

@implementation PreferencesWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"PreferencesWindowController"])))
    return nil;
  toolbarItems = [[NSMutableDictionary alloc] init];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                               name:NSApplicationWillTerminateNotification object:nil];
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [viewsMinSizes release];
  [toolbarItems release];
  [applyPreambleToLibraryAlert release];
  [compositionConfigurationsAdditionalScriptsHelpPanel release];
  [synchronizationAdditionalScriptsHelpPanel release];
  [super dealloc];
}
//end dealloc

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ((object == [[PreferencesController sharedController] preamblesController]) && [keyPath isEqualToString:@"selection.value"])
    [preamblesValueTextView textDidChange:nil];//to force recoulouring
  else if ((object == [[PreferencesController sharedController] bodyTemplatesController]) && [keyPath isEqualToString:@"selection.head"])
    [bodyTemplatesHeadTextView textDidChange:nil];//to force recoulouring
  else if ((object == [[PreferencesController sharedController] bodyTemplatesController]) && [keyPath isEqualToString:@"selection.tail"])
    [bodyTemplatesTailTextView textDidChange:nil];//to force recoulouring
  else if ((object == [[PreferencesController sharedController] compositionConfigurationsController]) && 
           ([keyPath isEqualToString:@"arrangedObjects"] ||
            [keyPath isEqualToString:[@"arrangedObjects." stringByAppendingString:CompositionConfigurationNameKey]]))
  {
    [compositionConfigurationsCurrentPopUpButton removeAllItems];
    [compositionConfigurationsCurrentPopUpButton addItemsWithTitles:
      [[[PreferencesController sharedController] compositionConfigurationsController]
        valueForKeyPath:[@"arrangedObjects." stringByAppendingString:CompositionConfigurationNameKey]]];
    [[compositionConfigurationsCurrentPopUpButton menu] addItem:[NSMenuItem separatorItem]];
    [compositionConfigurationsCurrentPopUpButton addItemWithTitle:NSLocalizedString(@"Edit the configurations...", @"Edit the configurations...")];
  }
  else if (object == [[PreferencesController sharedController] serviceRegularExpressionFiltersController])
    [self textDidChange:
      [NSNotification notificationWithName:NSTextDidChangeNotification object:serviceRegularExpressionsTestInputTextView]];
  else if ((object == [NSUserDefaultsController sharedUserDefaultsController]) &&
           [keyPath isEqualToString:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]])
  {
    [compositionConfigurationsCurrentPopUpButton selectItemAtIndex:[[PreferencesController sharedController] compositionConfigurationsDocumentIndex]];
    [self updateProgramArgumentsToolTips];
  }
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) awakeFromNib
{
  //get rid of formatter localization problems
  [generalPointSizeFormatter setLocale:[NSLocale currentLocale]];
  [generalPointSizeFormatter setGroupingSeparator:[[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator]];
  [generalPointSizeFormatter setDecimalSeparator:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
  NSString* generalPointSizeZeroSymbol =
   [NSString stringWithFormat:@"0%@%0*d%@",
     [generalPointSizeFormatter decimalSeparator], 2, 0, 
     [generalPointSizeFormatter positiveSuffix]];
  [generalPointSizeFormatter setZeroSymbol:generalPointSizeZeroSymbol];
  
  [marginsAdditionalPointSizeFormatter setLocale:[NSLocale currentLocale]];
  [marginsAdditionalPointSizeFormatter setGroupingSeparator:[[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator]];
  [marginsAdditionalPointSizeFormatter setDecimalSeparator:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
  NSString* marginsAdditionalPointSizeZeroSymbol =
  [NSString stringWithFormat:@"0%@%0*d%@",
   [marginsAdditionalPointSizeFormatter decimalSeparator], 2, 0, 
   [marginsAdditionalPointSizeFormatter positiveSuffix]];
  [marginsAdditionalPointSizeFormatter setZeroSymbol:marginsAdditionalPointSizeZeroSymbol];
  
  [servicePointSizeFactorFormatter setLocale:[NSLocale currentLocale]];
  [servicePointSizeFactorFormatter setGroupingSeparator:[[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator]];
  [servicePointSizeFactorFormatter setDecimalSeparator:[[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator]];
  NSString* servicePointSizeZeroSymbol =
  [NSString stringWithFormat:@"0%@%0*d%@",
   [servicePointSizeFactorFormatter decimalSeparator], 2, 0, 
   [servicePointSizeFactorFormatter positiveSuffix]];
  [servicePointSizeFactorFormatter setZeroSymbol:servicePointSizeZeroSymbol];
  
  viewsMinSizes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
    [NSValue valueWithSize:[generalView frame].size], GeneralToolbarItemIdentifier,
    [NSValue valueWithSize:[editionView frame].size], EditionToolbarItemIdentifier,
    [NSValue valueWithSize:[templatesView frame].size], TemplatesToolbarItemIdentifier,
    [NSValue valueWithSize:[compositionView frame].size], CompositionToolbarItemIdentifier,
    [NSValue valueWithSize:[libraryView frame].size], LibraryToolbarItemIdentifier,
    [NSValue valueWithSize:[historyView frame].size], HistoryToolbarItemIdentifier,
    [NSValue valueWithSize:[serviceView frame].size], ServiceToolbarItemIdentifier,
    [NSValue valueWithSize:[pluginsView frame].size], PluginsToolbarItemIdentifier,
    [NSValue valueWithSize:[advancedView frame].size], AdvancedToolbarItemIdentifier,
    [NSValue valueWithSize:[webView frame].size], WebToolbarItemIdentifier,
    nil];
  
  if (!isMacOS10_5OrAbove())
  {
    NSArray* compositionConfigurationsCurrentAdvancedButtons = [NSArray arrayWithObjects:
      compositionConfigurationsCurrentPdfLaTeXAdvancedButton, compositionConfigurationsCurrentXeLaTeXAdvancedButton,
      compositionConfigurationsCurrentLaTeXAdvancedButton, compositionConfigurationsCurrentDviPdfAdvancedButton,
      compositionConfigurationsCurrentGsAdvancedButton, compositionConfigurationsCurrentPsToPdfAdvancedButton, nil];
    NSEnumerator* enumerator = [compositionConfigurationsCurrentAdvancedButtons objectEnumerator];
    NSButton* button = nil;
    while((button = [enumerator nextObject]))
      [button setImage:[NSImage imageNamed:@"NSActionTemplate10_4"]];
  }//end if (!isMacOS10_5OrAbove())
  
  NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"preferencesToolbar"];
  [toolbar setDelegate:(id)self];
  NSWindow* window = [self window];
  [window setDelegate:(id)self];
  [window setToolbar:toolbar];
  [window setShowsToolbarButton:NO];
  [toolbar setSelectedItemIdentifier:GeneralToolbarItemIdentifier];
  [self toolbarHit:[toolbarItems objectForKey:[toolbar selectedItemIdentifier]]];
  [toolbar release];
  
  NSUserDefaultsController* userDefaultsController = [NSUserDefaultsController sharedUserDefaultsController];
  PreferencesController* preferencesController = [PreferencesController sharedController];

  //General
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"PDF vector format", @"PDF vector format")
    tag:(int)EXPORT_FORMAT_PDF];
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"PDF with outlined fonts", @"PDF with outlined fonts")
    tag:(int)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"EPS vector format", @"EPS vector format")
    tag:(int)EXPORT_FORMAT_EPS];
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"SVG vector format", @"SVG vector format")
    tag:(int)EXPORT_FORMAT_SVG];
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"TIFF bitmap format", @"TIFF bitmap format")
    tag:(int)EXPORT_FORMAT_TIFF];
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"PNG bitmap format", @"PNG bitmap format")
    tag:(int)EXPORT_FORMAT_PNG];
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"JPEG bitmap format", @"JPEG bitmap format")
    tag:(int)EXPORT_FORMAT_JPEG];
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"MathML text format", @"MathML text format")
    tag:(int)EXPORT_FORMAT_MATHML];
  [generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"Text format", @"Text format")
    tag:(int)EXPORT_FORMAT_TEXT];
  [generalExportFormatPopupButton setTarget:self];
  [generalExportFormatPopupButton setAction:@selector(nilAction:)];
  [generalExportFormatPopupButton bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey] options:nil];
  [generalExportScaleLabel bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:EXPORT_FORMAT_MATHML]], NSValueTransformerBindingOption, nil]];
  [generalExportScalePercentTextField bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:EXPORT_FORMAT_MATHML]], NSValueTransformerBindingOption, nil]];
  [generalExportFormatOptionsButton bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsInTransformer transformerWithReferences:
        [NSArray arrayWithObjects:[NSNumber numberWithInt:EXPORT_FORMAT_JPEG],
                                  [NSNumber numberWithInt:EXPORT_FORMAT_SVG],
                                  [NSNumber numberWithInt:EXPORT_FORMAT_TEXT],
                                  nil]],
        NSValueTransformerBindingOption, nil]];
  [generalExportFormatOptionsButton setTarget:self];
  [generalExportFormatOptionsButton setAction:@selector(generalExportFormatOptionsOpen:)];
  [generalExportFormatJpegWarning setTitle:
    NSLocalizedString(@"Warning : jpeg does not manage transparency", @"Warning : jpeg does not manage transparency")];
  [generalExportFormatJpegWarning sizeToFit];
  [generalExportFormatJpegWarning centerInSuperviewHorizontally:YES vertically:NO];
  [generalExportFormatJpegWarning bind:NSHiddenBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:EXPORT_FORMAT_JPEG]], NSValueTransformerBindingOption, nil]];
  [generalExportFormatSvgWarning setTitle:
    NSLocalizedString(@"Warning : pdf2svg was not found", @"Warning : pdf2svg was not found")];
  [generalExportFormatSvgWarning sizeToFit];
  [generalExportFormatSvgWarning centerInSuperviewHorizontally:YES vertically:NO];
  [generalExportFormatSvgWarning setTextColor:[NSColor redColor]];
  [generalExportFormatSvgWarning bind:NSHiddenBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:EXPORT_FORMAT_SVG]],
      NSValueTransformerBindingOption, nil]];
  NSString* NSHidden2Binding = [NSHiddenBinding stringByAppendingString:@"2"];
  [generalExportFormatSvgWarning bind:NSHidden2Binding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportSvgPdfToSvgPathKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [FileExistsTransformer transformerWithDirectoryAllowed:NO],
      NSValueTransformerBindingOption, nil]];

  [generalExportFormatMathMLWarning setTitle:
    NSLocalizedString(@"Warning : the XML::LibXML perl module was not found", @"Warning : the XML::LibXML perl module was not found")];
  [generalExportFormatMathMLWarning sizeToFit];
  [generalExportFormatMathMLWarning centerInSuperviewHorizontally:YES vertically:NO];
  [generalExportFormatMathMLWarning setTextColor:[NSColor redColor]];
  [generalExportFormatMathMLWarning bind:NSHiddenBinding toObject:userDefaultsController
                                withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
                                    options:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:EXPORT_FORMAT_MATHML]],
                                             NSValueTransformerBindingOption, nil]];
  [generalExportFormatMathMLWarning bind:NSHidden2Binding toObject:[AppController appController]
                                   withKeyPath:@"isPerlWithLibXMLAvailable"
                                       options:nil];
  
  [generalExportScalePercentTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportScaleAsPercentKey] options:nil];
  
  [generalDummyBackgroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultImageViewBackgroundKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [generalDummyBackgroundAutoStateButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultAutomaticHighContrastedPreviewBackgroundKey] options:nil];
  [generalDoNotClipPreviewButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultDoNotClipPreviewKey] options:nil];

  [generalLatexisationLaTeXModeSegmentedControl setSegmentCount:5];
  NSUInteger segmentIndex = 0;
  NSSegmentedCell* latexModeSegmentedCell = [generalLatexisationLaTeXModeSegmentedControl cell];
  [latexModeSegmentedCell setTag:LATEX_MODE_AUTO    forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Auto", @"Auto") forSegment:segmentIndex++];
  [latexModeSegmentedCell setTag:LATEX_MODE_ALIGN   forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Align", @"Align") forSegment:segmentIndex++];
  [latexModeSegmentedCell setTag:LATEX_MODE_DISPLAY forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Display", @"Display") forSegment:segmentIndex++];
  [latexModeSegmentedCell setTag:LATEX_MODE_INLINE  forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Inline", @"Inline") forSegment:segmentIndex++];
  [latexModeSegmentedCell setTag:LATEX_MODE_TEXT    forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Text", @"Text") forSegment:segmentIndex++];
  [generalLatexisationLaTeXModeSegmentedControl bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultModeKey] options:nil];

  [generalLatexisationFontSizeTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultPointSizeKey] options:nil];
  [generalLatexisationFontColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];

  //margins
  [marginsAdditionalTopTextField    setFormatter:marginsAdditionalPointSizeFormatter];
  [marginsAdditionalLeftTextField   setFormatter:marginsAdditionalPointSizeFormatter];
  [marginsAdditionalRightTextField  setFormatter:marginsAdditionalPointSizeFormatter];
  [marginsAdditionalBottomTextField setFormatter:marginsAdditionalPointSizeFormatter];
  [marginsAdditionalTopTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:AdditionalTopMarginKey] options:nil];
  [marginsAdditionalLeftTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:AdditionalLeftMarginKey] options:nil];
  [marginsAdditionalRightTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:AdditionalRightMarginKey] options:nil];
  [marginsAdditionalBottomTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:AdditionalBottomMarginKey] options:nil];

  //Edition
  [editionFontNameTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultFontKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [ComposedTransformer
        transformerWithValueTransformer:[NSValueTransformer valueTransformerForName:[KeyedUnarchiveFromDataTransformer name]]
        additionalValueTransformer:nil
        additionalKeyPath:@"displayNameWithPointSize"], NSValueTransformerBindingOption, nil]];
  [editionSyntaxColoringStateButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringEnableKey]
    options:nil];
  [editionSyntaxColoringTextForegroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringTextForegroundColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [editionSyntaxColoringTextBackgroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringTextBackgroundColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [editionSyntaxColoringCommandColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringCommandColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [editionSyntaxColoringKeywordColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringKeywordColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [editionSyntaxColoringMathsColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringMathsColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [editionSyntaxColoringCommentColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringCommentColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [editionSpellCheckingStateButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SpellCheckingEnableKey]
    options:nil];
  [editionTabKeyInsertsSpacesCheckBox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EditionTabKeyInsertsSpacesEnabledKey]
    options:nil];
  [editionTabKeyInsertsSpacesTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EditionTabKeyInsertsSpacesCountKey]
    options:nil];
  [editionTabKeyInsertsSpacesTextField bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EditionTabKeyInsertsSpacesEnabledKey]
    options:nil];
  [editionTabKeyInsertsSpacesStepper bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EditionTabKeyInsertsSpacesCountKey]
    options:nil];
  [editionTabKeyInsertsSpacesStepper bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EditionTabKeyInsertsSpacesEnabledKey]
    options:nil];
  
  [editionTextAreaReducedButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ReducedTextAreaStateKey] options:nil];

  NSArrayController* editionTextShortcutsController = [preferencesController editionTextShortcutsController];
  [editionTextShortcutsAddButton bind:NSEnabledBinding toObject:editionTextShortcutsController withKeyPath:@"canAdd" options:nil];
  [editionTextShortcutsAddButton setTarget:editionTextShortcutsController];
  [editionTextShortcutsAddButton setAction:@selector(add:)];
  [editionTextShortcutsRemoveButton bind:NSEnabledBinding toObject:editionTextShortcutsController withKeyPath:@"canRemove" options:nil];
  [editionTextShortcutsRemoveButton setTarget:editionTextShortcutsController];
  [editionTextShortcutsRemoveButton setAction:@selector(remove:)];
  
  [self performSelector:@selector(afterAwakeFromNib:) withObject:nil afterDelay:0];
  [editionSyntaxColouringTextView
    bind:NSFontBinding toObject:userDefaultsController withKeyPath:[userDefaultsController adaptedKeyPath:DefaultFontKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      NSUnarchiveFromDataTransformerName, NSValueTransformerNameBindingOption,
      nil]];

  //Preambles
  PreamblesController* preamblesController = [preferencesController preamblesController];
  [preamblesAddButton setTarget:preamblesController];
  [preamblesAddButton setAction:@selector(add:)];
  [preamblesAddButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"canAdd" options:nil];
  [preamblesRemoveButton setTarget:preamblesController];
  [preamblesRemoveButton setAction:@selector(remove:)];
  [preamblesRemoveButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"canRemove" options:nil];
  [preamblesValueTextView bind:NSAttributedStringBinding toObject:preamblesController withKeyPath:@"selection.value" options:
    [NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [preamblesValueTextView bind:NSEditableBinding toObject:preamblesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  [preamblesController addObserver:self forKeyPath:@"selection.value" options:0 context:nil];//to recolour the preamblesValueTextView...
  [self observeValueForKeyPath:@"selection.value" ofObject:preamblesController change:nil context:nil];
  
  [preamblesValueResetDefaultButton setTarget:self];
  [preamblesValueResetDefaultButton setAction:@selector(preamblesValueResetDefault:)];
  [preamblesValueResetDefaultButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];

  [preamblesValueApplyToOpenedDocumentsButton setTarget:self];
  [preamblesValueApplyToOpenedDocumentsButton setAction:@selector(preamblesValueApplyToOpenedDocuments:)];
  [preamblesValueApplyToOpenedDocumentsButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];

  [preamblesValueApplyToLibraryButton setTarget:self];
  [preamblesValueApplyToLibraryButton setAction:@selector(preamblesValueApplyToLibrary:)];
  [preamblesValueApplyToLibraryButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  
  [preamblesNamesLatexisationPopUpButton bind:NSContentValuesBinding toObject:preamblesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [preamblesNamesLatexisationPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:LatexisationSelectedPreambleIndexKey] options:nil];

  //BodyTemplates
  BodyTemplatesController* bodyTemplatesController = [preferencesController bodyTemplatesController];
  [bodyTemplatesAddButton setTarget:bodyTemplatesController];
  [bodyTemplatesAddButton setAction:@selector(add:)];
  [bodyTemplatesAddButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"canAdd" options:nil];
  [bodyTemplatesRemoveButton setTarget:bodyTemplatesController];
  [bodyTemplatesRemoveButton setAction:@selector(remove:)];
  [bodyTemplatesRemoveButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"canRemove" options:nil];
  [bodyTemplatesHeadTextView bind:NSAttributedStringBinding toObject:bodyTemplatesController withKeyPath:@"selection.head" options:
    [NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [bodyTemplatesHeadTextView bind:NSEditableBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  [bodyTemplatesTailTextView bind:NSAttributedStringBinding toObject:bodyTemplatesController withKeyPath:@"selection.tail" options:
    [NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [bodyTemplatesTailTextView bind:NSEditableBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  [bodyTemplatesController addObserver:self forKeyPath:@"selection.head" options:0 context:nil];//to recolour the bodyTemplatesHeadTextView
  [bodyTemplatesController addObserver:self forKeyPath:@"selection.tail" options:0 context:nil];//to recolour the bodyTemplatesTailTextView
  [self observeValueForKeyPath:@"selection.head" ofObject:bodyTemplatesController change:nil context:nil];
  [self observeValueForKeyPath:@"selection.tail" ofObject:bodyTemplatesController change:nil context:nil];
  
  [bodyTemplatesApplyToOpenedDocumentsButton setTarget:self];
  [bodyTemplatesApplyToOpenedDocumentsButton setAction:@selector(bodyTemplatesApplyToOpenedDocuments:)];
  [bodyTemplatesApplyToOpenedDocumentsButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];

  [bodyTemplatesNamesLatexisationPopUpButton bind:NSContentValuesBinding toObject:bodyTemplatesController
    withKeyPath:@"arrangedObjectsNamesWithNone" options:nil];
  [bodyTemplatesNamesLatexisationPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:LatexisationSelectedBodyTemplateIndexKey] options:
      [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumberIntegerShiftTransformer transformerWithShift:[NSNumber numberWithInt:1]],
        NSValueTransformerBindingOption, nil]];

  //Composition configurations
  CompositionConfigurationsController* compositionConfigurationsController = [preferencesController compositionConfigurationsController];
  [compositionConfigurationsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
  [userDefaultsController addObserver:self forKeyPath:[userDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]
    options:NSKeyValueObservingOptionNew context:nil];
  [compositionConfigurationsController addObserver:self forKeyPath:[@"arrangedObjects." stringByAppendingString:CompositionConfigurationNameKey]
      options:NSKeyValueObservingOptionNew context:nil];
  [self observeValueForKeyPath:@"arrangedObjects" ofObject:compositionConfigurationsController change:nil context:nil];
  [self observeValueForKeyPath:[userDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey] ofObject:userDefaultsController
    change:nil context:nil];
  [compositionConfigurationsCurrentPopUpButton setTarget:self];
  [compositionConfigurationsCurrentPopUpButton setAction:@selector(compositionConfigurationsManagerOpen:)];

  [compositionConfigurationsProgramArgumentsAddButton setTarget:compositionConfigurationsProgramArgumentsTableView];
  [compositionConfigurationsProgramArgumentsAddButton setAction:@selector(add:)];
  [compositionConfigurationsProgramArgumentsRemoveButton setTarget:compositionConfigurationsProgramArgumentsTableView];
  [compositionConfigurationsProgramArgumentsRemoveButton setAction:@selector(remove:)];
  [compositionConfigurationsProgramArgumentsOkButton setTarget:self];
  [compositionConfigurationsProgramArgumentsOkButton setAction:@selector(compositionConfigurationsProgramArgumentsClose:)];

  [compositionConfigurationsManagerAddButton bind:NSEnabledBinding toObject:compositionConfigurationsController withKeyPath:@"canAdd" options:nil];
  [compositionConfigurationsManagerAddButton setTarget:compositionConfigurationsController];
  [compositionConfigurationsManagerAddButton setAction:@selector(add:)];
  [compositionConfigurationsManagerRemoveButton bind:NSEnabledBinding toObject:compositionConfigurationsController withKeyPath:@"canRemove" options:nil];
  [compositionConfigurationsManagerRemoveButton setTarget:compositionConfigurationsController];
  [compositionConfigurationsManagerRemoveButton setAction:@selector(remove:)];
  [compositionConfigurationsManagerOkButton setTarget:self];
  [compositionConfigurationsManagerOkButton setAction:@selector(compositionConfigurationsManagerClose:)];

  NSDictionary* isNotNilBindingOptions =
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil];
  NSString* NSEnabled2Binding = [NSEnabledBinding stringByAppendingString:@"2"];

  [compositionConfigurationsCurrentEngineMatrix bind:NSSelectedTagBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey] options:nil];
  [compositionConfigurationsCurrentLoginShellUsedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentLoginShellUsedButton bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationUseLoginShellKey] options:nil];
  [compositionConfigurationsCurrentResetButton setTitle:NSLocalizedString(@"Reset...", @"Reset...")];
  [compositionConfigurationsCurrentResetButton sizeToFit];
  [compositionConfigurationsCurrentResetButton setTarget:self];
  [compositionConfigurationsCurrentResetButton setAction:@selector(compositionConfigurationsCurrentReset:)];
  
  NSDictionary* colorForFileExistsBindingOptions =
    [NSDictionary dictionaryWithObjectsAndKeys:
      [ComposedTransformer
        transformerWithValueTransformer:[FileExistsTransformer transformerWithDirectoryAllowed:NO]
             additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor controlTextColor]]
             additionalKeyPath:nil], NSValueTransformerBindingOption, nil];
  NSDictionary* colorForFolderExistsBindingOptions =
    [NSDictionary dictionaryWithObjectsAndKeys:
      [ComposedTransformer
        transformerWithValueTransformer:[FolderExistsTransformer transformer]
             additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor controlTextColor]]
             additionalKeyPath:nil], NSValueTransformerBindingOption, nil];

  [compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey]
        options:nil];
  [compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentPdfLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentPdfLaTeXAdvancedButton setTarget:self];
  [compositionConfigurationsCurrentPdfLaTeXAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [compositionConfigurationsCurrentPdfLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentPdfLaTeXPathChangeButton setTarget:self];
  [compositionConfigurationsCurrentPdfLaTeXPathChangeButton setAction:@selector(changePath:)];

  [[compositionConfigurationsCurrentXeLaTeXPathTextField cell] setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey] options:nil];
  [compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_XELATEX]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentXeLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentXeLaTeXAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_XELATEX]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentXeLaTeXAdvancedButton setTarget:self];
  [compositionConfigurationsCurrentXeLaTeXAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [compositionConfigurationsCurrentXeLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentXeLaTeXPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_XELATEX]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentXeLaTeXPathChangeButton setTarget:self];
  [compositionConfigurationsCurrentXeLaTeXPathChangeButton setAction:@selector(changePath:)];

  [[compositionConfigurationsCurrentLaTeXPathTextField cell] setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLatexPathKey] options:nil];
  [compositionConfigurationsCurrentLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentLaTeXPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLatexPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentLaTeXAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentLaTeXAdvancedButton setTarget:self];
  [compositionConfigurationsCurrentLaTeXAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [compositionConfigurationsCurrentLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentLaTeXPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentLaTeXPathChangeButton setTarget:self];
  [compositionConfigurationsCurrentLaTeXPathChangeButton setAction:@selector(changePath:)];

  [[compositionConfigurationsCurrentDviPdfPathTextField cell] setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentDviPdfPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationDviPdfPathKey] options:nil];
  [compositionConfigurationsCurrentDviPdfPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentDviPdfPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentDviPdfPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationDviPdfPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentDviPdfAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentDviPdfAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentDviPdfAdvancedButton setTarget:self];
  [compositionConfigurationsCurrentDviPdfAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [compositionConfigurationsCurrentDviPdfPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentDviPdfPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsCurrentDviPdfPathChangeButton setTarget:self];
  [compositionConfigurationsCurrentDviPdfPathChangeButton setAction:@selector(changePath:)];

  [[compositionConfigurationsCurrentGsPathTextField cell] setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentGsPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationGsPathKey] options:nil];
  [compositionConfigurationsCurrentGsPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentGsPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationGsPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentGsAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentGsAdvancedButton setTarget:self];
  [compositionConfigurationsCurrentGsAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [compositionConfigurationsCurrentGsPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentGsPathChangeButton setTarget:self];
  [compositionConfigurationsCurrentGsPathChangeButton setAction:@selector(changePath:)];

  [[compositionConfigurationsCurrentPsToPdfPathTextField cell] setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentPsToPdfPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPsToPdfPathKey] options:nil];
  [compositionConfigurationsCurrentPsToPdfPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentPsToPdfPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPsToPdfPathKey] options:colorForFileExistsBindingOptions];
  [compositionConfigurationsCurrentPsToPdfPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];

  [compositionConfigurationsCurrentPsToPdfAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentPsToPdfAdvancedButton setTarget:self];
  [compositionConfigurationsCurrentPsToPdfAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [compositionConfigurationsCurrentPsToPdfPathChangeButton setTarget:self];
  [compositionConfigurationsCurrentPsToPdfPathChangeButton setAction:@selector(changePath:)];
  
  [self updateProgramArgumentsToolTips];

  //history
  [historySaveServiceResultsCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceUsesHistoryKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
  [historyDeleteOldEntriesCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
  [historyDeleteOldEntriesLimitTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesLimitKey]
    options:nil];
  [historyDeleteOldEntriesLimitTextField bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:nil];
  [historyDeleteOldEntriesLimitStepper setFormatter:[historyDeleteOldEntriesLimitTextField formatter]];
  [historyDeleteOldEntriesLimitStepper bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesLimitKey]
    options:nil];
  [historyDeleteOldEntriesLimitStepper bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:nil];
  [historySmartCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistorySmartEnabledKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];

  // additional scripts
  [[compositionConfigurationsAdditionalScriptsTableView tableColumnWithIdentifier:@"place"] bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
 withKeyPath:@"arrangedObjects.key"
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [ObjectTransformer transformerWithDictionary:
        [NSDictionary dictionaryWithObjectsAndKeys:
          NSLocalizedString(@"Pre-processing", @"Pre-processing"), [[NSNumber numberWithInt:SCRIPT_PLACE_PREPROCESSING] stringValue], 
          NSLocalizedString(@"Middle-processing", @"Middle-processing"), [[NSNumber numberWithInt:SCRIPT_PLACE_MIDDLEPROCESSING] stringValue], 
          NSLocalizedString(@"Post-processing", @"Post-processing"), [[NSNumber numberWithInt:SCRIPT_PLACE_POSTPROCESSING] stringValue], nil]],
       NSValueTransformerBindingOption, nil]];
  [[compositionConfigurationsAdditionalScriptsTableView tableColumnWithIdentifier:@"enabled"] bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[@"arrangedObjects.value." stringByAppendingString:CompositionConfigurationAdditionalProcessingScriptEnabledKey]
    options:nil];

  [compositionConfigurationsAdditionalScriptsTypePopUpButton removeAllItems];
  [[[compositionConfigurationsAdditionalScriptsTypePopUpButton menu]
    addItemWithTitle:NSLocalizedString(@"Define a script", @"Define a script") action:nil keyEquivalent:@""] setTag:SCRIPT_SOURCE_STRING];
  [[[compositionConfigurationsAdditionalScriptsTypePopUpButton menu]
    addItemWithTitle:NSLocalizedString(@"Use existing script", @"Use existing script") action:nil keyEquivalent:@""] setTag:SCRIPT_SOURCE_FILE];
  [compositionConfigurationsAdditionalScriptsTypePopUpButton bind:NSSelectedTagBinding
     toObject:[compositionConfigurationsController currentConfigurationScriptsController]
     withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
     options:nil];
     
  [compositionConfigurationsAdditionalScriptsTypePopUpButton bind:NSEnabledBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:@"selection" options:isNotNilBindingOptions];

  [compositionConfigurationsAdditionalScriptsDefiningBox bind:NSHiddenBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_STRING]], NSValueTransformerBindingOption, nil]];
  [compositionConfigurationsAdditionalScriptsExistingBox bind:NSHiddenBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_FILE]], NSValueTransformerBindingOption, nil]];

  [compositionConfigurationsAdditionalScriptsDefiningShellTextField bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
    options:nil];
  [compositionConfigurationsAdditionalScriptsDefiningShellTextField bind:NSTextColorBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
    options:colorForFileExistsBindingOptions];
  [compositionConfigurationsAdditionalScriptsDefiningContentTextView setFont:[NSFont fontWithName:@"Monaco" size:12.]];
  [compositionConfigurationsAdditionalScriptsDefiningContentTextView bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptContentKey]
    options:nil];

  [compositionConfigurationsAdditionalScriptsExistingPathTextField bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]
    options:nil];
  [compositionConfigurationsAdditionalScriptsExistingPathTextField bind:NSTextColorBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]
    options:colorForFileExistsBindingOptions];
  [compositionConfigurationsAdditionalScriptsExistingPathChangeButton setTarget:self];
  [compositionConfigurationsAdditionalScriptsExistingPathChangeButton setAction:@selector(changePath:)];

  //service
  [servicePreamblePopUpButton bind:NSContentValuesBinding toObject:preamblesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [servicePreamblePopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceSelectedPreambleIndexKey] options:nil];
  [serviceBodyTemplatesPopUpButton bind:NSContentValuesBinding toObject:bodyTemplatesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [serviceBodyTemplatesPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceSelectedBodyTemplateIndexKey] options:nil];

  [[serviceRespectsPointSizeMatrix cellAtRow:0 column:0] setTag:0];
  [[serviceRespectsPointSizeMatrix cellAtRow:1 column:0] setTag:1];
  [serviceRespectsPointSizeMatrix bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsPointSizeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:0] trueValue:[NSNumber numberWithInt:1]], NSValueTransformerBindingOption, nil]];
  [servicePointSizeFactorTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServicePointSizeFactorKey] options:nil];
  [servicePointSizeFactorStepper bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServicePointSizeFactorKey] options:nil];
  [servicePointSizeFactorTextField setFormatter:servicePointSizeFactorFormatter];
  [servicePointSizeFactorStepper   setFormatter:servicePointSizeFactorFormatter];

  [[serviceRespectsColorMatrix cellAtRow:0 column:0] setTag:0];
  [[serviceRespectsColorMatrix cellAtRow:1 column:0] setTag:1];
  [serviceRespectsColorMatrix bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:0] trueValue:[NSNumber numberWithInt:1]], NSValueTransformerBindingOption, nil]];

  [serviceRespectsBaselineButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsBaselineKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
  [serviceWarningLinkBackButton bind:NSHiddenBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsBaselineKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];

  [serviceUsesHistoryButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceUsesHistoryKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
      
  [serviceRelaunchWarning setHidden:isMacOS10_5OrAbove()];
  
  //service regular expression filters
  NSArrayController* serviceRegularExpressionFiltersController = [preferencesController serviceRegularExpressionFiltersController];
  [serviceRegularExpressionFiltersController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
  [serviceRegularExpressionFiltersController addObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterEnabledKey] options:0 context:nil];
  [serviceRegularExpressionFiltersController addObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterInputPatternKey] options:0 context:nil];
  [serviceRegularExpressionFiltersController addObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterOutputPatternKey] options:0 context:nil];
  [serviceRegularExpressionsAddButton bind:NSEnabledBinding toObject:serviceRegularExpressionFiltersController withKeyPath:@"canAdd" options:nil];
  [serviceRegularExpressionsAddButton setTarget:serviceRegularExpressionFiltersController];
  [serviceRegularExpressionsAddButton setAction:@selector(add:)];

  [serviceRegularExpressionsRemoveButton bind:NSEnabledBinding toObject:serviceRegularExpressionFiltersController withKeyPath:@"canRemove" options:nil];
  [serviceRegularExpressionsRemoveButton setTarget:serviceRegularExpressionFiltersController];
  [serviceRegularExpressionsRemoveButton setAction:@selector(remove:)];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextDidChangeNotification object:serviceRegularExpressionsTestInputTextView];
  [serviceRegularExpressionsTestInputTextView setDelegate:(id)self];
  [serviceRegularExpressionsTestInputTextView setFont:[NSFont controlContentFontOfSize:0]];
  [serviceRegularExpressionsTestInputTextView setPlaceHolder:NSLocalizedString(@"Text to test", @"Text to test")];
  if ([serviceRegularExpressionsTestInputTextView respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)])
    [serviceRegularExpressionsTestInputTextView setAutomaticTextReplacementEnabled:NO];
  [serviceRegularExpressionsTestOutputTextView setFont:[NSFont controlContentFontOfSize:0]];
  [serviceRegularExpressionsTestOutputTextView setPlaceHolder:NSLocalizedString(@"Result of text filtering", @"Result of text filtering")];
  if ([serviceRegularExpressionsTestOutputTextView respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)])
    [serviceRegularExpressionsTestOutputTextView setAutomaticTextReplacementEnabled:NO];

  [serviceRegularExpressionsHelpButton setTarget:self];
  [serviceRegularExpressionsHelpButton setAction:@selector(serviceRegularExpressionsHelpOpen:)];

  //additional files
  AdditionalFilesController* additionalFilesController = [preferencesController additionalFilesController];
  [additionalFilesAddButton bind:NSEnabledBinding toObject:additionalFilesController withKeyPath:@"canAdd" options:nil];
  [additionalFilesAddButton setTarget:additionalFilesTableView];
  [additionalFilesAddButton setAction:@selector(addFiles:)];
  [additionalFilesRemoveButton bind:NSEnabledBinding toObject:additionalFilesController withKeyPath:@"canRemove" options:nil];
  [additionalFilesRemoveButton setTarget:additionalFilesController];
  [additionalFilesRemoveButton setAction:@selector(remove:)];
  [additionalFilesHelpButton setTarget:self];
  [additionalFilesHelpButton setAction:@selector(additionalFilesHelpOpen:)];
  
  //background synchronization
  [synchronizationNewDocumentsEnabledButton bind:NSValueBinding
                                              toObject:userDefaultsController
                                           withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsEnabledKey]
                                               options:nil];
  [synchronizationNewDocumentsSynchronizePreambleCheckBox setTitle:NSLocalizedString(@"Synchronize preamble", @"Synchronize preamble")];
  [synchronizationNewDocumentsSynchronizePreambleCheckBox sizeToFit];
  [synchronizationNewDocumentsSynchronizePreambleCheckBox bind:NSValueBinding
                                              toObject:userDefaultsController
                                           withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsSynchronizePreambleKey]
                                               options:nil];
  [synchronizationNewDocumentsSynchronizePreambleCheckBox bind:NSEnabledBinding
                                                            toObject:userDefaultsController
                                                         withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsEnabledKey]
                                                             options:nil];
  [synchronizationNewDocumentsSynchronizeEnvironmentCheckBox setTitle:NSLocalizedString(@"Synchronize environment", @"Synchronize environment")];
  [synchronizationNewDocumentsSynchronizeEnvironmentCheckBox sizeToFit];
  [synchronizationNewDocumentsSynchronizeEnvironmentCheckBox bind:NSValueBinding
                                                            toObject:userDefaultsController
                                                         withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsSynchronizeEnvironmentKey]
                                                             options:nil];
  [synchronizationNewDocumentsSynchronizeEnvironmentCheckBox bind:NSEnabledBinding
                                                            toObject:userDefaultsController
                                                         withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsEnabledKey]
                                                             options:nil];
  [synchronizationNewDocumentsSynchronizeBodyCheckBox setTitle:NSLocalizedString(@"Synchronize body", @"Synchronize body")];
  [synchronizationNewDocumentsSynchronizeBodyCheckBox sizeToFit];
  [synchronizationNewDocumentsSynchronizeBodyCheckBox bind:NSValueBinding
                                                               toObject:userDefaultsController
                                                            withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsSynchronizeBodyKey]
                                                                options:nil];
  [synchronizationNewDocumentsSynchronizeBodyCheckBox bind:NSEnabledBinding
                                                               toObject:userDefaultsController
                                                            withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsEnabledKey]
                                                                options:nil];
  
  [synchronizationNewDocumentsPathTextField bind:NSEnabledBinding
                                              toObject:userDefaultsController
                                           withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsEnabledKey]
                                               options:nil];
  [synchronizationNewDocumentsPathTextField setSelectable:YES];
  [synchronizationNewDocumentsPathTextField setEditable:NO];
  [synchronizationNewDocumentsPathTextField setBordered:NO];
  [synchronizationNewDocumentsPathTextField setDrawsBackground:NO];
  [synchronizationNewDocumentsPathTextField bind:NSValueBinding
                                              toObject:userDefaultsController
                                           withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsPathKey]
                                               options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [FilePathLocalizedTransformer transformer], NSValueTransformerBindingOption,
                                                          nil]];
                                                        
  [synchronizationNewDocumentsPathTextField bind:NSTextColorBinding
                                              toObject:userDefaultsController
                                           withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsPathKey]
                                               options:colorForFolderExistsBindingOptions];
  [synchronizationNewDocumentsPathChangeButton bind:NSEnabledBinding
                                              toObject:userDefaultsController
                                           withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsEnabledKey]
                                               options:nil];
  [synchronizationNewDocumentsPathChangeButton setTarget:self];
  [synchronizationNewDocumentsPathChangeButton setAction:@selector(changePath:)];
  
  
  SynchronizationAdditionalScriptsController* synchronizationAdditionalScriptsController = [preferencesController synchronizationAdditionalScriptsController];
  [[synchronizationAdditionalScriptsTableView tableColumnWithIdentifier:@"place"] bind:NSValueBinding
                                                                                    toObject:synchronizationAdditionalScriptsController
                                                                                 withKeyPath:@"arrangedObjects.key"
                                                                                     options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                               [ObjectTransformer transformerWithDictionary:
                                                                                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                   NSLocalizedString(@"Pre-processing on load", @"Pre-processing on load"), [[NSNumber numberWithInt:SYNCHRONIZATION_SCRIPT_PLACE_LOADING_PREPROCESSING] stringValue], 
                                                                                                   NSLocalizedString(@"Post-processing on load", @"Post-processing on load"), [[NSNumber numberWithInt:SYNCHRONIZATION_SCRIPT_PLACE_LOADING_POSTPROCESSING] stringValue], 
                                                                                                   NSLocalizedString(@"Pre-processing on save", @"Pre-processing on save"), [[NSNumber numberWithInt:SYNCHRONIZATION_SCRIPT_PLACE_SAVING_PREPROCESSING] stringValue], 
                                                                                                   NSLocalizedString(@"Post-processing on save", @"Post-processing on save"), [[NSNumber numberWithInt:SYNCHRONIZATION_SCRIPT_PLACE_SAVING_POSTPROCESSING] stringValue],
                                                                                                   nil]], NSValueTransformerBindingOption,
                                                                                               nil]];
  [[synchronizationAdditionalScriptsTableView tableColumnWithIdentifier:@"enabled"] bind:NSValueBinding
                                                                                      toObject:synchronizationAdditionalScriptsController
                                                                                   withKeyPath:[@"arrangedObjects.value." stringByAppendingString:CompositionConfigurationAdditionalProcessingScriptEnabledKey]
                                                                                       options:nil];
  
  [synchronizationAdditionalScriptsTypePopUpButton removeAllItems];
  [[[synchronizationAdditionalScriptsTypePopUpButton menu]
    addItemWithTitle:NSLocalizedString(@"Define a script", @"Define a script") action:nil keyEquivalent:@""] setTag:SCRIPT_SOURCE_STRING];
  [[[synchronizationAdditionalScriptsTypePopUpButton menu]
    addItemWithTitle:NSLocalizedString(@"Use existing script", @"Use existing script") action:nil keyEquivalent:@""] setTag:SCRIPT_SOURCE_FILE];
  [synchronizationAdditionalScriptsTypePopUpButton bind:NSSelectedTagBinding
                                                     toObject:synchronizationAdditionalScriptsController
                                                  withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
                                                      options:nil];

  [synchronizationAdditionalScriptsTypePopUpButton bind:NSEnabledBinding
                                                     toObject:synchronizationAdditionalScriptsController
                                                  withKeyPath:@"selection" options:isNotNilBindingOptions];
  
  [synchronizationAdditionalScriptsDefiningBox bind:NSHiddenBinding
                                                 toObject:synchronizationAdditionalScriptsController
                                              withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
                                                  options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                            [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_STRING]], NSValueTransformerBindingOption,
                                                            nil]];
  [synchronizationAdditionalScriptsDefiningBox bind:[NSHiddenBinding stringByAppendingString:@"2"]
                                                 toObject:synchronizationAdditionalScriptsController
                                              withKeyPath:@"selectionIndexes"
                                                  options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [IsEqualToTransformer transformerWithReference:[NSIndexSet indexSet]], NSValueTransformerBindingOption,
                                                           nil]];
  [synchronizationAdditionalScriptsExistingBox bind:NSHiddenBinding
                                                 toObject:synchronizationAdditionalScriptsController
                                              withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
                                                  options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                            [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_FILE]], NSValueTransformerBindingOption,
                                                            nil]];
  [synchronizationAdditionalScriptsExistingBox bind:[NSHiddenBinding stringByAppendingString:@"2"]
                                                 toObject:synchronizationAdditionalScriptsController
                                              withKeyPath:@"selectionIndexes"
                                                  options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [IsEqualToTransformer transformerWithReference:[NSIndexSet indexSet]], NSValueTransformerBindingOption,
                                                           nil]];
  
  [synchronizationAdditionalScriptsDefiningShellTextField bind:NSValueBinding
                                                            toObject:synchronizationAdditionalScriptsController
                                                         withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
                                                             options:nil];

  [synchronizationAdditionalScriptsDefiningShellTextField bind:NSTextColorBinding
                                                            toObject:synchronizationAdditionalScriptsController
                                                         withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
                                                             options:colorForFileExistsBindingOptions];
  [synchronizationAdditionalScriptsDefiningContentTextView setFont:[NSFont fontWithName:@"Monaco" size:12.]];
  [synchronizationAdditionalScriptsDefiningContentTextView bind:NSValueBinding
                                                             toObject:synchronizationAdditionalScriptsController
                                                          withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptContentKey]
                                                              options:nil];
  
  [synchronizationAdditionalScriptsExistingPathTextField bind:NSValueBinding
                                                           toObject:synchronizationAdditionalScriptsController
                                                        withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]
                                                            options:nil];
  [synchronizationAdditionalScriptsExistingPathTextField bind:NSTextColorBinding
                                                           toObject:synchronizationAdditionalScriptsController
                                                        withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]
                                                             options:colorForFileExistsBindingOptions];
  [synchronizationAdditionalScriptsExistingPathChangeButton setTarget:self];
  [synchronizationAdditionalScriptsExistingPathChangeButton setAction:@selector(changePath:)];

  //encapsulations
  EncapsulationsController* encapsulationsController = [preferencesController encapsulationsController];
  [encapsulationsEnabledCheckBox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];

  [encapsulationsLabel1 bind:NSTextColorBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [BoolTransformer transformerWithFalseValue:[NSColor disabledControlTextColor] trueValue:[NSColor controlTextColor]],
          NSValueTransformerBindingOption, nil]];
  [encapsulationsLabel2 bind:NSTextColorBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [BoolTransformer transformerWithFalseValue:[NSColor disabledControlTextColor] trueValue:[NSColor controlTextColor]],
          NSValueTransformerBindingOption, nil]];
  [encapsulationsLabel3 bind:NSTextColorBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [BoolTransformer transformerWithFalseValue:[NSColor disabledControlTextColor] trueValue:[NSColor controlTextColor]],
          NSValueTransformerBindingOption, nil]];

  [encapsulationsTableView bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey] options:nil];

  [encapsulationsAddButton bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey] options:nil];
  [encapsulationsAddButton bind:NSEnabled2Binding toObject:encapsulationsController withKeyPath:@"canAdd" options:nil];
  [encapsulationsAddButton setTarget:encapsulationsController];
  [encapsulationsAddButton setAction:@selector(add:)];

  [encapsulationsRemoveButton bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey] options:nil];
  [encapsulationsRemoveButton bind:NSEnabled2Binding toObject:encapsulationsController withKeyPath:@"canRemove" options:nil];
  [encapsulationsRemoveButton setTarget:encapsulationsController];
  [encapsulationsRemoveButton setAction:@selector(remove:)];

  //updates
  [updatesCheckUpdatesButton bind:NSValueBinding toObject:[[AppController appController] sparkleUpdater]
    withKeyPath:@"automaticallyChecksForUpdates"
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
      
  //plugins
  /* disabled for now */
  /* NSArrayController* pluginsController = [[NSArrayController alloc] initWithContent:[[PluginsManager sharedManager] plugins]];
  [pluginsPluginTableView bind:NSContentBinding toObject:pluginsController
    withKeyPath:@"content" options:nil];
  [[[pluginsPluginTableView tableColumns] lastObject] bind:NSValueBinding toObject:pluginsController
    withKeyPath:@"content.localizedName" options:nil];
  [pluginsPluginTableView setDelegate:(id)self];
  [self tableViewSelectionDidChange:[NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification object:pluginsPluginTableView]];
  [pluginsController release];*/
}
//end awakeFromNib

-(void) afterAwakeFromNib:(id)object
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  [editionSyntaxColouringTextView setFont:[preferencesController editionFont]];
}
//end afterAwakeFromNib:

//initializes the controls with default values
-(void) windowDidLoad
{
  NSPoint topLeftPoint  = [[self window] frame].origin;
  topLeftPoint.y       += [[self window] frame].size.height;
  //[[self window] setFrameAutosaveName:@"preferences"];
  [[self window] setFrameTopLeftPoint:topLeftPoint];
}
//end windowDidLoad

-(void) windowWillClose:(NSNotification *)aNotification
{
  //useful for font selection
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if ([fontManager delegate] == self)
    [fontManager setDelegate:nil];
  [[self window] makeFirstResponder:nil];//commit editing
  [[NSUserDefaults standardUserDefaults] synchronize];
}
//end windowWillClose:

-(NSSize) windowWillResize:(NSWindow*)window toSize:(NSSize)proposedFrameSize
{
  NSSize result = proposedFrameSize;
  if (window == [self window])
  {
    if (![window showsResizeIndicator])
    {
      result = [window frame].size;
      [window setFrameOrigin:[window frame].origin];
    }//end if (![window showsResizeIndicator])
  }//end if (window == [self window])
  return result;
}
//end windowWillResize:toSize:

-(NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
  return [NSArray arrayWithObjects:GeneralToolbarItemIdentifier,  EditionToolbarItemIdentifier,
                                   TemplatesToolbarItemIdentifier, CompositionToolbarItemIdentifier,
                                   LibraryToolbarItemIdentifier, HistoryToolbarItemIdentifier,
                                   ServiceToolbarItemIdentifier, //PluginsToolbarItemIdentifier,
                                   AdvancedToolbarItemIdentifier, WebToolbarItemIdentifier,
                                   nil];
}
//end toolbarDefaultItemIdentifiers:

-(NSArray*) toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
  return [self toolbarDefaultItemIdentifiers:toolbar];
}
//end toolbarAllowedItemIdentifiers:

-(NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar*)toolbar
{
  return [self toolbarDefaultItemIdentifiers:toolbar];
}
//end toolbarSelectableItemIdentifiers:
 
-(NSToolbarItem*) toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
  NSToolbarItem* item = [toolbarItems objectForKey:itemIdentifier];
  if (!item)
  {
    item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    
    NSString* label = nil;
    NSImage* image = nil;
    if ([itemIdentifier isEqualToString:GeneralToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:NSImageNamePreferencesGeneral];
      label = NSLocalizedString(@"General", @"General");
    }
    else if ([itemIdentifier isEqualToString:EditionToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:@"editionToolbarItem"];
      label = NSLocalizedString(@"Edition", @"Edition");
    }
    else if ([itemIdentifier isEqualToString:TemplatesToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:@"templatesToolbarItem"];
      label = NSLocalizedString(@"Templates", @"Templates");
    }
    else if ([itemIdentifier isEqualToString:CompositionToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:@"compositionToolbarItem"];
      label = NSLocalizedString(@"Composition", @"Composition");
    }
    else if ([itemIdentifier isEqualToString:LibraryToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:@"libraryToolbarItem"];
      label = NSLocalizedString(@"Library", @"Library");
    }
    else if ([itemIdentifier isEqualToString:HistoryToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:@"historyToolbarItem"];
      label = NSLocalizedString(@"History", @"History");
    }
    else if ([itemIdentifier isEqualToString:ServiceToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:@"serviceToolbarItem"];
      label = NSLocalizedString(@"Service", @"Service");
    }
    else if ([itemIdentifier isEqualToString:AdvancedToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:NSImageNameAdvanced];
      label = NSLocalizedString(@"Advanced", @"Advanced");
    }
    else if ([itemIdentifier isEqualToString:WebToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:@"webToolbarItem"];
      label = NSLocalizedString(@"Web", @"Web");
    }
    else if ([itemIdentifier isEqualToString:PluginsToolbarItemIdentifier])
    {
      image = [NSImage imageNamed:@"pluginsToolbarItem"];
      label = NSLocalizedString(@"Plugins", @"Plugins");
    }
    [item setLabel:label];
    [item setImage:image];

    [item setTarget:self];
    [item setAction:@selector(toolbarHit:)];
    [toolbarItems setObject:item forKey:itemIdentifier];
  }//end if (item)
  return item;
}
//end toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:

-(IBAction) toolbarHit:(id)sender
{
  NSView* view = nil;
  NSString* itemIdentifier = [sender itemIdentifier];

  if ([itemIdentifier isEqualToString:GeneralToolbarItemIdentifier])
    view = generalView;
  else if ([itemIdentifier isEqualToString:EditionToolbarItemIdentifier])
    view = editionView;
  else if ([itemIdentifier isEqualToString:TemplatesToolbarItemIdentifier])
    view = templatesView;
  else if ([itemIdentifier isEqualToString:CompositionToolbarItemIdentifier])
    view = compositionView;
  else if ([itemIdentifier isEqualToString:LibraryToolbarItemIdentifier])
    view = libraryView;
  else if ([itemIdentifier isEqualToString:HistoryToolbarItemIdentifier])
    view = historyView;
  else if ([itemIdentifier isEqualToString:ServiceToolbarItemIdentifier])
    view = serviceView;
  else if ([itemIdentifier isEqualToString:PluginsToolbarItemIdentifier])
    view = pluginsView;
  else if ([itemIdentifier isEqualToString:AdvancedToolbarItemIdentifier])
    view = advancedView;
  else if ([itemIdentifier isEqualToString:WebToolbarItemIdentifier])
    view = webView;

  NSWindow* window = [self window];
  NSView*   contentView = [window contentView];
  if (view != contentView)
  {
    NSSize contentMinSize = [[viewsMinSizes objectForKey:itemIdentifier] sizeValue];
    NSRect oldContentFrame = contentView ? [contentView frame] : NSZeroRect;
    NSRect newContentFrame = !view ? NSZeroRect : [view frame];
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
    [window setContentMinSize:contentMinSize];
  }//end if (view != contentView)
  
  [window setShowsResizeIndicator:
    [itemIdentifier isEqualToString:EditionToolbarItemIdentifier] ||
    [itemIdentifier isEqualToString:ServiceToolbarItemIdentifier]];

  //useful for font selection
  [window makeFirstResponder:nil];
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if ([fontManager delegate] == self)
    [fontManager setDelegate:nil];
    
  //update from SUUpdater
  [updatesCheckUpdatesNowButton setEnabled:![[[AppController appController] sparkleUpdater] updateInProgress]];
}
//end toolbarHit:

-(void) selectPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier options:(id)options
{
  if ([itemIdentifier isEqualToString:TemplatesToolbarItemIdentifier])
    [templatesTabView selectTabViewItemAtIndex:[options intValue]];
  [[[self window] toolbar] setSelectedItemIdentifier:itemIdentifier];
  [self toolbarHit:[toolbarItems objectForKey:itemIdentifier]];
}
//end selectPreferencesPaneWithItemIdentifier:

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok  = YES;
  if ([sender tag] == EXPORT_FORMAT_EPS)
    ok = [[AppController appController] isGsAvailable];
  else if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[AppController appController] isGsAvailable] && [[AppController appController] isPsToPdfAvailable];
  /*else if ([sender tag] == EXPORT_FORMAT_SVG)
    ok = [[AppController appController] isPdfToSvgAvailable];*/
  return ok;
}
//end validateMenuItem:

-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [[self window] makeFirstResponder:nil];//commit editing
}
//end applicationWillTerminate:

-(IBAction) nilAction:(id)sender
{
  //useful for validateMenuItem:
}
//end nilAction:

#pragma mark general

-(IBAction) generalExportFormatOptionsOpen:(id)sender
{
  if (!generalExportFormatOptionsPanes)
  {
    generalExportFormatOptionsPanes = [[ExportFormatOptionsPanes alloc] initWithLoadingFromNib];
    [generalExportFormatOptionsPanes setExportFormatOptionsJpegPanelDelegate:self];
    [generalExportFormatOptionsPanes setExportFormatOptionsSvgPanelDelegate:self];
    [generalExportFormatOptionsPanes setExportFormatOptionsTextPanelDelegate:self];
  }//end if (!generalExportFormatOptionsPanes)
  [generalExportFormatOptionsPanes setJpegQualityPercent:[[PreferencesController sharedController] exportJpegQualityPercent]];
  [generalExportFormatOptionsPanes setJpegBackgroundColor:[[PreferencesController sharedController] exportJpegBackgroundColor]];
  [generalExportFormatOptionsPanes setSvgPdfToSvgPath:[[PreferencesController sharedController] exportSvgPdfToSvgPath]];
  [generalExportFormatOptionsPanes setTextExportPreamble:[[PreferencesController sharedController] exportTextExportPreamble]];
  [generalExportFormatOptionsPanes setTextExportEnvironment:[[PreferencesController sharedController] exportTextExportEnvironment]];
  [generalExportFormatOptionsPanes setTextExportBody:[[PreferencesController sharedController] exportTextExportBody]];
 
  
  NSPanel* panelToOpen = nil;
  export_format_t format = (export_format_t)[generalExportFormatPopupButton selectedTag];
  if (format == EXPORT_FORMAT_JPEG)
    panelToOpen = [generalExportFormatOptionsPanes exportFormatOptionsJpegPanel];
  else if (format == EXPORT_FORMAT_SVG)
    panelToOpen = [generalExportFormatOptionsPanes exportFormatOptionsSvgPanel];
  else if (format == EXPORT_FORMAT_TEXT)
    panelToOpen = [generalExportFormatOptionsPanes exportFormatOptionsTextPanel];
  if (panelToOpen)
    [NSApp beginSheet:panelToOpen modalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}
//end openOptionsForDragExport:

-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok
{
  if (ok)
  {
    if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    {
      [[PreferencesController sharedController] setExportJpegQualityPercent:[generalExportFormatOptionsPanes jpegQualityPercent]];
      [[PreferencesController sharedController] setExportJpegBackgroundColor:[generalExportFormatOptionsPanes jpegBackgroundColor]];
    }//end if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    else if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    {
      [[PreferencesController sharedController] setExportSvgPdfToSvgPath:[generalExportFormatOptionsPanes svgPdfToSvgPath]];
    }//end if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    else if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsTextPanel])
    {
      [[PreferencesController sharedController] setExportTextExportPreamble:[generalExportFormatOptionsPanes textExportPreamble]];
      [[PreferencesController sharedController] setExportTextExportEnvironment:[generalExportFormatOptionsPanes textExportEnvironment]];
      [[PreferencesController sharedController] setExportTextExportBody:[generalExportFormatOptionsPanes textExportBody]];
    }//end if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsTextPanel])
  }//end if (ok)
  [NSApp endSheet:exportFormatOptionsPanel];
  [exportFormatOptionsPanel orderOut:self];
}
//end exportFormatOptionsPanel:didCloseWithOK:

#pragma mark edition

-(IBAction) editionChangeFont:(id)sender
{
  [[self window] makeFirstResponder:nil]; //to remove first responder from the text views
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  [fontManager orderFrontFontPanel:self];
  [fontManager setDelegate:self]; //the delegate will be reset in tabView:willSelectTabViewItem: or windowWillClose:
}
//end editionChangeFont:

-(void) changeFont:(id)sender
{
  NSFont* oldFont = [[PreferencesController sharedController] editionFont];
  NSFont* newFont = (sender && (sender != self)) ? [sender convertFont:oldFont] : oldFont;
  [[PreferencesController sharedController] setEditionFont:newFont];

  NSMutableAttributedString* example = [editionSyntaxColouringTextView textStorage];
  [example addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [example length])];

  //if sender is nil or self, this "changeFont:" only updates fontTextField, but should not modify textViews
  if (sender && (sender != self))
  {
    NSMutableAttributedString* preamble = [preamblesValueTextView textStorage];
    [preamble addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [preamble length])];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preamblesValueTextView];

    NSMutableAttributedString* bodyTemplateHead = [bodyTemplatesHeadTextView textStorage];
    [bodyTemplateHead addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [bodyTemplateHead length])];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:bodyTemplatesHeadTextView];

    NSMutableAttributedString* bodyTemplateTail = [bodyTemplatesTailTextView textStorage];
    [bodyTemplateTail addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [bodyTemplateTail length])];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:bodyTemplatesTailTextView];

    NSMutableAttributedString* example = [editionSyntaxColouringTextView textStorage];
    [example addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [example length])];
    
    NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
    [documents makeObjectsPerformSelector:@selector(setFont:) withObject:newFont];
  }
}
//end changeFont:

#pragma mark preambles

-(IBAction) preamblesValueResetDefault:(id)sender
{
    NSBeginAlertSheet(NSLocalizedString(@"Reset preamble",@"Reset preamble"),
                      NSLocalizedString(@"Reset preamble",@"Reset preamble"),
                      NSLocalizedString(@"Cancel", @"Cancel"),
                      nil, [self window], self,
                      @selector(_preamblesValueResetDefault:returnCode:contextInfo:), nil, NULL,
                      NSLocalizedString(@"Are you sure you want to reset the preamble ?\nThis operation is irreversible.",
                                        @"Are you sure you want to reset the preamble ?\nThis operation is irreversible."));
}
//end preamblesValueResetDefault:

-(void) _preamblesValueResetDefault:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
  if (returnCode == NSAlertFirstButtonReturn)
  {
    [preamblesValueTextView setValue:[PreamblesController defaultLocalizedPreambleValueAttributedString] forKey:NSAttributedStringBinding];
    [[[PreferencesController sharedController] preamblesController]
      setValue:[NSKeyedArchiver archivedDataWithRootObject:[PreamblesController defaultLocalizedPreambleValueAttributedString]]
      forKeyPath:@"selection.value"];
  }//end if (returnCode == NSAlertFirstButtonReturn)
}
//end _clearHistorySheetDidEnd:returnCode:contextInfo:

-(IBAction) preamblesValueApplyToOpenedDocuments:(id)sender
{
  [[self window] makeFirstResponder:nil];
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
  [documents makeObjectsPerformSelector:@selector(setPreamble:) withObject:[preferencesController preambleDocumentAttributedString]];
  [documents makeObjectsPerformSelector:@selector(setFont:) withObject:[preferencesController editionFont]];
}
//end preamblesValueApplyToOpenedDocuments:

-(IBAction) preamblesValueApplyToLibrary:(id)sender
{
  [[self window] makeFirstResponder:nil];
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
  NSInteger choice = [applyPreambleToLibraryAlert runModal];
  if (choice == NSAlertFirstButtonReturn)
  {
    NSArray* libraryEquations = [[LibraryManager sharedManager] libraryEquations];
    NSEnumerator* enumerator = [libraryEquations objectEnumerator];
    LibraryEquation* libraryEquation = nil;
    while((libraryEquation = [enumerator nextObject]))
    {
      NSAttributedString* preamble = [[PreferencesController sharedController] preambleDocumentAttributedString];
      [[libraryEquation equation] setPreamble:preamble];
    }//end for each libraryEquation
  }//end if (choice == NSAlertFirstButtonReturn)
}
//end preamblesValueApplyToLibrary:

#pragma mark bodyTemplates

-(IBAction) bodyTemplatesApplyToOpenedDocuments:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* bodyTemplatesDictionary = [preferencesController bodyTemplateDocumentDictionary];
  NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
  NSEnumerator* enumerator = [documents objectEnumerator];
  MyDocument* document = nil;
  while((document = [enumerator nextObject]))
    [document setBodyTemplate:bodyTemplatesDictionary moveCursor:YES];
}
//end bodyTemplatesApplyToOpenedDocuments:

#pragma mark composition configurations

-(IBAction) compositionConfigurationsProgramArgumentsOpen:(id)sender
{
  CompositionConfigurationsProgramArgumentsController* controller = nil;
  if (sender == compositionConfigurationsCurrentPdfLaTeXAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsPdfLaTeXController];
  else if (sender == compositionConfigurationsCurrentXeLaTeXAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsXeLaTeXController];
  else if (sender == compositionConfigurationsCurrentLaTeXAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsLaTeXController];
  else if (sender == compositionConfigurationsCurrentDviPdfAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsDviPdfController];
  else if (sender == compositionConfigurationsCurrentGsAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsGsController];
  else if (sender == compositionConfigurationsCurrentPsToPdfAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsPsToPdfController];
  if (controller)
  {
    [compositionConfigurationsProgramArgumentsAddButton bind:NSEnabledBinding toObject:controller withKeyPath:@"canAdd" options:nil];
    [compositionConfigurationsProgramArgumentsRemoveButton bind:NSEnabledBinding toObject:controller withKeyPath:@"canRemove" options:nil];
    [compositionConfigurationsProgramArgumentsTableView setController:controller];
    [NSApp beginSheet:compositionConfigurationsProgramArgumentsPanel modalForWindow:[self window] modalDelegate:self
      didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
  }
}
//end compositionConfigurationsProgramArgumentsOpen:

-(IBAction) compositionConfigurationsProgramArgumentsClose:(id)sender
{
  [compositionConfigurationsProgramArgumentsPanel makeFirstResponder:nil];//commit editing
  [NSApp endSheet:compositionConfigurationsProgramArgumentsPanel returnCode:NSOKButton];
  [self updateProgramArgumentsToolTips];
}
//end compositionConfigurationsProgramArgumentsClose:

-(void) updateProgramArgumentsToolTips
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  CompositionConfigurationsController* compositionConfigurationsController =
    [preferencesController compositionConfigurationsController];
  NSString* arguments = nil;
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationPdfLatexPathKey] componentsJoinedByString:@" "];
  [compositionConfigurationsCurrentPdfLaTeXPathTextField  setToolTip:arguments];
  [compositionConfigurationsCurrentPdfLaTeXAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationXeLatexPathKey] componentsJoinedByString:@" "];
  [compositionConfigurationsCurrentXeLaTeXPathTextField  setToolTip:arguments];
  [compositionConfigurationsCurrentXeLaTeXAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationLatexPathKey] componentsJoinedByString:@" "];
  [compositionConfigurationsCurrentLaTeXPathTextField  setToolTip:arguments];
  [compositionConfigurationsCurrentLaTeXAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationDviPdfPathKey] componentsJoinedByString:@" "];
  [compositionConfigurationsCurrentDviPdfPathTextField  setToolTip:arguments];
  [compositionConfigurationsCurrentDviPdfAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationGsPathKey] componentsJoinedByString:@" "];
  [compositionConfigurationsCurrentGsPathTextField  setToolTip:arguments];
  [compositionConfigurationsCurrentGsAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationPsToPdfPathKey] componentsJoinedByString:@" "];
  [compositionConfigurationsCurrentPsToPdfPathTextField  setToolTip:arguments];
  [compositionConfigurationsCurrentPsToPdfAdvancedButton setToolTip:arguments];
}
//end updateProgramArgumentsToolTips:

-(IBAction) compositionConfigurationsManagerOpen:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSArray* compositionConfigurations = [preferencesController compositionConfigurations];
  NSInteger selectedIndex = [compositionConfigurationsCurrentPopUpButton indexOfSelectedItem];
  if ((sender != compositionConfigurationsCurrentPopUpButton) || !IsBetween_N(1, selectedIndex+1, [compositionConfigurations count]))
    [NSApp beginSheet:compositionConfigurationsManagerPanel modalForWindow:[self window] modalDelegate:self
      didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
  else
    [preferencesController setCompositionConfigurationsDocumentIndex:selectedIndex];
}
//end compositionConfigurationsManagerOpen:

-(IBAction) compositionConfigurationsManagerClose:(id)sender
{
  [compositionConfigurationsManagerPanel makeFirstResponder:nil];//commit editing
  [NSApp endSheet:compositionConfigurationsManagerPanel returnCode:NSOKButton];
  [self observeValueForKeyPath:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]
    ofObject:[NSUserDefaultsController sharedUserDefaultsController] change:nil context:nil];
}
//end compositionConfigurationsManagerClose:

-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (sheet == compositionConfigurationsManagerPanel)
    [sheet orderOut:self];
  else if (sheet == compositionConfigurationsProgramArgumentsPanel)
    [sheet orderOut:self];
}
//end sheetDidEnd:returnCode:contextInfo:

-(IBAction) changePath:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setResolvesAliases:NO];
  NSDictionary* contextInfo = nil;
  if (sender == compositionConfigurationsCurrentPdfLaTeXPathChangeButton)
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
      compositionConfigurationsCurrentPdfLaTeXPathTextField, @"textField",
      CompositionConfigurationPdfLatexPathKey, @"pathKey",
      nil];
  else if (sender == compositionConfigurationsCurrentXeLaTeXPathChangeButton)
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
      compositionConfigurationsCurrentXeLaTeXPathTextField, @"textField",
      CompositionConfigurationXeLatexPathKey, @"pathKey",
      nil];
  else if (sender == compositionConfigurationsCurrentLaTeXPathChangeButton)
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
      compositionConfigurationsCurrentLaTeXPathTextField, @"textField",
      CompositionConfigurationLatexPathKey, @"pathKey",
      nil];
  else if (sender == compositionConfigurationsCurrentDviPdfPathChangeButton)
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
      compositionConfigurationsCurrentDviPdfPathTextField, @"textField",
      CompositionConfigurationDviPdfPathKey, @"pathKey",
      nil];
  else if (sender == compositionConfigurationsCurrentGsPathChangeButton)
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
      compositionConfigurationsCurrentGsPathTextField, @"textField",
      CompositionConfigurationGsPathKey, @"pathKey",
      nil];
  else if (sender == compositionConfigurationsCurrentPsToPdfPathChangeButton)
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
      compositionConfigurationsCurrentPsToPdfPathTextField, @"textField",
      CompositionConfigurationPsToPdfPathKey, @"pathKey",
      nil];
  else if (sender == compositionConfigurationsAdditionalScriptsExistingPathChangeButton)
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
      compositionConfigurationsAdditionalScriptsExistingPathTextField, @"textField",
      nil];
  else if (sender == synchronizationNewDocumentsPathChangeButton)
  {
    [openPanel setDirectory:[[PreferencesController sharedController] synchronizationNewDocumentsPath]];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                   synchronizationNewDocumentsPathTextField, @"textField",
                   nil];
  }
  else if (sender == synchronizationAdditionalScriptsExistingPathChangeButton)
    contextInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                   synchronizationAdditionalScriptsExistingPathTextField, @"textField",
                   nil];
  NSString* filename = [[contextInfo objectForKey:@"textField"] stringValue];
  NSString* path = filename ? filename : @"";
  path = [[NSFileManager defaultManager] fileExistsAtPath:path] ? [path stringByDeletingLastPathComponent] : nil;
  [openPanel beginSheetForDirectory:path file:[filename lastPathComponent] types:nil modalForWindow:[self window] modalDelegate:self
                           didEndSelector:@selector(didEndOpenPanel:returnCode:contextInfo:) contextInfo:[contextInfo copy]];
}
//end changePath:

-(void) didEndOpenPanel:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if ((returnCode == NSOKButton) && contextInfo)
  {
    NSTextField* textField = [(NSDictionary*)contextInfo objectForKey:@"textField"];
    NSString*    pathKey   = [(NSDictionary*)contextInfo objectForKey:@"pathKey"];
    NSArray* urls = [openPanel URLs];
    if (urls && [urls count])
    {
      NSString* path = [[urls objectAtIndex:0] path];
      if (textField == compositionConfigurationsAdditionalScriptsExistingPathTextField)
        [[[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationScriptsController]
          setValue:path
          forKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]];
      else if (textField == synchronizationNewDocumentsPathTextField)
        [[PreferencesController sharedController] setSynchronizationNewDocumentsPath:path];
      else if (textField == synchronizationAdditionalScriptsExistingPathTextField)
        [[[PreferencesController sharedController] synchronizationAdditionalScriptsController]
          setValue:path
          forKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]];
      else if (path && pathKey)
        [[PreferencesController sharedController] setCompositionConfigurationDocumentProgramPath:path forKey:pathKey];
      else
        [textField setStringValue:path];
    }//end if (filenames && [filenames count])
  }//end if ((returnCode == NSOKButton) && contextInfo)
  [(NSDictionary*)contextInfo release];
}
//end didEndOpenPanel:returnCode:contextInfo:

-(IBAction) compositionConfigurationsAdditionalScriptsOpenHelp:(id)sender
{
  if (!compositionConfigurationsAdditionalScriptsHelpPanel)
  {
    compositionConfigurationsAdditionalScriptsHelpPanel =
      [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 600, 600)
                                 styleMask:NSTitledWindowMask | NSClosableWindowMask |
                                           NSMiniaturizableWindowMask | NSResizableWindowMask |
                                           NSTexturedBackgroundWindowMask
                                   backing:NSBackingStoreBuffered defer:NO];
    [compositionConfigurationsAdditionalScriptsHelpPanel setTitle:NSLocalizedString(@"Help on scripts", @"Help on scripts")];
    [compositionConfigurationsAdditionalScriptsHelpPanel center];
    NSScrollView* scrollView =
      [[[NSScrollView alloc] initWithFrame:[[compositionConfigurationsAdditionalScriptsHelpPanel contentView] frame]] autorelease];
    [[compositionConfigurationsAdditionalScriptsHelpPanel contentView] addSubview:scrollView];
    [scrollView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    NSTextView* textView =
      [[[NSTextView alloc] initWithFrame:[[compositionConfigurationsAdditionalScriptsHelpPanel contentView] frame]] autorelease];
    [textView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [textView setEditable:NO];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setDocumentView:textView];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    NSString* rtfdFilePath = [[NSBundle mainBundle] pathForResource:@"additional-files-help" ofType:@"rtfd"];
    NSURL* rtfdUrl = !rtfdFilePath ? nil : [NSURL fileURLWithPath:rtfdFilePath];
    NSAttributedString* attributedString = !rtfdUrl ? nil :
      [[[NSAttributedString alloc] initWithURL:rtfdUrl documentAttributes:0] autorelease];
    if (attributedString)
      [[textView textStorage] setAttributedString:attributedString];
    [textView setSelectedRange:NSMakeRange(0, 0)];
  }//end if (!compositionConfigurationsAdditionalScriptsHelpPanel)
  [compositionConfigurationsAdditionalScriptsHelpPanel makeKeyAndOrderFront:sender];
}
//end compositionConfigurationsAdditionalScriptsOpenHelp:

-(IBAction) compositionConfigurationsCurrentReset:(id)sender
{
  NSAlert* alert = 
    [NSAlert alertWithMessageText:NSLocalizedString(@"Do you really want to reset the paths ?", @"Do you really want to reset the paths ?")
      defaultButton:NSLocalizedString(@"OK", @"OK")
      alternateButton:NSLocalizedString(@"Cancel", @"Cancel")
      otherButton:nil
        informativeTextWithFormat:NSLocalizedString(@"Invalid paths will be replaced by the result of auto-detection", @"Invalid paths will be replaced by the result of auto-detection")];
  [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(compositionConfigurationsCurrentResetDidEnd:returnCode:contextInfo:) contextInfo:0];
}
//end compositionConfigurationsCurrentReset:

-(void) compositionConfigurationsCurrentResetDidEnd:(NSAlert*)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
  if (returnCode == NSAlertFirstButtonReturn)
  {
    PreferencesController* preferencesController = [PreferencesController sharedController];
    [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationPdfLatexPathKey];
    [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationXeLatexPathKey];
    [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationLatexPathKey];
    [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationDviPdfPathKey];
    [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationGsPathKey];
    [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationPsToPdfPathKey];

    AppController* appController = [AppController appController];
    NSMutableDictionary* configuration =
      [NSMutableDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithBool:NO], @"checkOnlyIfNecessary",
         [NSNumber numberWithBool:NO], @"allowUIAlertOnFailure",
         [NSNumber numberWithBool:NO], @"allowUIFindOnFailure",
         nil];
    BOOL isPdfLaTeXAvailable = NO;
    BOOL isXeLaTeXAvailable = NO;
    BOOL isLaTeXAvailable = NO;
    BOOL isDviPdfAvailable = NO;
    BOOL isGsAvailable = NO;
    BOOL isPsToPdfAvailable = NO;
    BOOL isPdfToSvgAvailable = NO;
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                       [NSArray arrayWithObjects:@"pdflatex", nil], @"executableNames",
                                       [NSValue valueWithPointer:&isPdfLaTeXAvailable], @"monitor", nil]];
    if (!isPdfLaTeXAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                  [NSArray arrayWithObjects:@"pdflatex", nil], @"executableNames",
                                                  [NSValue valueWithPointer:&isPdfLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                       [NSArray arrayWithObjects:@"xelatex", nil], @"executableNames",
                                       [NSValue valueWithPointer:&isXeLaTeXAvailable], @"monitor", nil]];
    if (!isXeLaTeXAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                                  [NSArray arrayWithObjects:@"xelatex", nil], @"executableNames",
                                                  [NSValue valueWithPointer:&isXeLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                       [NSArray arrayWithObjects:@"latex", nil], @"executableNames",
                                       [NSValue valueWithPointer:&isLaTeXAvailable], @"monitor", nil]];
    if (!isLaTeXAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                  [NSArray arrayWithObjects:@"latex", nil], @"executableNames",
                                                  [NSValue valueWithPointer:&isLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                       [NSArray arrayWithObjects:@"dvipdf", nil], @"executableNames",
                                       [NSValue valueWithPointer:&isDviPdfAvailable], @"monitor", nil]];
    if (!isDviPdfAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                  [NSArray arrayWithObjects:@"dvipdf", nil], @"executableNames",
                                                  [NSValue valueWithPointer:&isDviPdfAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                       [NSArray arrayWithObjects:@"gs-noX11", @"gs", nil], @"executableNames",
                                       @"ghostscript", @"executableDisplayName",
                                       [NSValue valueWithPointer:&isGsAvailable], @"monitor", nil]];
    if (!isGsAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                  [NSArray arrayWithObjects:@"gs-noX11", @"gs", nil], @"executableNames",
                                                  @"ghostscript", @"executableDisplayName",
                                                  [NSValue valueWithPointer:&isGsAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                       [NSArray arrayWithObjects:@"ps2pdf", nil], @"executableNames",
                                       [NSValue valueWithPointer:&isPsToPdfAvailable], @"monitor", nil]];
    if (!isPsToPdfAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                  [NSArray arrayWithObjects:@"ps2pdf", nil], @"executableNames",
                                                  [NSValue valueWithPointer:&isPsToPdfAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:DragExportSvgPdfToSvgPathKey, @"path",
                                       [NSArray arrayWithObjects:@"pdf2svg", nil], @"executableNames",
                                       [NSValue valueWithPointer:&isPdfToSvgAvailable], @"monitor", nil]];
    if (!isPdfToSvgAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:DragExportSvgPdfToSvgPathKey, @"path",
                                                  [NSArray arrayWithObjects:@"pdf2svg", nil], @"executableNames",
                                                  [NSValue valueWithPointer:&isPdfToSvgAvailable], @"monitor", nil]];
    
    [configuration setObject:[NSNumber numberWithBool:YES] forKey:@"allowUIAlertOnFailure"];
    [configuration setObject:[NSNumber numberWithBool:YES] forKey:@"allowUIFindOnFailure"];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                [NSArray arrayWithObjects:@"pdflatex", nil], @"executableNames",
                                                [NSValue valueWithPointer:&isPdfLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                                [NSArray arrayWithObjects:@"xelatex", nil], @"executableNames",
                                                [NSValue valueWithPointer:&isXeLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                [NSArray arrayWithObjects:@"latex", nil], @"executableNames",
                                                [NSValue valueWithPointer:&isLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                [NSArray arrayWithObjects:@"dvipdf", nil], @"executableNames",
                                                [NSValue valueWithPointer:&isDviPdfAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                [NSArray arrayWithObjects:@"gs-noX11", @"gs", nil], @"executableNames",
                                                @"ghostscript", @"executableDisplayName",
                                                [NSValue valueWithPointer:&isGsAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                [NSArray arrayWithObjects:@"ps2pdf", nil], @"executableNames",
                                                [NSValue valueWithPointer:&isPsToPdfAvailable], @"monitor", nil]];
  }//end if (returnCode == NSAlertFirstButtonReturn)
}
//end compositionConfigurationsCurrentReset:

#pragma mark service

-(IBAction) serviceRegularExpressionsHelpOpen:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://userguide.icu-project.org/strings/regexp"]];
}
//end serviceRegularExpressionsHelpOpen:

-(void) textDidChange:(NSNotification*)notification
{
  if ([notification object] == serviceRegularExpressionsTestInputTextView)
  {
    ServiceRegularExpressionFiltersController* serviceRegularExpressionFiltersController =
      [[PreferencesController sharedController] serviceRegularExpressionFiltersController];
    NSAttributedString* input = [[[serviceRegularExpressionsTestInputTextView textStorage] copy] autorelease];
    NSAttributedString* output = [serviceRegularExpressionFiltersController applyFilterToAttributedString:input];
    if (!output)
      output = [[[NSAttributedString alloc] initWithString:@""] autorelease];
    [[serviceRegularExpressionsTestOutputTextView textStorage] setAttributedString:output];
  }//end if ([notification sender] == serviceRegularExpressionsTestInputTextField)
}
//end textDidChange:

#pragma mark additional files

-(IBAction) additionalFilesHelpOpen:(id)sender
{
  [[AppController appController] showHelp:self section:[NSString stringWithFormat:@"\"%@\"\n\n", NSLocalizedString(@"Additional files", @"Additional files")]];
}
//end additionalFilesHelpOpen:

#pragma mark synchronization additional scripts

-(IBAction) synchronizationAdditionalScriptsOpenHelp:(id)sender
{
  if (!synchronizationAdditionalScriptsHelpPanel)
  {
    synchronizationAdditionalScriptsHelpPanel =
    [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 600, 200)
                               styleMask:NSTitledWindowMask | NSClosableWindowMask |
     NSMiniaturizableWindowMask | NSResizableWindowMask |
     NSTexturedBackgroundWindowMask
                                 backing:NSBackingStoreBuffered defer:NO];
    [synchronizationAdditionalScriptsHelpPanel setTitle:NSLocalizedString(@"Help on synchronization scripts", @"Help on synchronization scripts")];
    [synchronizationAdditionalScriptsHelpPanel center];
    NSScrollView* scrollView =
    [[[NSScrollView alloc] initWithFrame:[[synchronizationAdditionalScriptsHelpPanel contentView] frame]] autorelease];
    [[synchronizationAdditionalScriptsHelpPanel contentView] addSubview:scrollView];
    [scrollView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    NSTextView* textView =
    [[[NSTextView alloc] initWithFrame:[[synchronizationAdditionalScriptsHelpPanel contentView] frame]] autorelease];
    [textView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [textView setEditable:NO];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setDocumentView:textView];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    NSString* rtfdFilePath = [[NSBundle mainBundle] pathForResource:@"synchronization-scripts-help" ofType:@"rtfd"];
    NSURL* rtfdUrl = !rtfdFilePath ? nil : [NSURL fileURLWithPath:rtfdFilePath];
    NSAttributedString* attributedString = !rtfdUrl ? nil :
    [[[NSAttributedString alloc] initWithURL:rtfdUrl documentAttributes:0] autorelease];
    if (attributedString)
      [[textView textStorage] setAttributedString:attributedString];
    [textView setSelectedRange:NSMakeRange(0, 0)];
  }//end if (!synchronizationAdditionalScriptsHelpPanel)
  [synchronizationAdditionalScriptsHelpPanel makeKeyAndOrderFront:sender];
}
//end synchronizationAdditionalScriptsOpenHelp:

#pragma mark updates

-(IBAction) updatesCheckNow:(id)sender
{
  [[AppController appController] checkUpdates:self];
}
//end updatesCheckNow:

-(IBAction) updatesGotoWebSite:(id)sender
{
  [[AppController appController] openWebSite:self];
}
//end updatesGotoWebSite:

#pragma mark NSTableViewDelegate

-(void) tableView:(NSTableView*)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
  if (tableView == pluginsPluginTableView)
  {
    Plugin* plugin = [[[PluginsManager sharedManager] plugins] objectAtIndex:(unsigned)rowIndex];
    NSImage* image = [plugin icon];
    if (!image)
      image = [NSImage imageNamed:@"pluginsToolbarItem"];
    ImageAndTextCell* imageAndTextCell = [cell dynamicCastToClass:[ImageAndTextCell class]];
    [imageAndTextCell setImage:image];
  }//end if (tableView == pluginsPluginTableView)
}
//end tableView:willDisplayCell:forTableColumn:row:

-(void) tableViewSelectionDidChange:(NSNotification*)notification
{
  if ([notification object] == pluginsPluginTableView)
  {
    NSInteger selectedRow = [pluginsPluginTableView selectedRow];
    if (selectedRow < 0)
    {
      [pluginCurrentlySelected dropConfigurationPanel];
      [pluginCurrentlySelected release];
      pluginCurrentlySelected = nil;
    }//end if (selectedRow < 0)
    else//if (selectedRow >= 0)
    {
      Plugin* plugin = [[[PluginsManager sharedManager] plugins] objectAtIndex:(unsigned)selectedRow];
      [plugin importConfigurationPanelIntoView:[pluginsConfigurationBox contentView]];
      [pluginCurrentlySelected release];
      pluginCurrentlySelected = [plugin retain];
    }//end if (selectedRow >= 0)
  }//end if (tableView == pluginsPluginTableView)
}
//end tableViewSelectionDidChange:

@end
