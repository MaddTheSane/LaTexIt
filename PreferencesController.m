//  PreferencesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import "PreferencesController.h"

#import "AppController.h"
#import "CompositionConfigurationManager.h"
#import "EncapsulationManager.h"
#import "EncapsulationTableView.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSMutableArrayExtended.h"
#import "NSPopUpButtonExtended.h"
#import "NSSegmentedControlExtended.h"
#import "LibraryManager.h"
#import "LibraryTableView.h"
#import "LineCountTextView.h"
#import "MyDocument.h"
#import "PreamblesController.h"
#import "PreamblesTableView.h"
#import "SMLSyntaxColouring.h"
#import "ServiceShortcutsTextView.h"
#import "TextShortcutsManager.h"
#import "Utils.h"

#import <Sparkle/Sparkle.h>

#define NSAppKitVersionNumber10_4 824

NSString* SpellCheckingDidChangeNotification = @"LaTeXiT_SpellCheckingDidChangeNotification";

NSString* GeneralToolbarItemIdentifier     = @"GeneralToolbarItem";
NSString* EditionToolbarItemIdentifier     = @"EditionToolbarItem";
NSString* PreambleToolbarItemIdentifier    = @"PreambleToolbarItem";
NSString* CompositionToolbarItemIdentifier = @"CompositionToolbarItem";
NSString* ServiceToolbarItemIdentifier     = @"ServiceToolbarItem";
NSString* AdvancedToolbarItemIdentifier    = @"AdvancedToolbarItem";
NSString* WebToolbarItemIdentifier         = @"WebToolbarItem";

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

@interface PreferencesController (PrivateAPI)
-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification;
-(void) _updateButtonStates:(NSNotification*)notification;
-(void) tableViewSelectionDidChange:(NSNotification*)notification;
-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode  contextInfo:(void*)contextInfo;
-(void) preamblesDidChange;
@end

@implementation PreferencesController

static PreferencesController* sharedController = nil;
static NSMutableArray*        factoryDefaultsPreambles = nil;

+(PreferencesController*) sharedController
{
  @synchronized(self)
  {
    if (!sharedController)
    {
      sharedController = [[self alloc] init];
      [sharedController window];
    }
  }
  return sharedController;
}
//end sharedController

+(NSDictionary*) defaultAdditionalScript
{
  return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], ScriptEnabledKey,
                                               [NSNumber numberWithInt:SCRIPT_SOURCE_STRING], ScriptSourceTypeKey,
                                               @"/bin/sh", ScriptShellKey,
                                               @"", ScriptBodyKey,
                                               @"", ScriptFileKey,
                                               nil];
}
//end defaultAdditionalScript

+(NSDictionary*) defaultAdditionalScripts
{
  NSDictionary* noScript = [self defaultAdditionalScript];
  return [NSDictionary dictionaryWithObjectsAndKeys:noScript, [NSString stringWithFormat:@"%d",SCRIPT_PLACE_PREPROCESSING],
                                                    noScript, [NSString stringWithFormat:@"%d",SCRIPT_PLACE_MIDDLEPROCESSING],
                                                    noScript, [NSString stringWithFormat:@"%d",SCRIPT_PLACE_POSTPROCESSING],
                                                    nil];
}
//end defaultAdditionalScripts

+(id) currentCompositionConfigurationObjectForKey:(id)key
{
  id result = nil;
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  int compositionConfigurationIndex = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
  NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
  NSDictionary* configuration = [compositionConfigurations objectAtIndex:compositionConfigurationIndex];
  result = [configuration objectForKey:key];
  return result;
}
//end currentCompositionConfigurationObjectForKey:

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
//end currentCompositionConfigurationSetObject:forKey:

