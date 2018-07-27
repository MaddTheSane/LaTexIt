//  PreferencesWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.

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
#import "IsEqualToTransformer.h"
#import "IsNotEqualToTransformer.h"
#import "KeyedUnarchiveFromDataTransformer.h"
#import "LatexitEquation.h"
#import "LibraryEquation.h"
#import "LibraryManager.h"
#import "LibraryView.h"
#import "LineCountTextView.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSMutableArrayExtended.h"
#import "NSNumberIntegerShiftTransformer.h"
#import "NSPopUpButtonExtended.h"
#import "NSSegmentedControlExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "ObjectTransformer.h"
#import "PreamblesController.h"
#import "PreamblesTableView.h"
#import "ServiceShortcutsTableView.h"
#import "ServiceShortcutsTextView.h"
#import "Utils.h"

#import "RegexKitLite.h"
#import <Sparkle/Sparkle.h>

#define NSAppKitVersionNumber10_4 824

NSString* GeneralToolbarItemIdentifier       = @"GeneralToolbarItem";
NSString* EditionToolbarItemIdentifier       = @"EditionToolbarItem";
NSString* PreamblesToolbarItemIdentifier     = @"PreamblesToolbarItem";
NSString* BodyTemplatesToolbarItemIdentifier = @"BodyTemplatesToolbarItemIdentifier";
NSString* CompositionToolbarItemIdentifier   = @"CompositionToolbarItem";
NSString* HistoryToolbarItemIdentifier       = @"HistoryToolbarItem";
NSString* ServiceToolbarItemIdentifier       = @"ServiceToolbarItem";
NSString* AdvancedToolbarItemIdentifier      = @"AdvancedToolbarItem";
NSString* WebToolbarItemIdentifier           = @"WebToolbarItem";

@interface PreferencesWindowController (PrivateAPI)
-(void) updateProgramArgumentsToolTips;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;
-(void) tableViewSelectionDidChange:(NSNotification*)notification;
-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) didEndOpenPanel:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) exportFormatOptionsJpegPanel:(ExportFormatOptionsPanes*)exportFormatOptionsPanes didCloseWithOK:(BOOL)ok;
@end

