//  PreferencesWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

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
#import "CompositionConfigurationsAdditionalScriptsController.h"

#import "RegexKitLite.h"
#import <Sparkle/Sparkle.h>

#ifndef NSAppKitVersionNumber10_4
#define NSAppKitVersionNumber10_4 824
#endif

NSString* const GeneralToolbarItemIdentifier     = @"GeneralToolbarItemIdentifier";
NSString* const EditionToolbarItemIdentifier     = @"EditionToolbarItemIdentifier";
NSString* const TemplatesToolbarItemIdentifier   = @"TemplatesToolbarItemIdentifier";
NSString* const CompositionToolbarItemIdentifier = @"CompositionToolbarItemIdentifier";
NSString* const LibraryToolbarItemIdentifier     = @"LibraryToolbarItemIdentifier";
NSString* const HistoryToolbarItemIdentifier     = @"HistoryToolbarItemIdentifier";
NSString* const ServiceToolbarItemIdentifier     = @"ServiceToolbarItemIdentifier";
NSString* const AdvancedToolbarItemIdentifier    = @"AdvancedToolbarItemIdentifier";
NSString* const WebToolbarItemIdentifier         = @"WebToolbarItemIdentifier";
NSString* const PluginsToolbarItemIdentifier     = @"PluginsToolbarItemIdentifier";

@interface PreferencesWindowController () <ExportFormatOptionsDelegate>
-(IBAction) nilAction:(id)sender;
-(IBAction) changePath:(id)sender;
-(void) afterAwakeFromNib:(id)object;
-(void) updateProgramArgumentsToolTips;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;
-(void) tableViewSelectionDidChange:(NSNotification*)notification;
-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;
-(void) didEndOpenPanel:(NSOpenPanel*)openPanel returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;
-(void) _preamblesValueResetDefault:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
-(void) textDidChange:(NSNotification*)notification;
@end

@implementation PreferencesWindowController