+(void) initialize
{
  NSFont* defaultFont = [NSFont fontWithName:@"Monaco" size:12];
  if (!defaultFont)
    defaultFont = [NSFont userFontOfSize:0];
  NSData* defaultFontAsData = [defaultFont data];

  if (!factoryDefaultsPreambles)
    factoryDefaultsPreambles =
      [[NSArray alloc] initWithObjects:
        [PreamblesController encodePreamble:[PreamblesController defaultLocalizedPreambleDictionary]], nil];

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
                                               factoryDefaultsPreambles, PreamblesKey,
                                               defaultFontAsData, DefaultFontKey,
                                               [NSNumber numberWithUnsignedInt:0], LatexisationSelectedPreambleIndexKey,
                                               [NSNumber numberWithUnsignedInt:0], ServiceSelectedPreambleIndexKey,
                                               [NSArray arrayWithObjects:numberYes, numberYes, numberYes, numberYes, numberYes, numberYes, nil], ServiceShortcutEnabledKey,
                                               [NSArray arrayWithObjects:@"", @"", @"", @"", @"", @"", nil], ServiceShortcutStringsKey,
                                               [NSNumber numberWithBool:YES], ServiceRespectsBaselineKey,
                                               [NSNumber numberWithBool:YES], ServiceRespectsPointSizeKey,
                                               [NSNumber numberWithDouble:1.0], ServicePointSizeFactorKey,
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
                                               //[NSNumber numberWithBool:YES], CheckForNewVersionsKey,
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
                                               [NSNumber numberWithBool:YES], ShowWhiteColorWarningKey,
                                               [NSNumber numberWithBool:NO], UseLoginShellKey,
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
  
  //from version 1.15.0, SUCheckAtStartupKey replaces CheckForNewVersionsKey
  //from version 1.15.1, SUEnableAutomaticChecksKey replaces SUCheckAtStartupKey
  if ([userDefaults objectForKey:CheckForNewVersionsKey])
  {
    [[[AppController appController] sparkleUpdater] setAutomaticallyChecksForUpdates:[userDefaults boolForKey:CheckForNewVersionsKey]];
    [userDefaults removeObjectForKey:CheckForNewVersionsKey];
  }
  
  //from version 1.16.0, add the current version number
  NSString* selfVersionNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
  [userDefaults setObject:selfVersionNumber forKey:LaTeXiTVersionKey];
}
//end initialize

-(id) init
{
  if (![super initWithWindowNibName:@"Preferences"])
    return nil;
  sharedController = self;
  toolbarItems = [[NSMutableDictionary alloc] init];
  warningImage = [[NSImage imageNamed:@"warning-triangle"] retain];
  shortcutTextView = [[ServiceShortcutsTextView alloc] initWithFrame:NSMakeRect(0,0,10,10)];
  preambles = [[NSMutableArray alloc] initWithCapacity:1];
  selfController = [[NSObjectController alloc] init];
  [selfController setContent:self];
  preamblesController = [[PreamblesController alloc] init];
  [preamblesController bind:@"contentArray" toObject:self withKeyPath:@"preambles" options:nil];
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [warningImage release];
  [toolbarItems release];
  [exampleSyntaxColouring release];
  [applyPreambleToLibraryAlert release];
  [shortcutTextView release];
  [preamblesController release];
  [preambles release];
  [selfController release];
  [super dealloc];
}
//end dealloc

-(NSMutableArray*) preambles
{
  return preambles;
}
//end preambles

-(NSAttributedString*) preambleForLatexisation
{
  return [latexisationSelectedPreamble objectForKey:@"value"];
}
//end preambleForLatexisation

-(NSAttributedString*) preambleForService
{
  return [serviceSelectedPreamble objectForKey:@"value"];
}
//end preambles