@implementation PreferencesWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"PreferencesWindowController"])))
    return nil;
  self->toolbarItems = [[NSMutableDictionary alloc] init];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                               name:NSApplicationWillTerminateNotification object:nil];
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->viewsMinSizes release];
  [self->toolbarItems release];
  [self->applyPreambleToLibraryAlert release];
  [super dealloc];
}
//end dealloc

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ((object == [[PreferencesController sharedController] preamblesController]) && [keyPath isEqualToString:@"selection.value"])
    [self->preamblesValueTextView textDidChange:nil];//to force recoulouring
  else if ((object == [[PreferencesController sharedController] bodyTemplatesController]) && [keyPath isEqualToString:@"selection.head"])
    [self->bodyTemplatesHeadTextView textDidChange:nil];//to force recoulouring
  else if ((object == [[PreferencesController sharedController] bodyTemplatesController]) && [keyPath isEqualToString:@"selection.tail"])
    [self->bodyTemplatesTailTextView textDidChange:nil];//to force recoulouring
  else if ((object == [[PreferencesController sharedController] compositionConfigurationsController]) && 
           ([keyPath isEqualToString:@"arrangedObjects"] ||
            [keyPath isEqualToString:[@"arrangedObjects." stringByAppendingString:CompositionConfigurationNameKey]]))
  {
    [self->compositionConfigurationsCurrentPopUpButton removeAllItems];
    [self->compositionConfigurationsCurrentPopUpButton addItemsWithTitles:
      [[[PreferencesController sharedController] compositionConfigurationsController]
        valueForKeyPath:[@"arrangedObjects." stringByAppendingString:CompositionConfigurationNameKey]]];
    [[self->compositionConfigurationsCurrentPopUpButton menu] addItem:[NSMenuItem separatorItem]];
    [self->compositionConfigurationsCurrentPopUpButton addItemWithTitle:NSLocalizedString(@"Edit the configurations...", @"Edit the configurations...")];
  }
  else if ((object == [NSUserDefaultsController sharedUserDefaultsController]) &&
           [keyPath isEqualToString:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]])
  {
    [self->compositionConfigurationsCurrentPopUpButton selectItemAtIndex:[[PreferencesController sharedController] compositionConfigurationsDocumentIndex]];
    [self updateProgramArgumentsToolTips];
  }
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) awakeFromNib
{
  self->viewsMinSizes = [[NSDictionary alloc] initWithObjectsAndKeys:
    [NSValue valueWithSize:[self->generalView frame].size], GeneralToolbarItemIdentifier,
    [NSValue valueWithSize:[self->editionView frame].size], EditionToolbarItemIdentifier,
    [NSValue valueWithSize:[self->preamblesView frame].size], PreamblesToolbarItemIdentifier,
    [NSValue valueWithSize:[self->bodyTemplatesView frame].size], BodyTemplatesToolbarItemIdentifier,
    [NSValue valueWithSize:[self->compositionView frame].size], CompositionToolbarItemIdentifier,
    [NSValue valueWithSize:[self->historyView frame].size], HistoryToolbarItemIdentifier,
    [NSValue valueWithSize:[self->serviceView frame].size], ServiceToolbarItemIdentifier,
    [NSValue valueWithSize:[self->advancedView frame].size], AdvancedToolbarItemIdentifier,
    [NSValue valueWithSize:[self->webView frame].size], WebToolbarItemIdentifier,
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
      [button setImage:[NSImage imageNamed:@"NSActionTemplate10_4.png"]];
  }//end if (!isMacOS10_5OrAbove())
  
  NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"preferencesToolbar"];
  [toolbar setDelegate:self];
  NSWindow* window = [self window];
  [window setDelegate:self];
  [window setToolbar:toolbar];
  [window setShowsToolbarButton:NO];
  [toolbar setSelectedItemIdentifier:GeneralToolbarItemIdentifier];
  [self toolbarHit:[self->toolbarItems objectForKey:[toolbar selectedItemIdentifier]]];
  [toolbar release];
  
  NSUserDefaultsController* userDefaultsController = [NSUserDefaultsController sharedUserDefaultsController];
  PreferencesController* preferencesController = [PreferencesController sharedController];

  //General
  [self->generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"PDF vector format", @"PDF vector format")
                                                     tag:(int)EXPORT_FORMAT_PDF];
  [self->generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"PDF without embedded fonts", @"PDF without embedded fonts")
                                                     tag:(int)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
  [self->generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"EPS vector format", @"EPS vector format")
                                                     tag:(int)EXPORT_FORMAT_EPS];
  [self->generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"TIFF bitmap format", @"TIFF bitmap format")
                                                     tag:(int)EXPORT_FORMAT_TIFF];
  [self->generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"PNG bitmap format", @"PNG bitmap format")
                                                     tag:(int)EXPORT_FORMAT_PNG];
  [self->generalExportFormatPopupButton addItemWithTitle:NSLocalizedString(@"JPEG bitmap format", @"JPEG bitmap format")
                                                     tag:(int)EXPORT_FORMAT_JPEG];
  [self->generalExportFormatPopupButton bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey] options:nil];
  [self->generalExportFormatJpegWarning bind:NSHiddenBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:EXPORT_FORMAT_JPEG]], NSValueTransformerBindingOption, nil]];
  [self->generalExportFormatOptionsButton bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:EXPORT_FORMAT_JPEG]], NSValueTransformerBindingOption, nil]];
  [self->generalExportFormatOptionsButton setTarget:self];
  [self->generalExportFormatOptionsButton setAction:@selector(generalExportFormatOptionsOpen:)];

  [self->generalExportScalePercentTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DragExportScaleAsPercentKey] options:nil];
  
  [self->generalDummyBackgroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultImageViewBackgroundKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->generalDummyBackgroundAutoStateButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultAutomaticHighContrastedPreviewBackgroundKey] options:nil];

  #ifdef MIGRATE_ALIGN
  [self->generalLatexisationLaTeXModeSegmentedControl setLabel:@"Align" forSegment:0];
  [[self->generalLatexisationLaTeXModeSegmentedControl cell] setTag:LATEX_MODE_ALIGN forSegment:0];
  #else
  [[self->generalLatexisationLaTeXModeSegmentedControl cell] setTag:LATEX_MODE_EQNARRAY forSegment:0];
  #endif
  [[self->generalLatexisationLaTeXModeSegmentedControl cell] setTag:LATEX_MODE_DISPLAY forSegment:1];
  [[self->generalLatexisationLaTeXModeSegmentedControl cell] setTag:LATEX_MODE_INLINE  forSegment:2];
  [[self->generalLatexisationLaTeXModeSegmentedControl cell] setTag:LATEX_MODE_TEXT  forSegment:3];
  [self->generalLatexisationLaTeXModeSegmentedControl bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultModeKey] options:nil];

  [self->generalLatexisationFontSizeTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultPointSizeKey] options:nil];
  [self->generalLatexisationFontColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];

  //margins
  [self->marginsAdditionalTopTextField    setFormatter:self->marginsAdditionalPointSizeFormatter];
  [self->marginsAdditionalLeftTextField   setFormatter:self->marginsAdditionalPointSizeFormatter];
  [self->marginsAdditionalRightTextField  setFormatter:self->marginsAdditionalPointSizeFormatter];
  [self->marginsAdditionalBottomTextField setFormatter:self->marginsAdditionalPointSizeFormatter];
  [self->marginsAdditionalTopTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:AdditionalTopMarginKey] options:nil];
  [self->marginsAdditionalLeftTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:AdditionalLeftMarginKey] options:nil];
  [self->marginsAdditionalRightTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:AdditionalRightMarginKey] options:nil];
  [self->marginsAdditionalBottomTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:AdditionalBottomMarginKey] options:nil];

  //Edition
  [self->editionFontNameTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:DefaultFontKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [ComposedTransformer
        transformerWithValueTransformer:[NSValueTransformer valueTransformerForName:[KeyedUnarchiveFromDataTransformer name]]
        additionalValueTransformer:nil
        additionalKeyPath:@"displayNameWithPointSize"], NSValueTransformerBindingOption, nil]];
  [self->editionSyntaxColoringStateButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringEnableKey]
    options:nil];
  [self->editionSyntaxColoringTextForegroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringTextForegroundColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->editionSyntaxColoringTextBackgroundColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringTextBackgroundColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->editionSyntaxColoringCommandColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringCommandColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->editionSyntaxColoringKeywordColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringKeywordColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->editionSyntaxColoringMathsColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringMathsColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->editionSyntaxColoringCommentColorWell bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SyntaxColoringCommentColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->editionSpellCheckingStateButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:SpellCheckingEnableKey]
    options:nil];
  
  [self->editionTextAreaReducedButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ReducedTextAreaStateKey] options:nil];

  NSArrayController* editionTextShortcutsController = [preferencesController editionTextShortcutsController];
  [self->editionTextShortcutsAddButton bind:NSEnabledBinding toObject:editionTextShortcutsController withKeyPath:@"canAdd" options:nil];
  [self->editionTextShortcutsAddButton setTarget:editionTextShortcutsController];
  [self->editionTextShortcutsAddButton setAction:@selector(add:)];
  [self->editionTextShortcutsRemoveButton bind:NSEnabledBinding toObject:editionTextShortcutsController withKeyPath:@"canRemove" options:nil];
  [self->editionTextShortcutsRemoveButton setTarget:editionTextShortcutsController];
  [self->editionTextShortcutsRemoveButton setAction:@selector(remove:)];

  //Preambles
  PreamblesController* preamblesController = [preferencesController preamblesController];
  [self->preamblesAddButton setTarget:preamblesController];
  [self->preamblesAddButton setAction:@selector(add:)];
  [self->preamblesAddButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"canAdd" options:nil];
  [self->preamblesRemoveButton setTarget:preamblesController];
  [self->preamblesRemoveButton setAction:@selector(remove:)];
  [self->preamblesRemoveButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"canRemove" options:nil];
  [self->preamblesValueTextView bind:NSAttributedStringBinding toObject:preamblesController withKeyPath:@"selection.value" options:
    [NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->preamblesValueTextView bind:NSEditableBinding toObject:preamblesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  [preamblesController addObserver:self forKeyPath:@"selection.value" options:0 context:nil];//to recolour the preamblesValueTextView...
  [self observeValueForKeyPath:@"selection.value" ofObject:preamblesController change:nil context:nil];
  
  [self->preamblesValueResetDefaultButton setTarget:self];
  [self->preamblesValueResetDefaultButton setAction:@selector(preamblesValueResetDefault:)];
  [self->preamblesValueResetDefaultButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];

  [self->preamblesValueApplyToOpenedDocumentsButton setTarget:self];
  [self->preamblesValueApplyToOpenedDocumentsButton setAction:@selector(preamblesValueApplyToOpenedDocuments:)];
  [self->preamblesValueApplyToOpenedDocumentsButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];

  [self->preamblesValueApplyToLibraryButton setTarget:self];
  [self->preamblesValueApplyToLibraryButton setAction:@selector(preamblesValueApplyToLibrary:)];
  [self->preamblesValueApplyToLibraryButton bind:NSEnabledBinding toObject:preamblesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  
  [self->preamblesNamesLatexisationPopUpButton bind:NSContentValuesBinding toObject:preamblesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [self->preamblesNamesLatexisationPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:LatexisationSelectedPreambleIndexKey] options:nil];

  //BodyTemplates
  BodyTemplatesController* bodyTemplatesController = [preferencesController bodyTemplatesController];
  [self->bodyTemplatesAddButton setTarget:bodyTemplatesController];
  [self->bodyTemplatesAddButton setAction:@selector(add:)];
  [self->bodyTemplatesAddButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"canAdd" options:nil];
  [self->bodyTemplatesRemoveButton setTarget:bodyTemplatesController];
  [self->bodyTemplatesRemoveButton setAction:@selector(remove:)];
  [self->bodyTemplatesRemoveButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"canRemove" options:nil];
  [self->bodyTemplatesHeadTextView bind:NSAttributedStringBinding toObject:bodyTemplatesController withKeyPath:@"selection.head" options:
    [NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->bodyTemplatesHeadTextView bind:NSEditableBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  [self->bodyTemplatesTailTextView bind:NSAttributedStringBinding toObject:bodyTemplatesController withKeyPath:@"selection.tail" options:
    [NSDictionary dictionaryWithObjectsAndKeys:[KeyedUnarchiveFromDataTransformer name], NSValueTransformerNameBindingOption, nil]];
  [self->bodyTemplatesTailTextView bind:NSEditableBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  [bodyTemplatesController addObserver:self forKeyPath:@"selection.head" options:0 context:nil];//to recolour the bodyTemplatesHeadTextView
  [bodyTemplatesController addObserver:self forKeyPath:@"selection.tail" options:0 context:nil];//to recolour the bodyTemplatesTailTextView
  [self observeValueForKeyPath:@"selection.head" ofObject:bodyTemplatesController change:nil context:nil];
  [self observeValueForKeyPath:@"selection.tail" ofObject:bodyTemplatesController change:nil context:nil];
  
  [self->bodyTemplatesApplyToOpenedDocumentsButton setTarget:self];
  [self->bodyTemplatesApplyToOpenedDocumentsButton setAction:@selector(bodyTemplatesApplyToOpenedDocuments:)];
  [self->bodyTemplatesApplyToOpenedDocumentsButton bind:NSEnabledBinding toObject:bodyTemplatesController withKeyPath:@"selection" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];

  [self->bodyTemplatesNamesLatexisationPopUpButton bind:NSContentValuesBinding toObject:bodyTemplatesController
    withKeyPath:@"arrangedObjectsNamesWithNone" options:nil];
  [self->bodyTemplatesNamesLatexisationPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
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
  [self->compositionConfigurationsCurrentPopUpButton setTarget:self];
  [self->compositionConfigurationsCurrentPopUpButton setAction:@selector(compositionConfigurationsManagerOpen:)];

  [self->compositionConfigurationsProgramArgumentsAddButton setTarget:self->compositionConfigurationsProgramArgumentsTableView];
  [self->compositionConfigurationsProgramArgumentsAddButton setAction:@selector(add:)];
  [self->compositionConfigurationsProgramArgumentsRemoveButton setTarget:compositionConfigurationsProgramArgumentsTableView];
  [self->compositionConfigurationsProgramArgumentsRemoveButton setAction:@selector(remove:)];
  [self->compositionConfigurationsProgramArgumentsOkButton setTarget:self];
  [self->compositionConfigurationsProgramArgumentsOkButton setAction:@selector(compositionConfigurationsProgramArgumentsClose:)];

  [self->compositionConfigurationsManagerAddButton bind:NSEnabledBinding toObject:compositionConfigurationsController withKeyPath:@"canAdd" options:nil];
  [self->compositionConfigurationsManagerAddButton setTarget:compositionConfigurationsController];
  [self->compositionConfigurationsManagerAddButton setAction:@selector(add:)];
  [self->compositionConfigurationsManagerRemoveButton bind:NSEnabledBinding toObject:compositionConfigurationsController withKeyPath:@"canRemove" options:nil];
  [self->compositionConfigurationsManagerRemoveButton setTarget:compositionConfigurationsController];
  [self->compositionConfigurationsManagerRemoveButton setAction:@selector(remove:)];
  [self->compositionConfigurationsManagerOkButton setTarget:self];
  [self->compositionConfigurationsManagerOkButton setAction:@selector(compositionConfigurationsManagerClose:)];

  NSDictionary* isNotNilBindingOptions =
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil];
  NSString* NSEnabled2Binding = [NSEnabledBinding stringByAppendingString:@"2"];

  [self->compositionConfigurationsCurrentEngineMatrix bind:NSSelectedTagBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey] options:nil];
  [self->compositionConfigurationsCurrentLoginShellUsedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentLoginShellUsedButton bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationUseLoginShellKey] options:nil];

  NSDictionary* colorForFileExistsBindingOptions =
    [NSDictionary dictionaryWithObjectsAndKeys:
      [ComposedTransformer
        transformerWithValueTransformer:[FileExistsTransformer transformerWithDirectoryAllowed:NO]
             additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor blackColor]]
             additionalKeyPath:nil], NSValueTransformerBindingOption, nil];

  [self->compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey] options:nil];
  [self->compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentPdfLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey] options:colorForFileExistsBindingOptions];

  [self->compositionConfigurationsCurrentPdfLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentPdfLaTeXAdvancedButton setTarget:self];
  [self->compositionConfigurationsCurrentPdfLaTeXAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [self->compositionConfigurationsCurrentPdfLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentPdfLaTeXPathChangeButton setTarget:self];
  [self->compositionConfigurationsCurrentPdfLaTeXPathChangeButton setAction:@selector(compositionConfigurationsChangePath:)];

  [self->compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey] options:nil];
  [self->compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_XELATEX]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentXeLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey] options:colorForFileExistsBindingOptions];

  [self->compositionConfigurationsCurrentXeLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentXeLaTeXAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_XELATEX]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentXeLaTeXAdvancedButton setTarget:self];
  [self->compositionConfigurationsCurrentXeLaTeXAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [self->compositionConfigurationsCurrentXeLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentXeLaTeXPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_XELATEX]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentXeLaTeXPathChangeButton setTarget:self];
  [self->compositionConfigurationsCurrentXeLaTeXPathChangeButton setAction:@selector(compositionConfigurationsChangePath:)];

  [self->compositionConfigurationsCurrentLaTeXPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLatexPathKey] options:nil];
  [self->compositionConfigurationsCurrentLaTeXPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentLaTeXPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentLaTeXPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLatexPathKey] options:colorForFileExistsBindingOptions];

  [self->compositionConfigurationsCurrentLaTeXAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentLaTeXAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentLaTeXAdvancedButton setTarget:self];
  [self->compositionConfigurationsCurrentLaTeXAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [self->compositionConfigurationsCurrentLaTeXPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentLaTeXPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentLaTeXPathChangeButton setTarget:self];
  [self->compositionConfigurationsCurrentLaTeXPathChangeButton setAction:@selector(compositionConfigurationsChangePath:)];

  [self->compositionConfigurationsCurrentDviPdfPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationDviPdfPathKey] options:nil];
  [self->compositionConfigurationsCurrentDviPdfPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentDviPdfPathTextField bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentDviPdfPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationDviPdfPathKey] options:colorForFileExistsBindingOptions];

  [self->compositionConfigurationsCurrentDviPdfAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentDviPdfAdvancedButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentDviPdfAdvancedButton setTarget:self];
  [self->compositionConfigurationsCurrentDviPdfAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [self->compositionConfigurationsCurrentDviPdfPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentDviPdfPathChangeButton bind:NSEnabled2Binding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
          [IsEqualToTransformer transformerWithReference:[NSNumber numberWithInt:COMPOSITION_MODE_LATEXDVIPDF]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsCurrentDviPdfPathChangeButton setTarget:self];
  [self->compositionConfigurationsCurrentDviPdfPathChangeButton setAction:@selector(compositionConfigurationsChangePath:)];

  [self->compositionConfigurationsCurrentGsPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationGsPathKey] options:nil];
  [self->compositionConfigurationsCurrentGsPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentGsPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationGsPathKey] options:colorForFileExistsBindingOptions];

  [self->compositionConfigurationsCurrentGsAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentGsAdvancedButton setTarget:self];
  [self->compositionConfigurationsCurrentGsAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [self->compositionConfigurationsCurrentGsPathChangeButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentGsPathChangeButton setTarget:self];
  [self->compositionConfigurationsCurrentGsPathChangeButton setAction:@selector(compositionConfigurationsChangePath:)];

  [self->compositionConfigurationsCurrentPsToPdfPathTextField bind:NSValueBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPsToPdfPathKey] options:nil];
  [self->compositionConfigurationsCurrentPsToPdfPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentPsToPdfPathTextField bind:NSTextColorBinding toObject:compositionConfigurationsController
    withKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPsToPdfPathKey] options:colorForFileExistsBindingOptions];
  [self->compositionConfigurationsCurrentPsToPdfPathTextField bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];

  [self->compositionConfigurationsCurrentPsToPdfAdvancedButton bind:NSEnabledBinding toObject:compositionConfigurationsController
    withKeyPath:@"selection" options:isNotNilBindingOptions];
  [self->compositionConfigurationsCurrentPsToPdfAdvancedButton setTarget:self];
  [self->compositionConfigurationsCurrentPsToPdfAdvancedButton setAction:@selector(compositionConfigurationsProgramArgumentsOpen:)];

  [self->compositionConfigurationsCurrentPsToPdfPathChangeButton setTarget:self];
  [self->compositionConfigurationsCurrentPsToPdfPathChangeButton setAction:@selector(compositionConfigurationsChangePath:)];
  
  [self updateProgramArgumentsToolTips];

  //history
  [self->historySaveServiceResultsCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceUsesHistoryKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
  [self->historyDeleteOldEntriesCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
  [self->historyDeleteOldEntriesLimitTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesLimitKey]
    options:nil];
  [self->historyDeleteOldEntriesLimitTextField bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:nil];
  [self->historyDeleteOldEntriesLimitStepper setFormatter:[self->historyDeleteOldEntriesLimitTextField formatter]];
  [self->historyDeleteOldEntriesLimitStepper bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesLimitKey]
    options:nil];
  [self->historyDeleteOldEntriesLimitStepper bind:NSEnabledBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistoryDeleteOldEntriesEnabledKey]
    options:nil];
  [self->historySmartCheckbox bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:HistorySmartEnabledKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];

  // additional scripts
  [[self->compositionConfigurationsAdditionalScriptsTableView tableColumnWithIdentifier:@"place"] bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController] withKeyPath:@"arrangedObjects.key"
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [ObjectTransformer transformerWithDictionary:
        [NSDictionary dictionaryWithObjectsAndKeys:
          NSLocalizedString(@"Pre-processing", @"Pre-processing"), [[NSNumber numberWithInt:SCRIPT_PLACE_PREPROCESSING] stringValue], 
          NSLocalizedString(@"Middle-processing", @"Middle-processing"), [[NSNumber numberWithInt:SCRIPT_PLACE_MIDDLEPROCESSING] stringValue], 
          NSLocalizedString(@"Post-processing", @"Post-processing"), [[NSNumber numberWithInt:SCRIPT_PLACE_POSTPROCESSING] stringValue], nil]],
       NSValueTransformerBindingOption, nil]];
  [[self->compositionConfigurationsAdditionalScriptsTableView tableColumnWithIdentifier:@"enabled"] bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[@"arrangedObjects.value." stringByAppendingString:CompositionConfigurationAdditionalProcessingScriptEnabledKey]
    options:nil];

  [self->compositionConfigurationsAdditionalScriptsTypePopUpButton removeAllItems];
  [[[self->compositionConfigurationsAdditionalScriptsTypePopUpButton menu]
    addItemWithTitle:NSLocalizedString(@"Define a script", @"Define a script") action:nil keyEquivalent:@""] setTag:SCRIPT_SOURCE_STRING];
  [[[self->compositionConfigurationsAdditionalScriptsTypePopUpButton menu]
    addItemWithTitle:NSLocalizedString(@"Use existing script", @"Use existing script") action:nil keyEquivalent:@""] setTag:SCRIPT_SOURCE_FILE];
  [self->compositionConfigurationsAdditionalScriptsTypePopUpButton bind:NSSelectedTagBinding
     toObject:[compositionConfigurationsController currentConfigurationScriptsController]
     withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
     options:nil];
     
  [self->compositionConfigurationsAdditionalScriptsTypePopUpButton bind:NSEnabledBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:@"selection" options:isNotNilBindingOptions];

  [self->compositionConfigurationsAdditionalScriptsDefiningBox bind:NSHiddenBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_STRING]], NSValueTransformerBindingOption, nil]];
  [self->compositionConfigurationsAdditionalScriptsExistingBox bind:NSHiddenBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptTypeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInt:SCRIPT_SOURCE_FILE]], NSValueTransformerBindingOption, nil]];

  [self->compositionConfigurationsAdditionalScriptsDefiningShellTextField bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
    options:nil];
  [self->compositionConfigurationsAdditionalScriptsDefiningShellTextField bind:NSTextColorBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptShellKey]
    options:colorForFileExistsBindingOptions];
  [self->compositionConfigurationsAdditionalScriptsDefiningContentTextView setFont:[NSFont fontWithName:@"Monaco" size:12.]];
  [self->compositionConfigurationsAdditionalScriptsDefiningContentTextView bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptContentKey]
    options:nil];

  [self->compositionConfigurationsAdditionalScriptsExistingPathTextField bind:NSValueBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]
    options:nil];
  [self->compositionConfigurationsAdditionalScriptsExistingPathTextField bind:NSTextColorBinding
    toObject:[compositionConfigurationsController currentConfigurationScriptsController]
    withKeyPath:[NSString stringWithFormat:@"selection.value.%@", CompositionConfigurationAdditionalProcessingScriptPathKey]
    options:colorForFileExistsBindingOptions];
  [self->compositionConfigurationsAdditionalScriptsExistingPathChangeButton setTarget:self];
  [self->compositionConfigurationsAdditionalScriptsExistingPathChangeButton setAction:@selector(compositionConfigurationsChangePath:)];

  //service
  [self->servicePreamblePopUpButton bind:NSContentValuesBinding toObject:preamblesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [self->servicePreamblePopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceSelectedPreambleIndexKey] options:nil];
  [self->serviceBodyTemplatesPopUpButton bind:NSContentValuesBinding toObject:bodyTemplatesController withKeyPath:@"arrangedObjects.name"
    options:nil];
  [self->serviceBodyTemplatesPopUpButton bind:NSSelectedIndexBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceSelectedBodyTemplateIndexKey] options:nil];

  [[self->serviceRespectsPointSizeMatrix cellAtRow:0 column:0] setTag:0];
  [[self->serviceRespectsPointSizeMatrix cellAtRow:1 column:0] setTag:1];
  [self->serviceRespectsPointSizeMatrix bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsPointSizeKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:0] trueValue:[NSNumber numberWithInt:1]], NSValueTransformerBindingOption, nil]];
  [self->servicePointSizeFactorTextField bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServicePointSizeFactorKey] options:nil];
  [self->servicePointSizeFactorStepper bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServicePointSizeFactorKey] options:nil];
  [self->servicePointSizeFactorTextField setFormatter:self->servicePointSizeFactorFormatter];
  [self->servicePointSizeFactorStepper   setFormatter:self->servicePointSizeFactorFormatter];

  [[self->serviceRespectsColorMatrix cellAtRow:0 column:0] setTag:0];
  [[self->serviceRespectsColorMatrix cellAtRow:1 column:0] setTag:1];
  [self->serviceRespectsColorMatrix bind:NSSelectedTagBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsColorKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:0] trueValue:[NSNumber numberWithInt:1]], NSValueTransformerBindingOption, nil]];

  [self->serviceRespectsBaselineButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsBaselineKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
  [self->serviceWarningLinkBackButton bind:NSHiddenBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceRespectsBaselineKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];

  [self->serviceUsesHistoryButton bind:NSValueBinding toObject:userDefaultsController
    withKeyPath:[userDefaultsController adaptedKeyPath:ServiceUsesHistoryKey]
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
      
  [self->serviceRelaunchWarning setHidden:isMacOS10_5OrAbove()];
  
  [self->advancedSplitView setIsPaneSplitter:YES];

  //additional files
  AdditionalFilesController* additionalFilesController = [preferencesController additionalFilesController];
  [self->additionalFilesAddButton bind:NSEnabledBinding toObject:additionalFilesController withKeyPath:@"canAdd" options:nil];
  [self->additionalFilesAddButton setTarget:self->additionalFilesTableView];
  [self->additionalFilesAddButton setAction:@selector(addFiles:)];
  [self->additionalFilesRemoveButton bind:NSEnabledBinding toObject:additionalFilesController withKeyPath:@"canRemove" options:nil];
  [self->additionalFilesRemoveButton setTarget:additionalFilesController];
  [self->additionalFilesRemoveButton setAction:@selector(remove:)];
  [self->additionalFilesHelpButton setTarget:self];
  [self->additionalFilesHelpButton setAction:@selector(additionalFilesHelpOpen:)];

  //encapsulations
  EncapsulationsController* encapsulationsController = [preferencesController encapsulationsController];
  [self->encapsulationsAddButton bind:NSEnabledBinding toObject:encapsulationsController withKeyPath:@"canAdd" options:nil];
  [self->encapsulationsAddButton setTarget:encapsulationsController];
  [self->encapsulationsAddButton setAction:@selector(add:)];
  [self->encapsulationsRemoveButton bind:NSEnabledBinding toObject:encapsulationsController withKeyPath:@"canRemove" options:nil];
  [self->encapsulationsRemoveButton setTarget:encapsulationsController];
  [self->encapsulationsRemoveButton setAction:@selector(remove:)];

  //updates
  [self->updatesCheckUpdatesButton bind:NSValueBinding toObject:[[AppController appController] sparkleUpdater]
    withKeyPath:@"automaticallyChecksForUpdates"
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];
}
//end awakeFromNib

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
                                   PreamblesToolbarItemIdentifier, BodyTemplatesToolbarItemIdentifier,
                                   CompositionToolbarItemIdentifier, HistoryToolbarItemIdentifier,
                                   ServiceToolbarItemIdentifier, AdvancedToolbarItemIdentifier,
                                   WebToolbarItemIdentifier, nil];
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
    else if ([itemIdentifier isEqualToString:PreamblesToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"preambleToolbarItem" ofType:@"tiff"];
      label = [NSLocalizedString(@"Preambles", @"Preambles") stringByReplacingOccurrencesOfRegex:@"LaTeX" withString:@""];
    }
    else if ([itemIdentifier isEqualToString:BodyTemplatesToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"bodyTemplateToolbarItem" ofType:@"tiff"];
      label = [NSLocalizedString(@"Body templates", @"Body templates") stringByReplacingOccurrencesOfRegex:@"LaTeX" withString:@""];
    }
    else if ([itemIdentifier isEqualToString:CompositionToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"compositionToolbarItem" ofType:@"tiff"];
      label = [NSLocalizedString(@"Composition", @"Composition") stringByReplacingOccurrencesOfRegex:@"LaTeX" withString:@""];
    }
    else if ([itemIdentifier isEqualToString:HistoryToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"historyToolbarItem" ofType:@"tiff"];
      label = [NSLocalizedString(@"History", @"History") stringByReplacingOccurrencesOfRegex:@"LaTeX" withString:@""];
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
  }//end if (item)
  return item;
}
//end toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:

-(IBAction) toolbarHit:(id)sender
{
  NSView* view = nil;
  NSString* itemIdentifier = [sender itemIdentifier];

  if ([itemIdentifier isEqualToString:GeneralToolbarItemIdentifier])
    view = self->generalView;
  else if ([itemIdentifier isEqualToString:EditionToolbarItemIdentifier])
    view = self->editionView;
  else if ([itemIdentifier isEqualToString:PreamblesToolbarItemIdentifier])
    view = self->preamblesView;
  else if ([itemIdentifier isEqualToString:BodyTemplatesToolbarItemIdentifier])
    view = self->bodyTemplatesView;
  else if ([itemIdentifier isEqualToString:CompositionToolbarItemIdentifier])
    view = self->compositionView;
  else if ([itemIdentifier isEqualToString:HistoryToolbarItemIdentifier])
    view = self->historyView;
  else if ([itemIdentifier isEqualToString:ServiceToolbarItemIdentifier])
    view = self->serviceView;
  else if ([itemIdentifier isEqualToString:AdvancedToolbarItemIdentifier])
    view = self->advancedView;
  else if ([itemIdentifier isEqualToString:WebToolbarItemIdentifier])
    view = self->webView;

  NSWindow* window = [self window];
  NSView*   contentView = [window contentView];
  if (view != contentView)
  {
    NSSize contentMinSize = [[self->viewsMinSizes objectForKey:itemIdentifier] sizeValue];
    NSRect oldContentFrame = contentView ? [contentView frame] : NSZeroRect;
    NSRect newContentFrame = !view ? NSZeroRect : [view frame];
    NSRect newFrame = [window frame];
    newFrame.size.width  += (newContentFrame.size.width  - oldContentFrame.size.width);
    newFrame.size.height += (newContentFrame.size.height - oldContentFrame.size.height);
    newFrame.origin.y    -= (newContentFrame.size.height - oldContentFrame.size.height);
    [[window contentView] retain];
    [self->emptyView setFrame:newContentFrame];
    [window setContentView:self->emptyView];
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
  [self->updatesCheckUpdatesNowButton setEnabled:![[[AppController appController] sparkleUpdater] updateInProgress]];
}
//end toolbarHit:

-(void) selectPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier
{
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
  return ok;
}
//end validateMenuItem:

-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [[self window] makeFirstResponder:nil];//commit editing
}
//end applicationWillTerminate:

#pragma mark general

-(IBAction) generalExportFormatOptionsOpen:(id)sender
{
  if (!self->generalExportFormatOptionsPanes)
  {
    self->generalExportFormatOptionsPanes = [[ExportFormatOptionsPanes alloc] initWithLoadingFromNib];
    [self->generalExportFormatOptionsPanes setExportFormatOptionsJpegPanelDelegate:self];
  }
  [self->generalExportFormatOptionsPanes setJpegQualityPercent:[[PreferencesController sharedController] exportJpegQualityPercent]];
  [self->generalExportFormatOptionsPanes setJpegBackgroundColor:[[PreferencesController sharedController] exportJpegBackgroundColor]];
  [NSApp beginSheet:[self->generalExportFormatOptionsPanes exportFormatOptionsJpegPanel]
     modalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}
//end openOptionsForDragExport:

-(void) exportFormatOptionsJpegPanel:(ExportFormatOptionsPanes*)exportFormatOptionsPanes didCloseWithOK:(BOOL)ok
{
  if (ok)
  {
    [[PreferencesController sharedController] setExportJpegQualityPercent:[exportFormatOptionsPanes jpegQualityPercent]];
    [[PreferencesController sharedController] setExportJpegBackgroundColor:[exportFormatOptionsPanes jpegBackgroundColor]];
  }//end if (ok)
  [NSApp endSheet:[exportFormatOptionsPanes exportFormatOptionsJpegPanel]];
  [[exportFormatOptionsPanes exportFormatOptionsJpegPanel] orderOut:self];
}
//end exportFormatOptionsJpegPanel:didCloseWithOK:

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

  NSMutableAttributedString* example = [self->editionSyntaxColouringTextView textStorage];
  [example addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [example length])];

  //if sender is nil or self, this "changeFont:" only updates fontTextField, but should not modify textViews
  if (sender && (sender != self))
  {
    NSMutableAttributedString* preamble = [self->preamblesValueTextView textStorage];
    [preamble addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [preamble length])];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self->preamblesValueTextView];

    NSMutableAttributedString* bodyTemplateHead = [self->bodyTemplatesHeadTextView textStorage];
    [bodyTemplateHead addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [bodyTemplateHead length])];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self->bodyTemplatesHeadTextView];

    NSMutableAttributedString* bodyTemplateTail = [self->bodyTemplatesTailTextView textStorage];
    [bodyTemplateTail addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [bodyTemplateTail length])];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self->bodyTemplatesTailTextView];

    NSMutableAttributedString* example = [self->editionSyntaxColouringTextView textStorage];
    [example addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [example length])];
    
    NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
    [documents makeObjectsPerformSelector:@selector(setFont:) withObject:newFont];
  }
}
//end changeFont:

#pragma mark preambles

-(IBAction) preamblesValueResetDefault:(id)sender
{
  [self->preamblesValueTextView setValue:[PreamblesController defaultLocalizedPreambleValueAttributedString] forKey:NSAttributedStringBinding];
  [[[PreferencesController sharedController] preamblesController]
    setValue:[NSKeyedArchiver archivedDataWithRootObject:[PreamblesController defaultLocalizedPreambleValueAttributedString]]
    forKeyPath:@"selection.value"];
}
//end preamblesValueResetDefault:

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
  if (!self->applyPreambleToLibraryAlert)
  {
    self->applyPreambleToLibraryAlert = [[NSAlert alloc] init];
    [self->applyPreambleToLibraryAlert setMessageText:NSLocalizedString(@"Do you really want to apply that preamble to the library items ?",
                                                                        @"Do you really want to apply that preamble to the library items ?")];
    [self->applyPreambleToLibraryAlert setInformativeText:
      NSLocalizedString(@"Their old preamble will be overwritten. If it was a special preamble that had been tuned to generate them, it will be lost.",
                        @"Their old preamble will be overwritten. If it was a special preamble that had been tuned to generate them, it will be lost.")];
    [self->applyPreambleToLibraryAlert setAlertStyle:NSWarningAlertStyle];
    [self->applyPreambleToLibraryAlert addButtonWithTitle:NSLocalizedString(@"Apply", @"Apply")];
    [self->applyPreambleToLibraryAlert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
  }
  int choice = [self->applyPreambleToLibraryAlert runModal];
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
  NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
  [documents makeObjectsPerformSelector:@selector(setBodyTemplate:) withObject:[preferencesController bodyTemplateDocumentDictionary]];
}
//end bodyTemplatesApplyToOpenedDocuments:

#pragma mark composition configurations

-(IBAction) compositionConfigurationsProgramArgumentsOpen:(id)sender
{
  CompositionConfigurationsProgramArgumentsController* controller = nil;
  if (sender == self->compositionConfigurationsCurrentPdfLaTeXAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsPdfLaTeXController];
  else if (sender == self->compositionConfigurationsCurrentXeLaTeXAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsXeLaTeXController];
  else if (sender == self->compositionConfigurationsCurrentLaTeXAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsLaTeXController];
  else if (sender == self->compositionConfigurationsCurrentDviPdfAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsDviPdfController];
  else if (sender == self->compositionConfigurationsCurrentGsAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsGsController];
  else if (sender == self->compositionConfigurationsCurrentPsToPdfAdvancedButton)
    controller = [[[PreferencesController sharedController] compositionConfigurationsController] currentConfigurationProgramArgumentsPsToPdfController];
  if (controller)
  {
    [self->compositionConfigurationsProgramArgumentsAddButton bind:NSEnabledBinding toObject:controller withKeyPath:@"canAdd" options:nil];
    [self->compositionConfigurationsProgramArgumentsRemoveButton bind:NSEnabledBinding toObject:controller withKeyPath:@"canRemove" options:nil];
    [self->compositionConfigurationsProgramArgumentsTableView setController:controller];
    [NSApp beginSheet:self->compositionConfigurationsProgramArgumentsPanel modalForWindow:[self window] modalDelegate:self
      didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
  }
}
//end compositionConfigurationsProgramArgumentsOpen:

-(IBAction) compositionConfigurationsProgramArgumentsClose:(id)sender
{
  [self->compositionConfigurationsProgramArgumentsPanel makeFirstResponder:nil];//commit editing
  [NSApp endSheet:self->compositionConfigurationsProgramArgumentsPanel returnCode:NSOKButton];
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
  [self->compositionConfigurationsCurrentPdfLaTeXPathTextField  setToolTip:arguments];
  [self->compositionConfigurationsCurrentPdfLaTeXAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationXeLatexPathKey] componentsJoinedByString:@" "];
  [self->compositionConfigurationsCurrentXeLaTeXPathTextField  setToolTip:arguments];
  [self->compositionConfigurationsCurrentXeLaTeXAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationLatexPathKey] componentsJoinedByString:@" "];
  [self->compositionConfigurationsCurrentLaTeXPathTextField  setToolTip:arguments];
  [self->compositionConfigurationsCurrentLaTeXAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationDviPdfPathKey] componentsJoinedByString:@" "];
  [self->compositionConfigurationsCurrentDviPdfPathTextField  setToolTip:arguments];
  [self->compositionConfigurationsCurrentDviPdfAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationGsPathKey] componentsJoinedByString:@" "];
  [self->compositionConfigurationsCurrentGsPathTextField  setToolTip:arguments];
  [self->compositionConfigurationsCurrentGsAdvancedButton setToolTip:arguments];
  arguments = [[compositionConfigurationsController currentConfigurationProgramArgumentsForKey:CompositionConfigurationPsToPdfPathKey] componentsJoinedByString:@" "];
  [self->compositionConfigurationsCurrentPsToPdfPathTextField  setToolTip:arguments];
  [self->compositionConfigurationsCurrentPsToPdfAdvancedButton setToolTip:arguments];
}
//end updateProgramArgumentsToolTips:

-(IBAction) compositionConfigurationsManagerOpen:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSArray* compositionConfigurations = [preferencesController compositionConfigurations];
  int selectedIndex = [self->compositionConfigurationsCurrentPopUpButton indexOfSelectedItem];
  if ((sender != self->compositionConfigurationsCurrentPopUpButton) || !IsBetween_i(1, selectedIndex+1, [compositionConfigurations count]))
    [NSApp beginSheet:self->compositionConfigurationsManagerPanel modalForWindow:[self window] modalDelegate:self
      didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
  else
    [preferencesController setCompositionConfigurationsDocumentIndex:selectedIndex];
}
//end compositionConfigurationsManagerOpen:

-(IBAction) compositionConfigurationsManagerClose:(id)sender
{
  [self->compositionConfigurationsManagerPanel makeFirstResponder:nil];//commit editing
  [NSApp endSheet:self->compositionConfigurationsManagerPanel returnCode:NSOKButton];
  [self observeValueForKeyPath:[NSUserDefaultsController adaptedKeyPath:CompositionConfigurationDocumentIndexKey]
    ofObject:[NSUserDefaultsController sharedUserDefaultsController] change:nil context:nil];
}
//end compositionConfigurationsManagerClose:

-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (sheet == self->compositionConfigurationsManagerPanel)
    [sheet orderOut:self];
  else if (sheet == self->compositionConfigurationsProgramArgumentsPanel)
    [sheet orderOut:self];
}
//end sheetDidEnd:returnCode:contextInfo:

-(IBAction) compositionConfigurationsChangePath:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setResolvesAliases:YES];
  NSTextField* textField = nil;
  if (sender == self->compositionConfigurationsCurrentPdfLaTeXPathChangeButton)
    textField = self->compositionConfigurationsCurrentPdfLaTeXPathTextField;
  else if (sender == self->compositionConfigurationsCurrentXeLaTeXPathChangeButton)
    textField = self->compositionConfigurationsCurrentXeLaTeXPathTextField;
  else if (sender == self->compositionConfigurationsCurrentLaTeXPathChangeButton)
    textField = self->compositionConfigurationsCurrentLaTeXPathTextField;
  else if (sender == self->compositionConfigurationsCurrentDviPdfPathChangeButton)
    textField = self->compositionConfigurationsCurrentDviPdfPathTextField;
  else if (sender == self->compositionConfigurationsCurrentGsPathChangeButton)
    textField = self->compositionConfigurationsCurrentGsPathTextField;
  else if (sender == self->compositionConfigurationsCurrentPsToPdfPathChangeButton)
    textField = self->compositionConfigurationsCurrentPsToPdfPathTextField;
  else if (sender == self->compositionConfigurationsAdditionalScriptsExistingPathChangeButton)
    textField = self->compositionConfigurationsAdditionalScriptsExistingPathTextField;
  NSString* filename = [textField stringValue];
  NSString* path = filename ? filename : @"";
  path = [[NSFileManager defaultManager] fileExistsAtPath:path] ? [path stringByDeletingLastPathComponent] : nil;
  [openPanel beginSheetForDirectory:path file:[filename lastPathComponent] types:nil modalForWindow:[self window] modalDelegate:self
                           didEndSelector:@selector(didEndOpenPanel:returnCode:contextInfo:) contextInfo:textField];
}
//end compositionConfigurationsChangePath:

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
    }//end if (filenames && [filenames count])
  }//end if ((returnCode == NSOKButton) && contextInfo)
}
//end didEndOpenPanel:returnCode:contextInfo:

-(IBAction) compositionConfigurationsAdditionalScriptsOpenHelp:(id)sender
{
  [self->compositionConfigurationsAdditionalScriptsHelpPanel makeKeyAndOrderFront:sender];
}
//end compositionConfigurationsAdditionalScriptsOpenHelp:

#pragma mark additional files

-(IBAction) additionalFilesHelpOpen:(id)sender
{
  [[AppController appController] showHelp:self section:[NSString stringWithFormat:@"\"%@\"\n\n", NSLocalizedString(@"Additional files", @"Additional files")]];
}
//end additionalFilesHelpOpen:

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

@end