-(instancetype) init
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
    [compositionConfigurationsCurrentPopUpButton.menu addItem:[NSMenuItem separatorItem]];
    [compositionConfigurationsCurrentPopUpButton addItemWithTitle:NSLocalizedString(@"Edit the configurations...", @"Edit the configurations...")];
  }
  else if (object == [[PreferencesController sharedController] serviceRegularExpressionFiltersController])
    [self textDidChange:
      [NSNotification notificationWithName:NSTextDidChangeNotification object:serviceRegularExpressionsTestInputTextView]];
  else if ((object == [NSUserDefaultsController sharedUserDefaultsController]) &&
           [keyPath isEqualToString:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]])
  {
    [compositionConfigurationsCurrentPopUpButton selectItemAtIndex:[PreferencesController sharedController].compositionConfigurationsDocumentIndex];
    [self updateProgramArgumentsToolTips];
  }
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) awakeFromNib
{
  //get rid of formatter localization problems
  generalPointSizeFormatter.locale = [NSLocale currentLocale];
  generalPointSizeFormatter.groupingSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
  generalPointSizeFormatter.decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
  NSString* generalPointSizeZeroSymbol =
   [NSString stringWithFormat:@"0%@%0*d%@",
     generalPointSizeFormatter.decimalSeparator, 2, 0, 
     generalPointSizeFormatter.positiveSuffix];
  generalPointSizeFormatter.zeroSymbol = generalPointSizeZeroSymbol;
  
  marginsAdditionalPointSizeFormatter.locale = [NSLocale currentLocale];
  marginsAdditionalPointSizeFormatter.groupingSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
  marginsAdditionalPointSizeFormatter.decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
  NSString* marginsAdditionalPointSizeZeroSymbol =
  [NSString stringWithFormat:@"0%@%0*d%@",
   marginsAdditionalPointSizeFormatter.decimalSeparator, 2, 0, 
   marginsAdditionalPointSizeFormatter.positiveSuffix];
  marginsAdditionalPointSizeFormatter.zeroSymbol = marginsAdditionalPointSizeZeroSymbol;
  
  servicePointSizeFactorFormatter.locale = [NSLocale currentLocale];
  servicePointSizeFactorFormatter.groupingSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
  servicePointSizeFactorFormatter.decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
  NSString* servicePointSizeZeroSymbol =
  [NSString stringWithFormat:@"0%@%0*d%@",
   servicePointSizeFactorFormatter.decimalSeparator, 2, 0, 
   servicePointSizeFactorFormatter.positiveSuffix];
  servicePointSizeFactorFormatter.zeroSymbol = servicePointSizeZeroSymbol;
  
  viewsMinSizes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
    [NSValue valueWithSize:generalView.frame.size], GeneralToolbarItemIdentifier,
    [NSValue valueWithSize:editionView.frame.size], EditionToolbarItemIdentifier,
    [NSValue valueWithSize:templatesView.frame.size], TemplatesToolbarItemIdentifier,
    [NSValue valueWithSize:compositionView.frame.size], CompositionToolbarItemIdentifier,
    [NSValue valueWithSize:libraryView.frame.size], LibraryToolbarItemIdentifier,
    [NSValue valueWithSize:historyView.frame.size], HistoryToolbarItemIdentifier,
    [NSValue valueWithSize:serviceView.frame.size], ServiceToolbarItemIdentifier,
    [NSValue valueWithSize:pluginsView.frame.size], PluginsToolbarItemIdentifier,
    [NSValue valueWithSize:advancedView.frame.size], AdvancedToolbarItemIdentifier,
    [NSValue valueWithSize:webView.frame.size], WebToolbarItemIdentifier,
    nil];
  
  NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"preferencesToolbar"];
  toolbar.delegate = (id)self;
  NSWindow* window = self.window;
  window.delegate = (id)self;
  window.toolbar = toolbar;
  [window setShowsToolbarButton:NO];
  toolbar.selectedItemIdentifier = GeneralToolbarItemIdentifier;
  [self toolbarHit:toolbarItems[toolbar.selectedItemIdentifier]];
  
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
  generalExportFormatPopupButton.target = self;
  generalExportFormatPopupButton.action = @selector(nilAction:);
  [generalExportFormatPopupButton bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey] options:nil];
  [generalExportScaleLabel bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:@(EXPORT_FORMAT_MATHML)]}];
  [generalExportScalePercentTextField bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:@(EXPORT_FORMAT_MATHML)]}];
  [generalExportFormatOptionsButton bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:@{NSValueTransformerBindingOption: [IsInTransformer transformerWithReferences:
        @[@(EXPORT_FORMAT_JPEG),
                                  @(EXPORT_FORMAT_SVG),
                                  @(EXPORT_FORMAT_TEXT),
                                  @(EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)]]}];
  generalExportFormatOptionsButton.target = self;
  generalExportFormatOptionsButton.action = @selector(generalExportFormatOptionsOpen:);
  [generalExportFormatJpegWarning setTitle:
    NSLocalizedString(@"Warning : jpeg does not manage transparency", @"Warning : jpeg does not manage transparency")];
  [generalExportFormatJpegWarning sizeToFit];
  [generalExportFormatJpegWarning centerInSuperviewHorizontally:YES vertically:NO];
  [generalExportFormatJpegWarning bind:NSHiddenBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:@(EXPORT_FORMAT_JPEG)]}];
  [generalExportFormatSvgWarning setTitle:
    NSLocalizedString(@"Warning : pdf2svg was not found", @"Warning : pdf2svg was not found")];
  [generalExportFormatSvgWarning sizeToFit];
  [generalExportFormatSvgWarning centerInSuperviewHorizontally:YES vertically:NO];
  generalExportFormatSvgWarning.textColor = [NSColor redColor];
  [generalExportFormatSvgWarning bind:NSHiddenBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:@(EXPORT_FORMAT_SVG)]}];
  NSString* NSHidden2Binding = [NSHiddenBinding stringByAppendingString:@"2"];
  [generalExportFormatSvgWarning bind:NSHidden2Binding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportSvgPdfToSvgPathKey]
    options:@{NSValueTransformerBindingOption: [FileExistsTransformer transformerWithDirectoryAllowed:NO]}];

  [generalExportFormatMathMLWarning setTitle:
    NSLocalizedString(@"Warning : the XML::LibXML perl module was not found", @"Warning : the XML::LibXML perl module was not found")];
  [generalExportFormatMathMLWarning sizeToFit];
  [generalExportFormatMathMLWarning centerInSuperviewHorizontally:YES vertically:NO];
  generalExportFormatMathMLWarning.textColor = [NSColor redColor];
  [generalExportFormatMathMLWarning bind:NSHiddenBinding toObject:userDefaultsController
                                withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
                                    options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:@(EXPORT_FORMAT_MATHML)]}];
  [generalExportFormatMathMLWarning bind:NSHidden2Binding toObject:[AppController appController]
                                   withKeyPath:@"isPerlWithLibXMLAvailable"
                                       options:nil];
  
  [generalExportScalePercentTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportScaleAsPercentKey] options:nil];
  
  [generalDummyBackgroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultImageViewBackgroundKey]
        options:@{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [generalDummyBackgroundAutoStateButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultAutomaticHighContrastedPreviewBackgroundKey] options:nil];
  [generalDoNotClipPreviewButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultDoNotClipPreviewKey] options:nil];

  generalLatexisationLaTeXModeSegmentedControl.segmentCount = 5;
  NSUInteger segmentIndex = 0;
  NSSegmentedCell* latexModeSegmentedCell = generalLatexisationLaTeXModeSegmentedControl.cell;
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
    options:@{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];

  //margins
  marginsAdditionalTopTextField.formatter = marginsAdditionalPointSizeFormatter;
  marginsAdditionalLeftTextField.formatter = marginsAdditionalPointSizeFormatter;
  marginsAdditionalRightTextField.formatter = marginsAdditionalPointSizeFormatter;
  marginsAdditionalBottomTextField.formatter = marginsAdditionalPointSizeFormatter;
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
    options:@{NSValueTransformerBindingOption: [ComposedTransformer
        transformerWithValueTransformer:[NSValueTransformer valueTransformerForName:[KeyedUnarchiveFromDataTransformer name]]
        additionalValueTransformer:nil
        additionalKeyPath:@"displayNameWithPointSize"]}];
  [editionSyntaxColoringStateButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringEnableKey]
    options:nil];
  [editionSyntaxColoringTextForegroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringTextForegroundColorKey]
    options:@{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [editionSyntaxColoringTextBackgroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringTextBackgroundColorKey]
    options:@{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [editionSyntaxColoringCommandColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringCommandColorKey]
    options:@{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [editionSyntaxColoringKeywordColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringKeywordColorKey]
    options:@{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [editionSyntaxColoringMathsColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringMathsColorKey]
    options:@{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [editionSyntaxColoringCommentColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringCommentColorKey]
    options:@{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
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
  editionTextShortcutsAddButton.target = editionTextShortcutsController;
  editionTextShortcutsAddButton.action = @selector(add:);
  [editionTextShortcutsRemoveButton bind:NSEnabledBinding toObject:editionTextShortcutsController withKeyPath:@"canRemove" options:nil];
  editionTextShortcutsRemoveButton.target = editionTextShortcutsController;
  editionTextShortcutsRemoveButton.action = @selector(remove:);
  
  [self performSelector:@selector(afterAwakeFromNib:) withObject:nil afterDelay:0];
  [editionSyntaxColouringTextView
    bind:NSFontBinding toObject:userDefaultsController withKeyPath:[userDefaultsController adaptedKeyPath:DefaultFontKey]
    options:@{NSValueTransformerNameBindingOption: NSUnarchiveFromDataTransformerName}];

  //Preambles
  PreamblesController* preamblesController = [preferencesController preamblesController];
  preamblesAddButton.target = preamblesController;
  preamblesAddButton.action = @selector(add:);
  [preamblesAddButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"canAdd" options:nil];
  preamblesRemoveButton.target = preamblesController;
  preamblesRemoveButton.action = @selector(remove:);
  [preamblesRemoveButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"canRemove" options:nil];
  [preamblesValueTextView bind:NSAttributedStringBinding toObject:preamblesController withKeyPath:@"selection.value" options:
    @{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [preamblesValueTextView bind:NSEditableBinding toObject:preamblesController withKeyPath:@"selection" options:
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName}];
  [preamblesController addObserver:self forKeyPath:@"selection.value" options:0 context:nil];//to recolour the preamblesValueTextView...
  [self observeValueForKeyPath:@"selection.value" ofObject:preamblesController change:nil context:nil];
  
  preamblesValueResetDefaultButton.target = self;
  preamblesValueResetDefaultButton.action = @selector(preamblesValueResetDefault:);
  [preamblesValueResetDefaultButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName}];

  preamblesValueApplyToOpenedDocumentsButton.target = self;
  preamblesValueApplyToOpenedDocumentsButton.action = @selector(preamblesValueApplyToOpenedDocuments:);
  [preamblesValueApplyToOpenedDocumentsButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName}];

  preamblesValueApplyToLibraryButton.target = self;
  preamblesValueApplyToLibraryButton.action = @selector(preamblesValueApplyToLibrary:);
  [preamblesValueApplyToLibraryButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName}];
  
  [preamblesNamesLatexisationPopUpButton bind:NSContentValuesBinding toObject:preamblesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [preamblesNamesLatexisationPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:LatexisationSelectedPreambleIndexKey] options:nil];

  //BodyTemplates
  BodyTemplatesController* bodyTemplatesController = [preferencesController bodyTemplatesController];
  bodyTemplatesAddButton.target = bodyTemplatesController;
  bodyTemplatesAddButton.action = @selector(add:);
  [bodyTemplatesAddButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"canAdd" options:nil];
  bodyTemplatesRemoveButton.target = bodyTemplatesController;
  bodyTemplatesRemoveButton.action = @selector(remove:);
  [bodyTemplatesRemoveButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"canRemove" options:nil];
  [bodyTemplatesHeadTextView bind:NSAttributedStringBinding toObject:bodyTemplatesController withKeyPath:@"selection.head" options:
    @{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [bodyTemplatesHeadTextView bind:NSEditableBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName}];
  [bodyTemplatesTailTextView bind:NSAttributedStringBinding toObject:bodyTemplatesController withKeyPath:@"selection.tail" options:
    @{NSValueTransformerNameBindingOption: [KeyedUnarchiveFromDataTransformer name]}];
  [bodyTemplatesTailTextView bind:NSEditableBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName}];
  [bodyTemplatesController addObserver:self forKeyPath:@"selection.head" options:0 context:nil];//to recolour the bodyTemplatesHeadTextView
  [bodyTemplatesController addObserver:self forKeyPath:@"selection.tail" options:0 context:nil];//to recolour the bodyTemplatesTailTextView
  [self observeValueForKeyPath:@"selection.head" ofObject:bodyTemplatesController change:nil context:nil];
  [self observeValueForKeyPath:@"selection.tail" ofObject:bodyTemplatesController change:nil context:nil];
  
  bodyTemplatesApplyToOpenedDocumentsButton.target = self;
  bodyTemplatesApplyToOpenedDocumentsButton.action = @selector(bodyTemplatesApplyToOpenedDocuments:);
  [bodyTemplatesApplyToOpenedDocumentsButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName}];

  [bodyTemplatesNamesLatexisationPopUpButton bind:NSContentValuesBinding toObject:bodyTemplatesController
    withKeyPath:@"arrangedObjectsNamesWithNone" options:nil];
  [bodyTemplatesNamesLatexisationPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:LatexisationSelectedBodyTemplateIndexKey] options:
      @{NSValueTransformerBindingOption: [NSNumberIntegerShiftTransformer transformerWithShift:@1]}];

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
  compositionConfigurationsCurrentPopUpButton.target = self;
  compositionConfigurationsCurrentPopUpButton.action = @selector(compositionConfigurationsManagerOpen:);

  compositionConfigurationsProgramArgumentsAddButton.target = compositionConfigurationsProgramArgumentsTableView;
  compositionConfigurationsProgramArgumentsAddButton.action = @selector(add:);
  compositionConfigurationsProgramArgumentsRemoveButton.target = compositionConfigurationsProgramArgumentsTableView;
  compositionConfigurationsProgramArgumentsRemoveButton.action = @selector(remove:);
  compositionConfigurationsProgramArgumentsOkButton.target = self;
  compositionConfigurationsProgramArgumentsOkButton.action = @selector(compositionConfigurationsProgramArgumentsClose:);

  [compositionConfigurationsManagerAddButton bind:NSEnabledBinding toObject:compositionConfigurationsController withKeyPath:@"canAdd" options:nil];
  compositionConfigurationsManagerAddButton.target = compositionConfigurationsController;
  compositionConfigurationsManagerAddButton.action = @selector(add:);
  [compositionConfigurationsManagerRemoveButton bind:NSEnabledBinding toObject:compositionConfigurationsController withKeyPath:@"canRemove" options:nil];
  compositionConfigurationsManagerRemoveButton.target = compositionConfigurationsController;
  compositionConfigurationsManagerRemoveButton.action = @selector(remove:);
  compositionConfigurationsManagerOkButton.target = self;
  compositionConfigurationsManagerOkButton.action = @selector(compositionConfigurationsManagerClose:);

  NSDictionary* isNotNilBindingOptions =
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName};
  NSString* NSEnabled2Binding = [NSEnabledBinding stringByAppendingString:@"2"];

  [compositionConfigurationsCurrentEnginePopUpButton bind:NSSelectedTagBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey] options:nil];
  [compositionConfigurationsCurrentLoginShellUsedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentLoginShellUsedButton bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationUseLoginShellKey] options:nil];
  [compositionConfigurationsCurrentResetButton setTitle:NSLocalizedString(@"Reset...", @"Reset...")];
  [compositionConfigurationsCurrentResetButton sizeToFit];
  compositionConfigurationsCurrentResetButton.target = self;
  compositionConfigurationsCurrentResetButton.action = @selector(compositionConfigurationsCurrentReset:);
  
  NSDictionary* colorForFileExistsBindingOptions =
    @{NSValueTransformerBindingOption: [ComposedTransformer
        transformerWithValueTransformer:[FileExistsTransformer transformerWithDirectoryAllowed:NO]
             additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor controlTextColor]]
             additionalKeyPath:nil]};
  NSDictionary* colorForFolderExistsBindingOptions =
    @{NSValueTransformerBindingOption: [ComposedTransformer
        transformerWithValueTransformer:[FolderExistsTransformer transformer]
             additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor controlTextColor]]
             additionalKeyPath:nil]};

  [compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey]
        options:nil];
  [compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentPdfLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  compositionConfigurationsCurrentPdfLaTeXAdvancedButton.target = self;
  compositionConfigurationsCurrentPdfLaTeXAdvancedButton.action = @selector(compositionConfigurationsProgramArgumentsOpen:);

  [compositionConfigurationsCurrentPdfLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  compositionConfigurationsCurrentPdfLaTeXPathChangeButton.target = self;
  compositionConfigurationsCurrentPdfLaTeXPathChangeButton.action = @selector(changePath:);

  [compositionConfigurationsCurrentXeLaTeXPathTextField.cell setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey] options:nil];
  [compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_XELATEX)]}];
  [compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentXeLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentXeLaTeXAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_XELATEX)]}];
  compositionConfigurationsCurrentXeLaTeXAdvancedButton.target = self;
  compositionConfigurationsCurrentXeLaTeXAdvancedButton.action = @selector(compositionConfigurationsProgramArgumentsOpen:);

  [compositionConfigurationsCurrentXeLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentXeLaTeXPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_XELATEX)]}];
  compositionConfigurationsCurrentXeLaTeXPathChangeButton.target = self;
  compositionConfigurationsCurrentXeLaTeXPathChangeButton.action = @selector(changePath:);

  [self->compositionConfigurationsCurrentLuaLaTeXPathTextField.cell setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [self->compositionConfigurationsCurrentLuaLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
                                                       withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLuaLatexPathKey] options:nil];
  [self->compositionConfigurationsCurrentLuaLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
                                                       withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentLuaLaTeXPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
                                                       withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
                                                           options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LUALATEX)]}];
  [self->compositionConfigurationsCurrentLuaLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
                                                       withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLuaLatexPathKey] options:colorForFileExistsBindingOptions];
  
  [self->compositionConfigurationsCurrentLuaLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
                                                        withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentLuaLaTeXAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
                                                        withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
                                                            options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LUALATEX)]}];
  self->compositionConfigurationsCurrentLuaLaTeXAdvancedButton.target = self;
  self->compositionConfigurationsCurrentLuaLaTeXAdvancedButton.action = @selector(compositionConfigurationsProgramArgumentsOpen:);
  
  [self->compositionConfigurationsCurrentLuaLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
                                                          withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentLuaLaTeXPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
                                                          withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
                                                              options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LUALATEX)]}];
  self->compositionConfigurationsCurrentLuaLaTeXPathChangeButton.target = self;
  self->compositionConfigurationsCurrentLuaLaTeXPathChangeButton.action = @selector(changePath:);

  [compositionConfigurationsCurrentLaTeXPathTextField.cell setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLatexPathKey] options:nil];
  [compositionConfigurationsCurrentLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentLaTeXPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LATEXDVIPDF)]}];
  [compositionConfigurationsCurrentLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLatexPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentLaTeXAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LATEXDVIPDF)]}];
  compositionConfigurationsCurrentLaTeXAdvancedButton.target = self;
  compositionConfigurationsCurrentLaTeXAdvancedButton.action = @selector(compositionConfigurationsProgramArgumentsOpen:);

  [compositionConfigurationsCurrentLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentLaTeXPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LATEXDVIPDF)]}];
  compositionConfigurationsCurrentLaTeXPathChangeButton.target = self;
  compositionConfigurationsCurrentLaTeXPathChangeButton.action = @selector(changePath:);

  [compositionConfigurationsCurrentDviPdfPathTextField.cell setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentDviPdfPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationDviPdfPathKey] options:nil];
  [compositionConfigurationsCurrentDviPdfPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentDviPdfPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LATEXDVIPDF)]}];
  [compositionConfigurationsCurrentDviPdfPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationDviPdfPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentDviPdfAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentDviPdfAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LATEXDVIPDF)]}];
  compositionConfigurationsCurrentDviPdfAdvancedButton.target = self;
  compositionConfigurationsCurrentDviPdfAdvancedButton.action = @selector(compositionConfigurationsProgramArgumentsOpen:);

  [compositionConfigurationsCurrentDviPdfPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentDviPdfPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:@(COMPOSITION_MODE_LATEXDVIPDF)]}];
  compositionConfigurationsCurrentDviPdfPathChangeButton.target = self;
  compositionConfigurationsCurrentDviPdfPathChangeButton.action = @selector(changePath:);

  [compositionConfigurationsCurrentGsPathTextField.cell setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
  [compositionConfigurationsCurrentGsPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationGsPathKey] options:nil];
  [compositionConfigurationsCurrentGsPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [compositionConfigurationsCurrentGsPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationGsPathKey] options:colorForFileExistsBindingOptions];

  [compositionConfigurationsCurrentGsAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  compositionConfigurationsCurrentGsAdvancedButton.target = self;
  compositionConfigurationsCurrentGsAdvancedButton.action = @selector(compositionConfigurationsProgramArgumentsOpen:);

  [compositionConfigurationsCurrentGsPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  compositionConfigurationsCurrentGsPathChangeButton.target = self;
  compositionConfigurationsCurrentGsPathChangeButton.action = @selector(changePath:);

  [compositionConfigurationsCurrentPsToPdfPathTextField.cell setPlaceholderString:NSLocalizedString(@"path to the Unix executable program", @"path to the Unix executable program")];
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
  compositionConfigurationsCurrentPsToPdfAdvancedButton.target = self;
  compositionConfigurationsCurrentPsToPdfAdvancedButton.action = @selector(compositionConfigurationsProgramArgumentsOpen:);

  compositionConfigurationsCurrentPsToPdfPathChangeButton.target = self;
  compositionConfigurationsCurrentPsToPdfPathChangeButton.action = @selector(changePath:);
  
  [self updateProgramArgumentsToolTips];

  //history
  [historySaveServiceResultsCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceUsesHistoryKey]
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]]}];
  [historyDeleteOldEntriesCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]]}];
  [historyDeleteOldEntriesLimitTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesLimitKey]
    options:nil];
  [historyDeleteOldEntriesLimitTextField bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:nil];
  historyDeleteOldEntriesLimitStepper.formatter = historyDeleteOldEntriesLimitTextField.formatter;
  [historyDeleteOldEntriesLimitStepper bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesLimitKey]
    options:nil];
  [historyDeleteOldEntriesLimitStepper bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:nil];
  [historySmartCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistorySmartEnabledKey]
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]]}];

  // additional scripts
  [[compositionConfigurationsAdditionalScriptsTableView tableColumnWithIdentifier:@"place"] bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
 withKeyPath:@"arrangedObjects.key"
    options:@{NSValueTransformerBindingOption: [ObjectTransformer transformerWithDictionary:
        @{@(SCRIPT_PLACE_PREPROCESSING).stringValue: NSLocalizedString(@"Pre-processing", @"Pre-processing"), 
          @(SCRIPT_PLACE_MIDDLEPROCESSING).stringValue: NSLocalizedString(@"Middle-processing", @"Middle-processing"), 
          @(SCRIPT_PLACE_POSTPROCESSING).stringValue: NSLocalizedString(@"Post-processing", @"Post-processing")}]}];
  [[compositionConfigurationsAdditionalScriptsTableView tableColumnWithIdentifier:@"enabled"] bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[@"arrangedObjects.value." stringByAppendingString:CompositionConfigurationAdditionalProcessingScriptEnabledKey]
    options:nil];

  [compositionConfigurationsAdditionalScriptsTypePopUpButton removeAllItems];
  [compositionConfigurationsAdditionalScriptsTypePopUpButton.menu
    addItemWithTitle:NSLocalizedString(@"Define a script", @"Define a script") action:nil keyEquivalent:@""].tag = SCRIPT_SOURCE_STRING;
  [compositionConfigurationsAdditionalScriptsTypePopUpButton.menu
    addItemWithTitle:NSLocalizedString(@"Use existing script", @"Use existing script") action:nil keyEquivalent:@""].tag = SCRIPT_SOURCE_FILE;
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
    options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_STRING]]}];
  [compositionConfigurationsAdditionalScriptsExistingBox bind:NSHiddenBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
    options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_FILE]]}];

  [compositionConfigurationsAdditionalScriptsDefiningShellTextField bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
    options:nil];
  [compositionConfigurationsAdditionalScriptsDefiningShellTextField bind:NSTextColorBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
    options:colorForFileExistsBindingOptions];
  compositionConfigurationsAdditionalScriptsDefiningContentTextView.font = [NSFont fontWithName:@"Monaco" size:12.];
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
  compositionConfigurationsAdditionalScriptsExistingPathChangeButton.target = self;
  compositionConfigurationsAdditionalScriptsExistingPathChangeButton.action = @selector(changePath:);

  //service
  [servicePreamblePopUpButton bind:NSContentValuesBinding toObject:preamblesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [servicePreamblePopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceSelectedPreambleIndexKey] options:nil];
  [serviceBodyTemplatesPopUpButton bind:NSContentValuesBinding toObject:bodyTemplatesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [serviceBodyTemplatesPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceSelectedBodyTemplateIndexKey] options:nil];

  [serviceRespectsPointSizeMatrix cellAtRow:0 column:0].tag = 0;
  [serviceRespectsPointSizeMatrix cellAtRow:1 column:0].tag = 1;
  [serviceRespectsPointSizeMatrix bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsPointSizeKey]
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:@0 trueValue:@1]}];
  [servicePointSizeFactorTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServicePointSizeFactorKey] options:nil];
  [servicePointSizeFactorStepper bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServicePointSizeFactorKey] options:nil];
  servicePointSizeFactorTextField.formatter = servicePointSizeFactorFormatter;
  servicePointSizeFactorStepper.formatter = servicePointSizeFactorFormatter;

  [serviceRespectsColorMatrix cellAtRow:0 column:0].tag = 0;
  [serviceRespectsColorMatrix cellAtRow:1 column:0].tag = 1;
  [serviceRespectsColorMatrix bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsColorKey]
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:@0 trueValue:@1]}];

  [serviceRespectsBaselineButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsBaselineKey]
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]]}];
  [serviceWarningLinkBackButton bind:NSHiddenBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsBaselineKey]
    options:@{NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];

  [serviceUsesHistoryButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceUsesHistoryKey]
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]]}];
      
  [serviceRelaunchWarning setHidden:YES/*isMacOS10_5OrAbove()*/];
  
  //service regular expression filters
  NSArrayController* serviceRegularExpressionFiltersController = [preferencesController serviceRegularExpressionFiltersController];
  [serviceRegularExpressionFiltersController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
  [serviceRegularExpressionFiltersController addObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterEnabledKey] options:0 context:nil];
  [serviceRegularExpressionFiltersController addObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterInputPatternKey] options:0 context:nil];
  [serviceRegularExpressionFiltersController addObserver:self forKeyPath:[NSString stringWithFormat:@"arrangedObjects.%@", ServiceRegularExpressionFilterOutputPatternKey] options:0 context:nil];
  [serviceRegularExpressionsAddButton bind:NSEnabledBinding toObject:serviceRegularExpressionFiltersController withKeyPath:@"canAdd" options:nil];
  serviceRegularExpressionsAddButton.target = serviceRegularExpressionFiltersController;
  serviceRegularExpressionsAddButton.action = @selector(add:);

  [serviceRegularExpressionsRemoveButton bind:NSEnabledBinding toObject:serviceRegularExpressionFiltersController withKeyPath:@"canRemove" options:nil];
  serviceRegularExpressionsRemoveButton.target = serviceRegularExpressionFiltersController;
  serviceRegularExpressionsRemoveButton.action = @selector(remove:);

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextDidChangeNotification object:serviceRegularExpressionsTestInputTextView];
  serviceRegularExpressionsTestInputTextView.delegate = (id)self;
  serviceRegularExpressionsTestInputTextView.font = [NSFont controlContentFontOfSize:0];
  [serviceRegularExpressionsTestInputTextView setPlaceHolder:NSLocalizedString(@"Text to test", @"Text to test")];
  if ([serviceRegularExpressionsTestInputTextView respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)])
    [serviceRegularExpressionsTestInputTextView setAutomaticTextReplacementEnabled:NO];
  serviceRegularExpressionsTestOutputTextView.font = [NSFont controlContentFontOfSize:0];
  [serviceRegularExpressionsTestOutputTextView setPlaceHolder:NSLocalizedString(@"Result of text filtering", @"Result of text filtering")];
  if ([serviceRegularExpressionsTestOutputTextView respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)])
    [serviceRegularExpressionsTestOutputTextView setAutomaticTextReplacementEnabled:NO];

  serviceRegularExpressionsHelpButton.target = self;
  serviceRegularExpressionsHelpButton.action = @selector(serviceRegularExpressionsHelpOpen:);

  //additional files
  AdditionalFilesController* additionalFilesController = [preferencesController additionalFilesController];
  [additionalFilesAddButton bind:NSEnabledBinding toObject:additionalFilesController withKeyPath:@"canAdd" options:nil];
  additionalFilesAddButton.target = additionalFilesTableView;
  additionalFilesAddButton.action = @selector(addFiles:);
  [additionalFilesRemoveButton bind:NSEnabledBinding toObject:additionalFilesController withKeyPath:@"canRemove" options:nil];
  additionalFilesRemoveButton.target = additionalFilesController;
  additionalFilesRemoveButton.action = @selector(remove:);
  additionalFilesHelpButton.target = self;
  additionalFilesHelpButton.action = @selector(additionalFilesHelpOpen:);
  
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
                                               options:@{NSValueTransformerBindingOption: [FilePathLocalizedTransformer transformer]}];
                                                        
  [synchronizationNewDocumentsPathTextField bind:NSTextColorBinding
                                              toObject:userDefaultsController
                                           withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsPathKey]
                                               options:colorForFolderExistsBindingOptions];
  [synchronizationNewDocumentsPathChangeButton bind:NSEnabledBinding
                                              toObject:userDefaultsController
                                           withKeyPath:[userDefaultsController adaptedKeyPath:SynchronizationNewDocumentsEnabledKey]
                                               options:nil];
  synchronizationNewDocumentsPathChangeButton.target = self;
  synchronizationNewDocumentsPathChangeButton.action = @selector(changePath:);
  
  
  SynchronizationAdditionalScriptsController* synchronizationAdditionalScriptsController = [preferencesController synchronizationAdditionalScriptsController];
  [[synchronizationAdditionalScriptsTableView tableColumnWithIdentifier:@"place"] bind:NSValueBinding
                                                                                    toObject:synchronizationAdditionalScriptsController
                                                                                 withKeyPath:@"arrangedObjects.key"
                                                                                     options:@{NSValueTransformerBindingOption: [ObjectTransformer transformerWithDictionary:
                                                                                                 @{@(SYNCHRONIZATION_SCRIPT_PLACE_LOADING_PREPROCESSING).stringValue: NSLocalizedString(@"Pre-processing on load", @"Pre-processing on load"), 
                                                                                                   @(SYNCHRONIZATION_SCRIPT_PLACE_LOADING_POSTPROCESSING).stringValue: NSLocalizedString(@"Post-processing on load", @"Post-processing on load"), 
                                                                                                   @(SYNCHRONIZATION_SCRIPT_PLACE_SAVING_PREPROCESSING).stringValue: NSLocalizedString(@"Pre-processing on save", @"Pre-processing on save"), 
                                                                                                   @(SYNCHRONIZATION_SCRIPT_PLACE_SAVING_POSTPROCESSING).stringValue: NSLocalizedString(@"Post-processing on save", @"Post-processing on save")}]}];
  [[synchronizationAdditionalScriptsTableView tableColumnWithIdentifier:@"enabled"] bind:NSValueBinding
                                                                                      toObject:synchronizationAdditionalScriptsController
                                                                                   withKeyPath:[@"arrangedObjects.value." stringByAppendingString:CompositionConfigurationAdditionalProcessingScriptEnabledKey]
                                                                                       options:nil];
  
  [synchronizationAdditionalScriptsTypePopUpButton removeAllItems];
  [synchronizationAdditionalScriptsTypePopUpButton.menu
    addItemWithTitle:NSLocalizedString(@"Define a script", @"Define a script") action:nil keyEquivalent:@""].tag = SCRIPT_SOURCE_STRING;
  [synchronizationAdditionalScriptsTypePopUpButton.menu
    addItemWithTitle:NSLocalizedString(@"Use existing script", @"Use existing script") action:nil keyEquivalent:@""].tag = SCRIPT_SOURCE_FILE;
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
                                                  options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_STRING]]}];
  [synchronizationAdditionalScriptsDefiningBox bind:[NSHiddenBinding stringByAppendingString:@"2"]
                                                 toObject:synchronizationAdditionalScriptsController
                                              withKeyPath:@"selectionIndexes"
                                                  options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:[NSIndexSet indexSet]]}];
  [synchronizationAdditionalScriptsExistingBox bind:NSHiddenBinding
                                                 toObject:synchronizationAdditionalScriptsController
                                              withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
                                                  options:@{NSValueTransformerBindingOption: [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_FILE]]}];
  [synchronizationAdditionalScriptsExistingBox bind:[NSHiddenBinding stringByAppendingString:@"2"]
                                                 toObject:synchronizationAdditionalScriptsController
                                              withKeyPath:@"selectionIndexes"
                                                  options:@{NSValueTransformerBindingOption: [IsEqualToTransformer transformerWithReference:[NSIndexSet indexSet]]}];
  
  [synchronizationAdditionalScriptsDefiningShellTextField bind:NSValueBinding
                                                            toObject:synchronizationAdditionalScriptsController
                                                         withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
                                                             options:nil];

  [synchronizationAdditionalScriptsDefiningShellTextField bind:NSTextColorBinding
                                                            toObject:synchronizationAdditionalScriptsController
                                                         withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
                                                             options:colorForFileExistsBindingOptions];
  synchronizationAdditionalScriptsDefiningContentTextView.font = [NSFont fontWithName:@"Monaco" size:12.];
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
  synchronizationAdditionalScriptsExistingPathChangeButton.target = self;
  synchronizationAdditionalScriptsExistingPathChangeButton.action = @selector(changePath:);

  //encapsulations
  EncapsulationsController* encapsulationsController = [preferencesController encapsulationsController];
  [encapsulationsEnabledCheckBox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey]
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]]}];

  [encapsulationsLabel1 bind:NSTextColorBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey]
        options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSColor disabledControlTextColor] trueValue:[NSColor controlTextColor]]}];
  [encapsulationsLabel2 bind:NSTextColorBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey]
        options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSColor disabledControlTextColor] trueValue:[NSColor controlTextColor]]}];
  [encapsulationsLabel3 bind:NSTextColorBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey]
        options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSColor disabledControlTextColor] trueValue:[NSColor controlTextColor]]}];

  [encapsulationsTableView bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey] options:nil];

  [encapsulationsAddButton bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey] options:nil];
  [encapsulationsAddButton bind:NSEnabled2Binding toObject:encapsulationsController withKeyPath:@"canAdd" options:nil];
  encapsulationsAddButton.target = encapsulationsController;
  encapsulationsAddButton.action = @selector(add:);

  [encapsulationsRemoveButton bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:EncapsulationsEnabledKey] options:nil];
  [encapsulationsRemoveButton bind:NSEnabled2Binding toObject:encapsulationsController withKeyPath:@"canRemove" options:nil];
  encapsulationsRemoveButton.target = encapsulationsController;
  encapsulationsRemoveButton.action = @selector(remove:);

  //updates
  [updatesCheckUpdatesButton bind:NSValueBinding toObject:[[AppController appController] sparkleUpdater]
    withKeyPath:@"automaticallyChecksForUpdates"
    options:@{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]]}];
      
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
  editionSyntaxColouringTextView.font = preferencesController.editionFont;
}
//end afterAwakeFromNib:

//initializes the controls with default values
-(void) windowDidLoad
{
  NSPoint topLeftPoint  = self.window.frame.origin;
  topLeftPoint.y       += self.window.frame.size.height;
  //[[self window] setFrameAutosaveName:@"preferences"];
  [self.window setFrameTopLeftPoint:topLeftPoint];
}
//end windowDidLoad

-(void) windowWillClose:(NSNotification *)aNotification
{
  //useful for font selection
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if (fontManager.delegate == self)
    [fontManager setDelegate:nil];
  [self.window makeFirstResponder:nil];//commit editing
  [[NSUserDefaults standardUserDefaults] synchronize];
}
//end windowWillClose:

-(NSSize) windowWillResize:(NSWindow*)window toSize:(NSSize)proposedFrameSize
{
  NSSize result = proposedFrameSize;
  if (window == self.window)
  {
    if (!window.showsResizeIndicator)
    {
      result = window.frame.size;
      [window setFrameOrigin:window.frame.origin];
    }//end if (![window showsResizeIndicator])
  }//end if (window == [self window])
  return result;
}
//end windowWillResize:toSize:

-(NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
  return @[GeneralToolbarItemIdentifier,  EditionToolbarItemIdentifier,
                                   TemplatesToolbarItemIdentifier, CompositionToolbarItemIdentifier,
                                   LibraryToolbarItemIdentifier, HistoryToolbarItemIdentifier,
                                   ServiceToolbarItemIdentifier, //PluginsToolbarItemIdentifier,
                                   AdvancedToolbarItemIdentifier, WebToolbarItemIdentifier];
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
  NSToolbarItem* item = toolbarItems[itemIdentifier];
  if (!item)
  {
    item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    
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
    item.label = label;
    item.image = image;

    item.target = self;
    item.action = @selector(toolbarHit:);
    toolbarItems[itemIdentifier] = item;
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

  NSWindow* window = self.window;
  NSView*   contentView = window.contentView;
  if (view != contentView)
  {
    NSSize contentMinSize = [viewsMinSizes[itemIdentifier] sizeValue];
    NSRect oldContentFrame = contentView ? contentView.frame : NSZeroRect;
    NSRect newContentFrame = !view ? NSZeroRect : view.frame;
    NSRect newFrame = window.frame;
    newFrame.size.width  += (newContentFrame.size.width  - oldContentFrame.size.width);
    newFrame.size.height += (newContentFrame.size.height - oldContentFrame.size.height);
    newFrame.origin.y    -= (newContentFrame.size.height - oldContentFrame.size.height);
    //window.contentView;
    emptyView.frame = newContentFrame;
    window.contentView = emptyView;
    [window setFrame:newFrame display:YES animate:YES];
    //window.contentView;
    window.contentView = view;
    window.contentMinSize = contentMinSize;
  }//end if (view != contentView)
  
  window.showsResizeIndicator = [itemIdentifier isEqualToString:EditionToolbarItemIdentifier] ||
    [itemIdentifier isEqualToString:ServiceToolbarItemIdentifier];

  //useful for font selection
  [window makeFirstResponder:nil];
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if (fontManager.delegate == self)
    [fontManager setDelegate:nil];
    
  //update from SUUpdater
  updatesCheckUpdatesNowButton.enabled = ![[[AppController appController] sparkleUpdater] updateInProgress];
}
//end toolbarHit:

-(void) selectPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier options:(id)options
{
  if ([itemIdentifier isEqualToString:TemplatesToolbarItemIdentifier])
    [templatesTabView selectTabViewItemAtIndex:[options intValue]];
  self.window.toolbar.selectedItemIdentifier = itemIdentifier;
  [self toolbarHit:toolbarItems[itemIdentifier]];
}
//end selectPreferencesPaneWithItemIdentifier:

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok  = YES;
  if (sender.tag == EXPORT_FORMAT_EPS)
    ok = [AppController appController].gsAvailable;
  else if (sender.tag == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [AppController appController].gsAvailable && [AppController appController].psToPdfAvailable;
  /*else if ([sender tag] == EXPORT_FORMAT_SVG)
    ok = [[AppController appController] isPdfToSvgAvailable];*/
  return ok;
}
//end validateMenuItem:

-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [self.window makeFirstResponder:nil];//commit editing
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
    generalExportFormatOptionsPanes.exportFormatOptionsJpegPanelDelegate = self;
    generalExportFormatOptionsPanes.exportFormatOptionsSvgPanelDelegate = self;
    generalExportFormatOptionsPanes.exportFormatOptionsTextPanelDelegate = self;
    self->generalExportFormatOptionsPanes.exportFormatOptionsPDFWofPanelDelegate = self;
  }//end if (!generalExportFormatOptionsPanes)
  generalExportFormatOptionsPanes.jpegQualityPercent = [PreferencesController sharedController].exportJpegQualityPercent;
  generalExportFormatOptionsPanes.jpegBackgroundColor = [PreferencesController sharedController].exportJpegBackgroundColor;
  generalExportFormatOptionsPanes.svgPdfToSvgPath = [PreferencesController sharedController].exportSvgPdfToSvgPath;
  generalExportFormatOptionsPanes.textExportPreamble = [PreferencesController sharedController].exportTextExportPreamble;
  generalExportFormatOptionsPanes.textExportEnvironment = [PreferencesController sharedController].exportTextExportEnvironment;
  generalExportFormatOptionsPanes.textExportBody = [PreferencesController sharedController].exportTextExportBody;
  self->generalExportFormatOptionsPanes.pdfWofGSWriteEngine = [PreferencesController sharedController].exportPDFWOFGsWriteEngine;
  self->generalExportFormatOptionsPanes.pdfWofGSPDFCompatibilityLevel = [PreferencesController sharedController].exportPDFWOFGsPDFCompatibilityLevel;
  self->generalExportFormatOptionsPanes.pdfWofMetaDataInvisibleGraphicsEnabled = [PreferencesController sharedController].exportPDFWOFMetaDataInvisibleGraphicsEnabled;
 
  
  NSPanel* panelToOpen = nil;
  export_format_t format = (export_format_t)generalExportFormatPopupButton.selectedTag;
  if (format == EXPORT_FORMAT_JPEG)
    panelToOpen = generalExportFormatOptionsPanes.exportFormatOptionsJpegPanel;
  else if (format == EXPORT_FORMAT_SVG)
    panelToOpen = generalExportFormatOptionsPanes.exportFormatOptionsSvgPanel;
  else if (format == EXPORT_FORMAT_TEXT)
    panelToOpen = generalExportFormatOptionsPanes.exportFormatOptionsTextPanel;
  else if (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    panelToOpen = self->generalExportFormatOptionsPanes.exportFormatOptionsPDFWofPanel;
  if (panelToOpen) {
    [self.window beginSheet:panelToOpen completionHandler:^(NSModalResponse returnCode) {
      
    }];
  }
}
//end openOptionsForDragExport:

-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok
{
  if (ok)
  {
    PreferencesController* preferencesController = [PreferencesController sharedController];
    if (exportFormatOptionsPanel == generalExportFormatOptionsPanes.exportFormatOptionsJpegPanel)
    {
      preferencesController.exportJpegQualityPercent = generalExportFormatOptionsPanes.jpegQualityPercent;
      preferencesController.exportJpegBackgroundColor = generalExportFormatOptionsPanes.jpegBackgroundColor;
    }//end if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    else if (exportFormatOptionsPanel == generalExportFormatOptionsPanes.exportFormatOptionsSvgPanel)
    {
      preferencesController.exportSvgPdfToSvgPath = generalExportFormatOptionsPanes.svgPdfToSvgPath;
    }//end if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    else if (exportFormatOptionsPanel == generalExportFormatOptionsPanes.exportFormatOptionsTextPanel)
    {
      preferencesController.exportTextExportPreamble = generalExportFormatOptionsPanes.textExportPreamble;
      preferencesController.exportTextExportEnvironment = generalExportFormatOptionsPanes.textExportEnvironment;
      preferencesController.exportTextExportBody = generalExportFormatOptionsPanes.textExportBody;
    }//end if (exportFormatOptionsPanel == [generalExportFormatOptionsPanes exportFormatOptionsTextPanel])
    else if (exportFormatOptionsPanel == self->generalExportFormatOptionsPanes.exportFormatOptionsPDFWofPanel)
    {
      preferencesController.exportPDFWOFGsWriteEngine = self->generalExportFormatOptionsPanes.pdfWofGSWriteEngine;
      preferencesController.exportPDFWOFGsPDFCompatibilityLevel = self->generalExportFormatOptionsPanes.pdfWofGSPDFCompatibilityLevel;
      preferencesController.exportPDFWOFMetaDataInvisibleGraphicsEnabled = self->generalExportFormatOptionsPanes.pdfWofMetaDataInvisibleGraphicsEnabled;
    }//end if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsPDFWofPanel])
  }//end if (ok)
  [self.window endSheet:exportFormatOptionsPanel];
  [exportFormatOptionsPanel orderOut:self];
}
//end exportFormatOptionsPanel:didCloseWithOK:

#pragma mark edition

-(IBAction) editionChangeFont:(id)sender
{
  [self.window makeFirstResponder:nil]; //to remove first responder from the text views
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  [fontManager orderFrontFontPanel:self];
  fontManager.delegate = self; //the delegate will be reset in tabView:willSelectTabViewItem: or windowWillClose:
}
//end editionChangeFont:

-(void) changeFont:(id)sender
{
  NSFont* oldFont = [PreferencesController sharedController].editionFont;
  NSFont* newFont = (sender && (sender != self)) ? [sender convertFont:oldFont] : oldFont;
  [PreferencesController sharedController].editionFont = newFont;

  NSMutableAttributedString* example = editionSyntaxColouringTextView.textStorage;
  [example addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, example.length)];

  //if sender is nil or self, this "changeFont:" only updates fontTextField, but should not modify textViews
  if (sender && (sender != self))
  {
    NSMutableAttributedString* preamble = preamblesValueTextView.textStorage;
    [preamble addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, preamble.length)];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preamblesValueTextView];

    NSMutableAttributedString* bodyTemplateHead = bodyTemplatesHeadTextView.textStorage;
    [bodyTemplateHead addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, bodyTemplateHead.length)];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:bodyTemplatesHeadTextView];

    NSMutableAttributedString* bodyTemplateTail = bodyTemplatesTailTextView.textStorage;
    [bodyTemplateTail addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, bodyTemplateTail.length)];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:bodyTemplatesTailTextView];

    NSMutableAttributedString* example = editionSyntaxColouringTextView.textStorage;
    [example addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, example.length)];
    
    NSArray* documents = [NSDocumentController sharedDocumentController].documents;
    [documents makeObjectsPerformSelector:@selector(setFont:) withObject:newFont];
  }
}
//end changeFont:

#pragma mark preambles

-(IBAction) preamblesValueResetDefault:(id)sender
{
  NSAlert *alert = [NSAlert new];
  alert.messageText = NSLocalizedString(@"Reset preamble",@"Reset preamble");
  alert.informativeText = NSLocalizedString(@"Are you sure you want to reset the preamble ?\nThis operation is irreversible.",
                                            @"Are you sure you want to reset the preamble ?\nThis operation is irreversible.");
  [alert addButtonWithTitle:NSLocalizedString(@"Reset preamble",@"Reset preamble")];
  [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
  [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
    [self _preamblesValueResetDefault:nil returnCode:returnCode contextInfo:NULL];
  }];
  
}
//end preamblesValueResetDefault:

-(void) _preamblesValueResetDefault:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
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
  [self.window makeFirstResponder:nil];
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSArray* documents = [NSDocumentController sharedDocumentController].documents;
  [documents makeObjectsPerformSelector:@selector(setPreamble:) withObject:[preferencesController preambleDocumentAttributedString]];
  [documents makeObjectsPerformSelector:@selector(setFont:) withObject:preferencesController.editionFont];
}
//end preamblesValueApplyToOpenedDocuments:

-(IBAction) preamblesValueApplyToLibrary:(id)sender
{
  [self.window makeFirstResponder:nil];
  if (!applyPreambleToLibraryAlert)
  {
    applyPreambleToLibraryAlert = [[NSAlert alloc] init];
    [applyPreambleToLibraryAlert setMessageText:NSLocalizedString(@"Do you really want to apply that preamble to the library items ?",
                                                                        @"Do you really want to apply that preamble to the library items ?")];
    [applyPreambleToLibraryAlert setInformativeText:
      NSLocalizedString(@"Their old preamble will be overwritten. If it was a special preamble that had been tuned to generate them, it will be lost.",
                        @"Their old preamble will be overwritten. If it was a special preamble that had been tuned to generate them, it will be lost.")];
    applyPreambleToLibraryAlert.alertStyle = NSWarningAlertStyle;
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
      libraryEquation.equation.preamble = preamble;
    }//end for each libraryEquation
  }//end if (choice == NSAlertFirstButtonReturn)
}
//end preamblesValueApplyToLibrary:

#pragma mark bodyTemplates

-(IBAction) bodyTemplatesApplyToOpenedDocuments:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* bodyTemplatesDictionary = preferencesController.bodyTemplateDocumentDictionary;
  NSArray* documents = [NSDocumentController sharedDocumentController].documents;
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
  else if (sender == self->compositionConfigurationsCurrentLuaLaTeXAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsLuaLaTeXController];
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
    [self.window beginSheet:compositionConfigurationsProgramArgumentsPanel completionHandler:^(NSModalResponse returnCode) {
      [self sheetDidEnd:self->compositionConfigurationsProgramArgumentsPanel returnCode:returnCode contextInfo:NULL];
    }];
  }
}
//end compositionConfigurationsProgramArgumentsOpen:

-(IBAction) compositionConfigurationsProgramArgumentsClose:(id)sender
{
  [compositionConfigurationsProgramArgumentsPanel makeFirstResponder:nil];//commit editing
  [self.window endSheet:compositionConfigurationsProgramArgumentsPanel returnCode:NSModalResponseOK];
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
  compositionConfigurationsCurrentPdfLaTeXPathTextField.toolTip = arguments;
  compositionConfigurationsCurrentPdfLaTeXAdvancedButton.toolTip = arguments;
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationXeLatexPathKey] componentsJoinedByString:@" "];
  compositionConfigurationsCurrentXeLaTeXPathTextField.toolTip = arguments;
  compositionConfigurationsCurrentXeLaTeXAdvancedButton.toolTip = arguments;
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationLuaLatexPathKey] componentsJoinedByString:@" "];
  self->compositionConfigurationsCurrentLuaLaTeXPathTextField.toolTip = arguments;
  self->compositionConfigurationsCurrentLuaLaTeXAdvancedButton.toolTip = arguments;
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationLatexPathKey] componentsJoinedByString:@" "];
  compositionConfigurationsCurrentLaTeXPathTextField.toolTip = arguments;
  compositionConfigurationsCurrentLaTeXAdvancedButton.toolTip = arguments;
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationDviPdfPathKey] componentsJoinedByString:@" "];
  compositionConfigurationsCurrentDviPdfPathTextField.toolTip = arguments;
  compositionConfigurationsCurrentDviPdfAdvancedButton.toolTip = arguments;
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationGsPathKey] componentsJoinedByString:@" "];
  compositionConfigurationsCurrentGsPathTextField.toolTip = arguments;
  compositionConfigurationsCurrentGsAdvancedButton.toolTip = arguments;
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationPsToPdfPathKey] componentsJoinedByString:@" "];
  compositionConfigurationsCurrentPsToPdfPathTextField.toolTip = arguments;
  compositionConfigurationsCurrentPsToPdfAdvancedButton.toolTip = arguments;
}
//end updateProgramArgumentsToolTips:

-(IBAction) compositionConfigurationsManagerOpen:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSArray* compositionConfigurations = preferencesController.compositionConfigurations;
  NSInteger selectedIndex = compositionConfigurationsCurrentPopUpButton.indexOfSelectedItem;
  if ((sender != compositionConfigurationsCurrentPopUpButton) || !IsBetween_N(1, selectedIndex+1, [compositionConfigurations count])) {
    [self.window beginSheet:compositionConfigurationsManagerPanel completionHandler:^(NSModalResponse returnCode) {
      [self sheetDidEnd:self->compositionConfigurationsManagerPanel returnCode:returnCode contextInfo:NULL];
    }];
  } else {
    preferencesController.compositionConfigurationsDocumentIndex = selectedIndex;
  }
}
//end compositionConfigurationsManagerOpen:

-(IBAction) compositionConfigurationsManagerClose:(id)sender
{
  [compositionConfigurationsManagerPanel makeFirstResponder:nil];//commit editing
  [self.window endSheet:compositionConfigurationsManagerPanel returnCode:NSModalResponseOK];
  [self observeValueForKeyPath:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]
    ofObject:[NSUserDefaultsController sharedUserDefaultsController] change:nil context:nil];
}
//end compositionConfigurationsManagerClose:

-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
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
    contextInfo = @{@"textField": compositionConfigurationsCurrentPdfLaTeXPathTextField,
      @"pathKey": CompositionConfigurationPdfLatexPathKey};
  else if (sender == compositionConfigurationsCurrentXeLaTeXPathChangeButton)
    contextInfo = @{@"textField": compositionConfigurationsCurrentXeLaTeXPathTextField,
      @"pathKey": CompositionConfigurationXeLatexPathKey};
  else if (sender == self->compositionConfigurationsCurrentLuaLaTeXPathChangeButton)
    contextInfo = @{@"textField": self->compositionConfigurationsCurrentLuaLaTeXPathTextField,
                   @"pathKey": CompositionConfigurationLuaLatexPathKey};
  else if (sender == compositionConfigurationsCurrentLaTeXPathChangeButton)
    contextInfo = @{@"textField": compositionConfigurationsCurrentLaTeXPathTextField,
      @"pathKey": CompositionConfigurationLatexPathKey};
  else if (sender == compositionConfigurationsCurrentDviPdfPathChangeButton)
    contextInfo = @{@"textField": compositionConfigurationsCurrentDviPdfPathTextField,
      @"pathKey": CompositionConfigurationDviPdfPathKey};
  else if (sender == compositionConfigurationsCurrentGsPathChangeButton)
    contextInfo = @{@"textField": compositionConfigurationsCurrentGsPathTextField,
      @"pathKey": CompositionConfigurationGsPathKey};
  else if (sender == compositionConfigurationsCurrentPsToPdfPathChangeButton)
    contextInfo = @{@"textField": compositionConfigurationsCurrentPsToPdfPathTextField,
      @"pathKey": CompositionConfigurationPsToPdfPathKey};
  else if (sender == compositionConfigurationsAdditionalScriptsExistingPathChangeButton)
    contextInfo = @{@"textField": compositionConfigurationsAdditionalScriptsExistingPathTextField};
  else if (sender == synchronizationNewDocumentsPathChangeButton)
  {
    openPanel.directoryURL = [NSURL fileURLWithPath:[PreferencesController sharedController].synchronizationNewDocumentsPath];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    contextInfo = @{@"textField": synchronizationNewDocumentsPathTextField};
  }
  else if (sender == synchronizationAdditionalScriptsExistingPathChangeButton)
    contextInfo = @{@"textField": synchronizationAdditionalScriptsExistingPathTextField};
  NSString* filename = [contextInfo[@"textField"] stringValue];
  NSString* path = filename ? filename : @"";
  path = [[NSFileManager defaultManager] fileExistsAtPath:path] ? path.stringByDeletingLastPathComponent : nil;
  openPanel.directoryURL = [NSURL fileURLWithPath:path];
  openPanel.nameFieldStringValue = filename.lastPathComponent;
  [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
    [self didEndOpenPanel:openPanel returnCode:result contextInfo:(void*)CFBridgingRetain([contextInfo copy])];
  }];
}
//end changePath:

-(void) didEndOpenPanel:(NSOpenPanel*)openPanel returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
  if ((returnCode == NSModalResponseOK) && contextInfo)
  {
    NSTextField* textField = ((__bridge NSDictionary*)contextInfo)[@"textField"];
    NSString*    pathKey   = ((__bridge NSDictionary*)contextInfo)[@"pathKey"];
    NSArray* urls = openPanel.URLs;
    if (urls && urls.count)
    {
      NSString* path = [urls[0] path];
      if (textField == compositionConfigurationsAdditionalScriptsExistingPathTextField)
        [[[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationScriptsController]
          setValue:path
          forKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]];
      else if (textField == synchronizationNewDocumentsPathTextField)
        [PreferencesController sharedController].synchronizationNewDocumentsPath = path;
      else if (textField == synchronizationAdditionalScriptsExistingPathTextField)
        [[[PreferencesController sharedController] synchronizationAdditionalScriptsController]
          setValue:path
          forKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]];
      else if (path && pathKey)
        [[PreferencesController sharedController] setCompositionConfigurationDocumentProgramPath:path forKey:pathKey];
      else
        textField.stringValue = path;
    }//end if (filenames && [filenames count])
  }//end if ((returnCode == NSOKButton) && contextInfo)
  CFBridgingRelease(contextInfo);
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
      [[NSScrollView alloc] initWithFrame:compositionConfigurationsAdditionalScriptsHelpPanel.contentView.frame];
    [compositionConfigurationsAdditionalScriptsHelpPanel.contentView addSubview:scrollView];
    scrollView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    NSTextView* textView =
      [[NSTextView alloc] initWithFrame:compositionConfigurationsAdditionalScriptsHelpPanel.contentView.frame];
    textView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    [textView setEditable:NO];
    scrollView.borderType = NSNoBorder;
    scrollView.documentView = textView;
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    NSString* rtfdFilePath = [[NSBundle mainBundle] pathForResource:@"additional-files-help" ofType:@"rtfd"];
    NSURL* rtfdUrl = !rtfdFilePath ? nil : [NSURL fileURLWithPath:rtfdFilePath];
    NSAttributedString* attributedString = !rtfdUrl ? nil :
    [[NSAttributedString alloc] initWithURL:rtfdUrl options:@{} documentAttributes:0 error:NULL];
    if (attributedString)
      [textView.textStorage setAttributedString:attributedString];
    [textView setSelectedRange:NSMakeRange(0, 0)];
  }//end if (!compositionConfigurationsAdditionalScriptsHelpPanel)
  [compositionConfigurationsAdditionalScriptsHelpPanel makeKeyAndOrderFront:sender];
}
//end compositionConfigurationsAdditionalScriptsOpenHelp:

-(IBAction) compositionConfigurationsCurrentReset:(id)sender
{
  NSAlert* alert = [NSAlert new];
  alert.messageText = NSLocalizedString(@"Do you really want to reset the paths ?", @"Do you really want to reset the paths ?");
  alert.informativeText = NSLocalizedString(@"Invalid paths will be replaced by the result of auto-detection", @"Invalid paths will be replaced by the result of auto-detection");
  [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
  [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
  [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
    if (returnCode == NSAlertFirstButtonReturn)
    {
      PreferencesController* preferencesController = [PreferencesController sharedController];
      [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationPdfLatexPathKey];
      [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationXeLatexPathKey];
      [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationLuaLatexPathKey];
      [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationLatexPathKey];
      [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationDviPdfPathKey];
      [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationGsPathKey];
      [preferencesController setCompositionConfigurationDocumentProgramPath:@"" forKey:CompositionConfigurationPsToPdfPathKey];
      
      AppController* appController = [AppController appController];
      NSMutableDictionary* configuration =
      [NSMutableDictionary dictionaryWithObjectsAndKeys:
       @NO, @"checkOnlyIfNecessary",
       @NO, @"allowUIAlertOnFailure",
       @NO, @"allowUIFindOnFailure",
       nil];
      BOOL isPdfLaTeXAvailable = NO;
      BOOL isXeLaTeXAvailable = NO;
      BOOL isLuaLaTeXAvailable = NO;
      BOOL isLaTeXAvailable = NO;
      BOOL isDviPdfAvailable = NO;
      BOOL isGsAvailable = NO;
      BOOL isPsToPdfAvailable = NO;
      BOOL isPdfToSvgAvailable = NO;
      [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                  @[@"pdflatex"], @"executableNames",
                                                  [NSValue valueWithPointer:&isPdfLaTeXAvailable], @"monitor", nil]];
      if (!isPdfLaTeXAvailable)
        [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                   @[@"pdflatex"], @"executableNames",
                                                   [NSValue valueWithPointer:&isPdfLaTeXAvailable], @"monitor", nil]];
      [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                                  @[@"xelatex"], @"executableNames",
                                                  [NSValue valueWithPointer:&isXeLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLuaLatexPathKey, @"path",
                                                @[@"lualatex"], @"executableNames",
                                                [NSValue valueWithPointer:&isLuaLaTeXAvailable], @"monitor", nil]];
    if (!isLuaLaTeXAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLuaLatexPathKey, @"path",
                                                 @[@"lualatex"], @"executableNames",
                                                 [NSValue valueWithPointer:&isLuaLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                       @[@"latex"], @"executableNames",
                                       [NSValue valueWithPointer:&isLaTeXAvailable], @"monitor", nil]];
    if (!isLaTeXAvailable)
      [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                  @[@"latex"], @"executableNames",
                                                  [NSValue valueWithPointer:&isLaTeXAvailable], @"monitor", nil]];
      if (!isLaTeXAvailable)
        [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                   @[@"latex"], @"executableNames",
                                                   [NSValue valueWithPointer:&isLaTeXAvailable], @"monitor", nil]];
      [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                  @[@"dvipdf"], @"executableNames",
                                                  [NSValue valueWithPointer:&isDviPdfAvailable], @"monitor", nil]];
      if (!isDviPdfAvailable)
        [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                   @[@"dvipdf"], @"executableNames",
                                                   [NSValue valueWithPointer:&isDviPdfAvailable], @"monitor", nil]];
      [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                  @[@"gs-noX11", @"gs"], @"executableNames",
                                                  @"ghostscript", @"executableDisplayName",
                                                  [NSValue valueWithPointer:&isGsAvailable], @"monitor", nil]];
      if (!isGsAvailable)
        [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                   @[@"gs-noX11", @"gs"], @"executableNames",
                                                   @"ghostscript", @"executableDisplayName",
                                                   [NSValue valueWithPointer:&isGsAvailable], @"monitor", nil]];
      [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                  @[@"ps2pdf"], @"executableNames",
                                                  [NSValue valueWithPointer:&isPsToPdfAvailable], @"monitor", nil]];
      if (!isPsToPdfAvailable)
        [appController _findPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                   @[@"ps2pdf"], @"executableNames",
                                                   [NSValue valueWithPointer:&isPsToPdfAvailable], @"monitor", nil]];
      [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:DragExportSvgPdfToSvgPathKey, @"path",
                                                  @[@"pdf2svg"], @"executableNames",
                                                  [NSValue valueWithPointer:&isPdfToSvgAvailable], @"monitor", nil]];
    
    configuration[@"allowUIAlertOnFailure"] = @YES;
    configuration[@"allowUIFindOnFailure"] = @YES;
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                @[@"pdflatex"], @"executableNames",
                                                [NSValue valueWithPointer:&isPdfLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                                @[@"xelatex"], @"executableNames",
                                                [NSValue valueWithPointer:&isXeLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLuaLatexPathKey, @"path",
                                                @[@"lualatex"], @"executableNames",
                                                [NSValue valueWithPointer:&isLuaLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                @[@"latex"], @"executableNames",
                                                [NSValue valueWithPointer:&isLaTeXAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                @[@"dvipdf"], @"executableNames",
                                                [NSValue valueWithPointer:&isDviPdfAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                @[@"gs-noX11", @"gs"], @"executableNames",
                                                @"ghostscript", @"executableDisplayName",
                                                [NSValue valueWithPointer:&isGsAvailable], @"monitor", nil]];
    [appController _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                @[@"ps2pdf"], @"executableNames",
                                                [NSValue valueWithPointer:&isPsToPdfAvailable], @"monitor", nil]];
  }//end if (returnCode == NSAlertDefaultReturn)
  }];
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
  if (notification.object == serviceRegularExpressionsTestInputTextView)
  {
    ServiceRegularExpressionFiltersController* serviceRegularExpressionFiltersController =
      [[PreferencesController sharedController] serviceRegularExpressionFiltersController];
    NSAttributedString* input = [serviceRegularExpressionsTestInputTextView.textStorage copy];
    NSAttributedString* output = [serviceRegularExpressionFiltersController applyFilterToAttributedString:input];
    if (!output)
      output = [[NSAttributedString alloc] initWithString:@""];
    [serviceRegularExpressionsTestOutputTextView.textStorage setAttributedString:output];
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
    [[NSScrollView alloc] initWithFrame:synchronizationAdditionalScriptsHelpPanel.contentView.frame];
    [synchronizationAdditionalScriptsHelpPanel.contentView addSubview:scrollView];
    scrollView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    NSTextView* textView =
    [[NSTextView alloc] initWithFrame:synchronizationAdditionalScriptsHelpPanel.contentView.frame];
    textView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    [textView setEditable:NO];
    scrollView.borderType = NSNoBorder;
    scrollView.documentView = textView;
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    NSString* rtfdFilePath = [[NSBundle mainBundle] pathForResource:@"synchronization-scripts-help" ofType:@"rtfd"];
    NSURL* rtfdUrl = !rtfdFilePath ? nil : [NSURL fileURLWithPath:rtfdFilePath];
    NSAttributedString* attributedString = !rtfdUrl ? nil :
    [[NSAttributedString alloc] initWithURL:rtfdUrl options:@{} documentAttributes:nil error:NULL];
    if (attributedString)
      [textView.textStorage setAttributedString:attributedString];
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
    Plugin* plugin = [PluginsManager sharedManager].plugins[(unsigned)rowIndex];
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
  if (notification.object == pluginsPluginTableView)
  {
    NSInteger selectedRow = pluginsPluginTableView.selectedRow;
    if (selectedRow < 0)
    {
      [pluginCurrentlySelected dropConfigurationPanel];
      pluginCurrentlySelected = nil;
    }//end if (selectedRow < 0)
    else//if (selectedRow >= 0)
    {
      Plugin* plugin = [PluginsManager sharedManager].plugins[(unsigned)selectedRow];
      [plugin importConfigurationPanelIntoView:pluginsConfigurationBox.contentView];
      pluginCurrentlySelected = plugin;
    }//end if (selectedRow >= 0)
  }//end if (tableView == pluginsPluginTableView)
}
//end tableViewSelectionDidChange:

@end