-(NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
  return [NSArray arrayWithObjects:GeneralToolbarItemIdentifier,  EditionToolbarItemIdentifier,
                                   PreambleToolbarItemIdentifier, CompositionToolbarItemIdentifier,
                                   ServiceToolbarItemIdentifier,  AdvancedToolbarItemIdentifier,
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
    else if ([itemIdentifier isEqualToString:PreambleToolbarItemIdentifier])
    {
      imagePath = [[NSBundle mainBundle] pathForResource:@"preambleToolbarItem" ofType:@"tiff"];
      label = NSLocalizedString(@"Preambles", @"Preambles");
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
//end toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:

-(IBAction) toolbarHit:(id)sender
{
  NSView* view = nil;
  NSString* itemIdentifier = [sender itemIdentifier];

  if ([itemIdentifier isEqualToString:GeneralToolbarItemIdentifier])
    view = generalView;
  else if ([itemIdentifier isEqualToString:EditionToolbarItemIdentifier])
    view = editionView;
  else if ([itemIdentifier isEqualToString:PreambleToolbarItemIdentifier])
    view = preamblesView;
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
//end awakeFromNib

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
  NSArray* preamblesEncodedInUserDefaults = [userDefaults arrayForKey:PreamblesKey];
  if (![preamblesEncodedInUserDefaults count])
    preamblesEncodedInUserDefaults = factoryDefaultsPreambles;
  unsigned int i = 0;
  for(i = 0 ; i<[preamblesEncodedInUserDefaults count] ; ++i)
    [preamblesController addObject:[PreamblesController decodePreamble:[preamblesEncodedInUserDefaults objectAtIndex:i]]];
  [preamblesController setSelectionIndex:0];
  [[preamblesTableView tableColumnWithIdentifier:@"name"] bind:@"value" toObject:preamblesController withKeyPath:@"arrangedObjects.name" options:nil];
  [preamblesTableView setDataSource:self];
  [addPreambleButton setAction:@selector(insert:)];
  [addPreambleButton setTarget:preamblesController];
  [addPreambleButton bind:@"enabled" toObject:preamblesController withKeyPath:@"canAdd" options:nil];
  [removePreambleButton setAction:@selector(remove:)];
  [removePreambleButton setTarget:preamblesController];
  [removePreambleButton bind:@"enabled" toObject:preamblesController withKeyPath:@"canRemove" options:nil];  
  [preambleTextView bind:@"attributedString" toObject:preamblesController withKeyPath:@"selection.value" options:nil];
  [latexisationSelectedPreamblePopUpButton bind:@"content" toObject:preamblesController withKeyPath:@"arrangedObjects" options:nil];
  [latexisationSelectedPreamblePopUpButton bind:@"contentValues" toObject:preamblesController withKeyPath:@"arrangedObjects.name" options:nil];
  [latexisationSelectedPreamblePopUpButton bind:@"selectedObject" toObject:selfController withKeyPath:@"content.latexisationSelectedPreamble" options:nil];
  [serviceSelectedPreamblePopUpButton bind:@"content" toObject:preamblesController withKeyPath:@"arrangedObjects" options:nil];
  [serviceSelectedPreamblePopUpButton bind:@"contentValues" toObject:preamblesController withKeyPath:@"arrangedObjects.name" options:nil];
  [serviceSelectedPreamblePopUpButton bind:@"selectedObject" toObject:selfController withKeyPath:@"content.serviceSelectedPreamble" options:nil];
  [self addObserver:self forKeyPath:@"preambles" options:NSKeyValueObservingOptionNew context:NULL];
  [[preambleTextView syntaxColouring] recolourCompleteDocument];
  unsigned int latexisationSelectedPreambleIndex = [[userDefaults objectForKey:LatexisationSelectedPreambleIndexKey] unsignedIntValue];
  [self setLatexisationSelectedPreamble:(latexisationSelectedPreambleIndex < [preambles count]) ?
                                        [preambles objectAtIndex:latexisationSelectedPreambleIndex] :
                                        [preambles count] ? [preambles objectAtIndex:0] : nil];
  unsigned int serviceSelectedPreambleIndex = [[userDefaults objectForKey:ServiceSelectedPreambleIndexKey] unsignedIntValue];
  [self setServiceSelectedPreamble:(serviceSelectedPreambleIndex < [preambles count]) ?
                                     [preambles objectAtIndex:serviceSelectedPreambleIndex] :
                                     [preambles count] ? [preambles objectAtIndex:0] : nil];
  [preamblesTableView selectRow:[preambles indexOfObject:latexisationSelectedPreamble] byExtendingSelection:NO];
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
  [serviceRelaunchWarning setHidden:(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4)]; //Leopard+
    
  
  [additionalTopMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
  [additionalTopMarginTextField setDelegate:self];
  [additionalLeftMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
  [additionalLeftMarginTextField setDelegate:self];
  [additionalRightMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
  [additionalRightMarginTextField setDelegate:self];
  [additionalBottomMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
  [additionalBottomMarginTextField setDelegate:self];
  
  [checkForNewVersionsButton setState:([[[AppController appController] sparkleUpdater] automaticallyChecksForUpdates] ? NSOnState : NSOffState)];
  
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
//end windowDidLoad

-(void) windowWillClose:(NSNotification *)aNotification
{
  //useful for font selection
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if ([fontManager delegate] == self)
    [fontManager setDelegate:nil];
  [[NSUserDefaults standardUserDefaults] synchronize];
}
//end windowWillClose:

//image exporting
-(IBAction) openOptionsForDragExport:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [dragExportJpegQualitySlider setFloatValue:[userDefaults floatForKey:DragExportJpegQualityKey]];
  [dragExportJpegQualityTextField setFloatValue:[dragExportJpegQualitySlider floatValue]];
  [dragExportJpegColorWell setColor:[NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]]];
  [NSApp runModalForWindow:dragExportOptionsPane];
}
//end openOptionsForDragExport:

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
//end closeOptionsPane:

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
//end dragExportPopupFormatDidChange:

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok  = YES;
  if ([sender tag] == EXPORT_FORMAT_EPS)
    ok = [[AppController appController] isGsAvailable];
  else if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[AppController appController] isGsAvailable] && [[AppController appController] isPs2PdfAvailable];
  return ok;
}
//end validateMenuItem:

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
//end changeDefaultGeneralConfig:

//updates the user defaults as the user is typing. Not very efficient, but textDidEndEditing was not working properly
-(void)textDidChange:(NSNotification *)aNotification
{
  if ([aNotification object] == scriptsScriptDefinitionBodyTextView)
    [self changeScriptsConfiguration:scriptsScriptDefinitionBodyTextView];
}
//end textDidChange:

-(IBAction) changeSpellChecking:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == spellCheckingButton)
  {
    [userDefaults setBool:([spellCheckingButton state] == NSOnState) forKey:SpellCheckingEnableKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SpellCheckingDidChangeNotification object:nil];
  }
}
//end changeSpellChecking:

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

-(IBAction) resetSelectedPreambleToDefault:(id)sender
{
  [preamblesController setValue:[[PreamblesController defaultLocalizedPreambleDictionary] valueForKey:@"value"] forKeyPath:@"selection.value"];
  [preambleTextView setNeedsDisplay:YES];
  [self preamblesDidChange];
}
//end resetSelectedPreambleToDefault:

-(IBAction) selectFont:(id)sender
{
  [[self window] makeFirstResponder:nil]; //to remove first responder from the preambleview
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  [fontManager orderFrontFontPanel:self];
  [fontManager setDelegate:self]; //the delegate will be reset in tabView:willSelectTabViewItem: or windowWillClose:
}
//end selectFont:

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
//end changeFont:

-(IBAction) applyPreambleToOpenDocuments:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSArray* documents = [[NSDocumentController sharedDocumentController] documents];
  [documents makeObjectsPerformSelector:@selector(setPreamble:) withObject:[[[self preambleForLatexisation] mutableCopy] autorelease]];
  [documents makeObjectsPerformSelector:@selector(setFont:) withObject:[NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]]];
}
//end applyPreambleToOpenDocuments:

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
                                  withObject:[[[self preambleForLatexisation] mutableCopy] autorelease]];
  }
}
//end applyPreambleToLibrary:

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
//end changeCompositionMode:

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
//end changePath:

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
//end didEndOpenPanel:returnCode:contextInfo:

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
//end controlTextDidChange:

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
//end controlTextDidEndEditing:

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
//end changeServiceConfiguration:

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
//end gotoPreferencePane:

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
//end changeAdditionalMargin:

-(IBAction) newEncapsulation:(id)sender
{
  [[EncapsulationManager sharedManager] newEncapsulation];
  [encapsulationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[encapsulationTableView numberOfRows]-1]
                      byExtendingSelection:NO];
}//end newEncapsulation:

-(IBAction) removeSelectedEncapsulations:(id)sender
{
  [[EncapsulationManager sharedManager] removeEncapsulationIndexes:[encapsulationTableView selectedRowIndexes]];
}
//end removeSelectedEncapsulations:

-(IBAction) newTextShortcut:(id)sender
{
  [[TextShortcutsManager sharedManager] newTextShortcut];
  [textShortcutsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[textShortcutsTableView numberOfRows]-1]
                    byExtendingSelection:NO];
}
//end newTextShortcut:

-(IBAction) removeSelectedTextShortcuts:(id)sender
{
  [[TextShortcutsManager sharedManager] removeTextShortcutsIndexes:[textShortcutsTableView selectedRowIndexes]];
}
//end removeSelectedTextShortcuts:

-(IBAction) newCompositionConfiguration:(id)sender
{
  [[CompositionConfigurationManager sharedManager] newCompositionConfiguration];
  [compositionConfigurationTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[compositionConfigurationTableView numberOfRows]-1]
                      byExtendingSelection:NO];
}
//end newCompositionConfiguration:

-(IBAction) removeSelectedCompositionConfigurations:(id)sender
{
  [[CompositionConfigurationManager sharedManager] removeCompositionConfigurationIndexes:[compositionConfigurationTableView selectedRowIndexes]];
}
//end removeSelectedCompositionConfigurations:

-(IBAction) checkForUpdatesChange:(id)sender
{
  [[[AppController appController] sparkleUpdater] setAutomaticallyChecksForUpdates:([sender state] == NSOnState)];
}
//end checkForUpdatesChange:

-(IBAction) checkNow:(id)sender
{
  [[AppController appController] checkUpdates:self];
}
//end checkNow:

-(IBAction) gotoWebSite:(id)sender
{
  [[AppController appController] openWebSite:self];
}
//end gotoWebSite:

-(void) selectPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier
{
  [[[self window] toolbar] setSelectedItemIdentifier:itemIdentifier];
  [self toolbarHit:[toolbarItems objectForKey:itemIdentifier]];
}
//end selectPreferencesPaneWithItemIdentifier:

-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification
{
  //the MarginController may change the margins defaults, so this notification is useful for synchronizing
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [additionalTopMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
  [additionalLeftMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
  [additionalRightMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
  [additionalBottomMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
}
//end _userDefaultsDidChangeNotification:

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
//end _updateButtonStates:

//useful to avoid some bad connections in Interface builder
-(IBAction) nullAction:(id)sender
{
}
//end nullAction:

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
//end numberOfRowsInTableView:

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
      unsigned int index = 0;
      NSMutableArray* serviceMenuItems = [NSMutableArray arrayWithArray:[[NSApp servicesMenu] itemArray]];
      NSMutableArray* alreadyUsedServiceShortcuts = [NSMutableArray array];
      while(index < [serviceMenuItems count])
      {
        id object = [serviceMenuItems objectAtIndex:index];
        if ([object isKindOfClass:[NSMenu class]])
        {
          [serviceMenuItems addObjectsFromArray:[object itemArray]];
          [serviceMenuItems removeObjectAtIndex:index];
        }
        else if ([object isKindOfClass:[NSMenuItem class]])
        {
          if ([object hasSubmenu] && ![[object title] isEqualToString:@"LaTeXiT"])
          {
            [serviceMenuItems addObjectsFromArray:[[object submenu] itemArray]];
            [serviceMenuItems removeObjectAtIndex:index];
          }
          else
          {
            NSString* lowerCaseShortcut = [[object keyEquivalent] lowercaseString];
            if (![lowerCaseShortcut isEqualToString:@""])
              [alreadyUsedServiceShortcuts addObject:lowerCaseShortcut];
            ++index;
          }
        }
        else
          [serviceMenuItems removeObjectAtIndex:index];
      }//end for each service
      
      const unichar shift = 0x21e7;
      const unichar command = 0x2318;
      const unichar shortcutMaskCharacters[] = {shift, command};
      NSCharacterSet* shortcutMaskCharacterSet =
        [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithCharacters:shortcutMaskCharacters
                                                                                   length:sizeof(shortcutMaskCharacters)]];
      NSString* trimmedCurrentShortcut = [currentShortcut stringByTrimmingCharactersInSet:shortcutMaskCharacterSet];
      conflict |= [currentEnabled boolValue] && currentShortcut && ![currentShortcut isEqualToString:@""] &&
                  ![trimmedCurrentShortcut isEqualToString:@""] &&
                  [alreadyUsedServiceShortcuts containsObject:[trimmedCurrentShortcut lowercaseString]];
      int i = 0;
      for(i = 0 ; [currentEnabled boolValue] && !conflict && i<[aTableView numberOfRows] ; ++i)
      {
         NSNumber* enabled =  [[aTableView delegate] tableView:aTableView objectValueForTableColumn:enabledColumn row:i];
         NSString* shortcut = [[aTableView delegate] tableView:aTableView objectValueForTableColumn:shortcutColumn row:i];
         conflict |= (i != rowIndex) && [enabled boolValue] && currentShortcut && ![currentShortcut isEqualToString:@""] &&
                                        [currentShortcut isEqualToString:shortcut];
      }//end for each defined shortcut

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
//end tableView:objectValueForTableColumn:row:

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
      [[AppController appController]
        changeServiceShortcutsWithDiscrepancyFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS
                               authenticationFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK];
    }
    else if ([identifier isEqualToString:@"shortcut"])
    {
      NSMutableArray* shorcutStrings = [NSMutableArray arrayWithArray:[userDefaults objectForKey:ServiceShortcutStringsKey]];
      NSString* valueToStore = ((value != nil) && ![value isEqualToString:@""])
                                 ? [value substringWithRange:NSMakeRange([value length]-1, 1)] : @"";
      [shorcutStrings replaceObjectAtIndex:index withObject:valueToStore];
      [userDefaults setObject:shorcutStrings forKey:ServiceShortcutStringsKey];
      [[AppController appController]
        changeServiceShortcutsWithDiscrepancyFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS
                               authenticationFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK];
    }
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
//end tableView:setObjectValue:forTableColumn:row:

-(void) tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  if (aTableView ==  serviceShortcutsTableView)
  {
    NSString* identifier = [aTableColumn identifier];
    if ([identifier isEqualToString:@"shortcut"])
      [aCell setPlaceholderString:NSLocalizedString(@"none", @"none")];
  }
}
//end tableView:willDisplayCell:forTableColumn:row:

-(id) windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject
{
  return (anObject == serviceShortcutsTableView) ? shortcutTextView : nil;
}
//end windowWillReturnFieldEditor:toObject:

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
//end changeScriptsConfiguration:

-(void) tableViewSelectionDidChange:(NSNotification*)notification
{
  if ([notification object] == scriptsTableView)
    [self changeScriptsConfiguration:scriptsTableView];
}
//end tableViewSelectionDidChange:

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
//end selectScript:

-(IBAction) showScriptHelp:(id)sender
{
  if (![scriptsHelpPanel isVisible])
  {
    [scriptsHelpPanel center];
    [scriptsHelpPanel makeKeyAndOrderFront:sender];
  }
}
//end showScriptHelp:

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
//end changeCompositionSelection:

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
//end closeCompositionSelectionPanel:

-(void)sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [compositionSelectionPopUpButton selectItemWithTag:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
  [sheet orderOut:self];
}
//end sheetDidEnd:returnCode:contextInfo:

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void *)context
{
  if ([keyPath isEqualToString:@"preambles"])
    [self preamblesDidChange];
}
//end observeValueForKeyPath:ofObject:change:context:

-(NSDictionary*) serviceSelectedPreamble {return serviceSelectedPreamble;}
-(void) setServiceSelectedPreamble:(NSDictionary*)preamble {[serviceSelectedPreamble autorelease]; serviceSelectedPreamble = [preamble retain];}
-(NSDictionary*) latexisationSelectedPreamble {return latexisationSelectedPreamble;}
-(void) setLatexisationSelectedPreamble:(NSDictionary*)preamble
{
  if (preamble != latexisationSelectedPreamble)
  {
    [latexisationSelectedPreamble release];
    latexisationSelectedPreamble = [preamble retain];
    [preamblesTableView selectRow:[preambles indexOfObject:latexisationSelectedPreamble] byExtendingSelection:NO];
  }
}
//end setLatexisationSelectedPreamble:

-(void) commitChanges
{
  [self preamblesDidChange];
}
//end commitChanges

-(void) checkSelectedPreamble:(NSDictionary**)pPreamble
{
  if (pPreamble)
  {
    NSDictionary* preamble = *pPreamble;
    if (preamble && ![preambles containsObject:preamble])
    {
      [preamble release];
      preamble = nil;
    }
    if (!preamble && [preambles count])
      preamble = [[preambles objectAtIndex:0] retain];
    *pPreamble = preamble;
  }
}
//end checkSelectedPreamble:

-(void) preamblesDidChange
{
  [self checkSelectedPreamble:&latexisationSelectedPreamble];
  [self checkSelectedPreamble:&serviceSelectedPreamble];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setObject:[NSNumber numberWithUnsignedInt:[preambles indexOfObject:latexisationSelectedPreamble]] forKey:LatexisationSelectedPreambleIndexKey];
  [userDefaults setObject:[NSNumber numberWithUnsignedInt:[preambles indexOfObject:serviceSelectedPreamble]] forKey:ServiceSelectedPreambleIndexKey];
  NSMutableArray* encodedPreambles = [NSMutableArray arrayWithCapacity:[preambles count]];
  NSEnumerator* enumerator = [preambles objectEnumerator];
  NSDictionary* preamble = nil;
  while((preamble = [enumerator nextObject]))
    [encodedPreambles addObject:[PreamblesController encodePreamble:preamble]];
  [userDefaults setObject:encodedPreambles forKey:PreamblesKey];
}
//end preamblesDidChange

//drag'n drop for moving rows

-(NSIndexSet*) _draggedRowIndexes //utility method to access draggedItems when working with pasteboard sender
{
  return draggedRowIndexes;
}
//end _draggedRowIndexes

//this one is deprecated in OS 10.4, calls writeRowsWithIndexes
-(BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
  NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
  NSEnumerator* enumerator = [rows objectEnumerator];
  NSNumber* row = [enumerator nextObject];
  while(row)
  {
    [indexSet addIndex:[row unsignedIntValue]];
    row = [enumerator nextObject];
  }
  return [self tableView:tableView writeRowsWithIndexes:indexSet toPasteboard:pboard];
}
//end tableView:writeRows:toPasteboard:

//this one is for OS 10.4
-(BOOL) tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
  //we put the moving rows in pasteboard
  draggedRowIndexes = rowIndexes;
  [pboard declareTypes:[NSArray arrayWithObject:PreamblesPboardType] owner:self];
  [pboard setPropertyList:[NSKeyedArchiver archivedDataWithRootObject:preambles] forType:PreamblesPboardType];
  return YES;
}
//end tableView:writeRowsWithIndexes:toPasteboard:

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  //we only accept moving inside the table (not between different ones)
  NSPasteboard* pboard = [info draggingPasteboard];
  NSIndexSet* indexSet =  [[[info draggingSource] dataSource] _draggedRowIndexes];
  BOOL ok = (tableView == [info draggingSource]) && pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:PreamblesPboardType]] &&
            [pboard propertyListForType:PreamblesPboardType] &&
            (operation == NSTableViewDropAbove) &&
            indexSet && ([indexSet firstIndex] != (unsigned int)row) && ([indexSet firstIndex]+1 != (unsigned int)row);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  [preamblesController willChangeValueForKey:@"arrangedOjects"];
  NSIndexSet* indexSet = [[[info draggingSource] dataSource] _draggedRowIndexes];
  [preambles moveObjectsAtIndices:indexSet toIndex:row];
  [preamblesController didChangeValueForKey:@"arrangedOjects"];
  [tableView setNeedsDisplay:YES];
  return YES;
}
//end tableView:acceptDrop:row:dropOperation:

@end
