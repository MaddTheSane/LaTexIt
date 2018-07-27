//  PreferencesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import "PreferencesController.h"

#import "AppController.h"
#import "EncapsulationManager.h"
#import "EncapsulationTableView.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSSegmentedControlExtended.h"
#import "LibraryManager.h"
#import "LineCountTextView.h"
#import "MyDocument.h"

NSString* DragExportTypeKey            = @"LaTeXiT_DragExportTypeKey";
NSString* DragExportJpegColorKey       = @"LaTeXiT_DragExportJpegColorKey";
NSString* DragExportJpegQualityKey     = @"LaTeXiT_DragExportJpegQualityKey";
NSString* DefaultImageViewBackground   = @"LaTeXiT_DefaultImageViewBackground";
NSString* DefaultColorKey              = @"LaTeXiT_DefaultColorKey";
NSString* DefaultPointSizeKey          = @"LaTeXiT_DefaultPointSizeKey";
NSString* DefaultModeKey               = @"LaTeXiT_DefaultModeKey";
NSString* DefaultPreambleAttributedKey = @"LaTeXiT_DefaultPreambleAttributedKey";
NSString* DefaultFontKey               = @"LaTeXiT_DefaultFontKey";
NSString* CompositionModeKey           = @"LaTeXiT_CompositionModeKey";
NSString* PdfLatexPathKey              = @"LaTeXiT_PdfLatexPathKey";
NSString* XeLatexPathKey               = @"LaTeXiT_XeLatexPathKey";
NSString* LatexPathKey                 = @"LaTeXiT_LatexPathKey";
NSString* DvipdfPathKey                = @"LaTeXiT_DvipdfPathKey";
NSString* GsPathKey                    = @"LaTeXiT_GsPathKey";
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
NSString* LastEasterEggsDatesKey       = @"LaTeXiT_LastEasterEggsDatesKey";

NSString* EncapsulationControllerVisibleAtStartupKey = @"EncapsulationControllerVisibleAtStartupKey";
NSString* HistoryControllerVisibleAtStartupKey = @"HistoryControllerVisibleAtStartupKey";
NSString* LatexPalettesControllerVisibleAtStartupKey = @"LatexPalettesControllerVisibleAtStartupKey";
NSString* LibraryControllerVisibleAtStartupKey = @"LibraryControllerVisibleAtStartupKey";
NSString* MarginControllerVisibleAtStartupKey = @"MarginControllerVisibleAtStartupKey";

NSString* CheckForNewVersionsKey       = @"LaTeXiT_CheckForNewVersionsKey";

NSString* SomePathDidChangeNotification = @"SomePathDidChangeNotification"; //changing the path to an executable (like pdflatex)
NSString* CompositionModeDidChangeNotification = @"CompositionModeDidChangeNotification";

@interface PreferencesController (PrivateAPI)
-(void) _userDefaultsDidChangeNotification:(NSNotification*)notification;
-(void) _updateButtonStates:(NSNotification*)notification;
@end

@implementation PreferencesController

static NSAttributedString* factoryDefaultPreamble = nil;

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

  NSDictionary* defaults =
    [NSDictionary dictionaryWithObjectsAndKeys:@"PDF",                           DragExportTypeKey,
                                               [[NSColor whiteColor] data],      DragExportJpegColorKey,
                                               [NSNumber numberWithFloat:100],   DragExportJpegQualityKey,
                                               [[NSColor whiteColor] data],      DefaultImageViewBackground,
                                               [[NSColor  blackColor]   data],   DefaultColorKey,
                                               [NSNumber numberWithDouble:36.0], DefaultPointSizeKey,
                                               [NSNumber numberWithInt:DISPLAY], DefaultModeKey,
                                               [NSNumber numberWithInt:0], CompositionModeKey,
                                               @"", PdfLatexPathKey,
                                               @"", XeLatexPathKey,
                                               @"", LatexPathKey,
                                               @"", DvipdfPathKey,
                                               @"", GsPathKey,
                                               factoryDefaultPreambleData, DefaultPreambleAttributedKey,
                                               defaultFontAsData, DefaultFontKey,
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
                                               [NSNumber numberWithBool:YES], CheckForNewVersionsKey,
                                               [NSNumber numberWithBool:NO], EncapsulationControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], HistoryControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], LatexPalettesControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], LibraryControllerVisibleAtStartupKey,
                                               [NSNumber numberWithBool:NO], MarginControllerVisibleAtStartupKey,
                                               nil];

  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

-(id) init
{
  if (![super initWithWindowNibName:@"Preferences"])
    return nil;
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

//initializes the controls with default values
-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"preferences"];

  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  [dragExportPopupFormat selectItemWithTitle:[userDefaults stringForKey:DragExportTypeKey]];
  [self dragExportPopupFormatDidChange:dragExportPopupFormat];

  [defaultImageViewBackgroundColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:DefaultImageViewBackground]]];
  
  [[defaultModeSegmentedControl cell] setTag:DISPLAY forSegment:0];
  [[defaultModeSegmentedControl cell] setTag:INLINE  forSegment:1];
  [[defaultModeSegmentedControl cell] setTag:TEXT  forSegment:2];
  [defaultModeSegmentedControl selectSegmentWithTag:[userDefaults integerForKey:DefaultModeKey]];
  [defaultPointSizeTextField setDoubleValue:[userDefaults floatForKey:DefaultPointSizeKey]];
  [defaultColorColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:DefaultColorKey]]];

  //[preambleTextView setDelegate:self];//No ! preambleTextView's delegate is itself to manage forbidden lines
  //[preambleTextView setForbiddenLine:0 forbidden:YES];//finally, the user is allowed to modify
  //[preambleTextView setForbiddenLine:1 forbidden:YES];//finally, the user is allowed to modify
  NSData* attributedStringData = [userDefaults objectForKey:DefaultPreambleAttributedKey];
  NSAttributedString* attributedString = [[[NSAttributedString alloc] initWithRTF:attributedStringData documentAttributes:NULL] autorelease];
  [[preambleTextView textStorage] setAttributedString:attributedString];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];

  [self changeFont:self];//updates font textfield
  
  [compositionMatrix selectCellWithTag:[userDefaults integerForKey:CompositionModeKey]];
  
  [pdfLatexTextField        setStringValue:[userDefaults stringForKey:PdfLatexPathKey]];
  [pdfLatexTextField        setDelegate:self];
  [xeLatexTextField         setStringValue:[userDefaults stringForKey:XeLatexPathKey]];
  [xeLatexTextField         setDelegate:self];
  [latexTextField           setStringValue:[userDefaults stringForKey:LatexPathKey]];
  [latexTextField           setDelegate:self];
  [dvipdfTextField          setStringValue:[userDefaults stringForKey:DvipdfPathKey]];
  [dvipdfTextField          setDelegate:self];
  [gsTextField              setStringValue:[userDefaults stringForKey:GsPathKey]];
  [gsTextField              setDelegate:self];
  [self changeCompositionMode:compositionMatrix];//to update enable state of the buttons just above (here in the code)
  
  [serviceRespectsPointSizeMatrix selectCellWithTag:([userDefaults boolForKey:ServiceRespectsPointSizeKey] ? 1 : 0)];
  [serviceRespectsColorMatrix     selectCellWithTag:([userDefaults boolForKey:ServiceRespectsColorKey]     ? 1 : 0)];
  [serviceRespectsBaselineButton  setState:([userDefaults boolForKey:ServiceRespectsBaselineKey]  ? NSOnState : NSOffState)];
  [serviceUsesHistoryButton       setState:([userDefaults boolForKey:ServiceUsesHistoryKey]  ? NSOnState : NSOffState)];
  
  [additionalTopMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
  [additionalTopMarginTextField setDelegate:self];
  [additionalLeftMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
  [additionalLeftMarginTextField setDelegate:self];
  [additionalRightMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
  [additionalRightMarginTextField setDelegate:self];
  [additionalBottomMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
  [additionalBottomMarginTextField setDelegate:self];
  
  [checkForNewVersionsButton setState:([userDefaults boolForKey:CheckForNewVersionsKey] ? NSOnState : NSOffState)];
    
  [self tabView:preferencesTabView willSelectTabViewItem:[preferencesTabView selectedTabViewItem]];
  
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(textDidChange:)
                             name:NSTextDidChangeNotification object:preambleTextView];
  [notificationCenter addObserver:self selector:@selector(textDidChange:)
                             name:FontDidChangeNotification object:preambleTextView];
  [notificationCenter addObserver:self selector:@selector(_userDefaultsDidChangeNotification:)
                             name:NSUserDefaultsDidChangeNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(_updateButtonStates:)
                             name:NSTableViewSelectionDidChangeNotification object:encapsulationTableView];
}

//allows resizing only for preamble tab
-(void) tabView:(NSTabView*)tabView willSelectTabViewItem:(NSTabViewItem*)item
{
  NSWindow* window = [self window];
  if (tabView && [tabView indexOfTabViewItem:item] == 1)
  {
    [window setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [window setShowsResizeIndicator:YES];
  }
  else
  {
    NSSize minSize = [window minSize];
    [window setMaxSize:minSize];
    NSRect frame = [window frame];
    frame.origin.y += frame.size.height-minSize.height;
    frame.size = minSize;
    [window setShowsResizeIndicator:NO];
    [window setFrame:frame display:YES animate:YES];
  }
  
  //useful for font selection
  [window makeFirstResponder:nil];
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if ([fontManager delegate] == self)
    [fontManager setDelegate:nil];
}

-(void) windowWillClose:(NSNotification *)aNotification
{
  //useful for font selection
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  if ([fontManager delegate] == self)
    [fontManager setDelegate:nil];
}

//image exporting
-(IBAction) openOptions:(id)sender
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
  NSString* titleOfSelectedItem = [sender titleOfSelectedItem];
  NSString* format = [titleOfSelectedItem lowercaseString];
  NSArray* components = [format componentsSeparatedByString:@" "];
  format = [components count] ? [components objectAtIndex:0] : @"";
  if ([format isEqualToString:@"jpeg"])
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
  
  [[NSUserDefaults standardUserDefaults] setObject:titleOfSelectedItem forKey:DragExportTypeKey];
}

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok  = YES;
  if ([[sender title] isEqualToString:@"EPS"])
    ok = [[AppController appController] isGsAvailable];
  return ok;
}

//handles default color, point size, and mode
-(IBAction) changeDefaultGeneralConfig:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == defaultImageViewBackgroundColorWell)
    [userDefaults setObject:[[defaultImageViewBackgroundColorWell color] data] forKey:DefaultImageViewBackground];
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
  //only seen for object preambleTextView
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSAttributedString* attributedString = [preambleTextView textStorage];
  [userDefaults setObject:[attributedString RTFFromRange:NSMakeRange(0, [attributedString length]) documentAttributes:nil]
                   forKey:DefaultPreambleAttributedKey];
}

-(IBAction) resetDefaultPreamble:(id)sender
{
  [[preambleTextView textStorage] setAttributedString:factoryDefaultPreamble];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];
  [preambleTextView setNeedsDisplay:YES];
}

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
  //if sender is nil or self, this "changeFont:" only updates fontTextField, but should not modify preambleTextView
  if (sender && (sender != self))
  {
    NSMutableAttributedString* preamble = [preambleTextView textStorage];
    [preamble addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, [preamble length])];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];
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
  NSArray* historyItems = [[LibraryManager sharedManager] allValues];
  [historyItems makeObjectsPerformSelector:@selector(setPreamble:) withObject:[[[preambleTextView textStorage] mutableCopy] autorelease]];
}

-(IBAction) changeCompositionMode:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == compositionMatrix)
  {
    composition_mode_t mode = (composition_mode_t) [[sender selectedCell] tag];
    [pdfLatexTextField setEnabled:(mode == PDFLATEX)];
    [pdfLatexButton    setEnabled:(mode == PDFLATEX)];
    [xeLatexTextField  setEnabled:(mode == XELATEX)];
    [xeLatexButton     setEnabled:(mode == XELATEX)];
    [latexTextField    setEnabled:(mode == LATEXDVIPDF)];
    [latexButton       setEnabled:(mode == LATEXDVIPDF)];
    [dvipdfTextField   setEnabled:(mode == LATEXDVIPDF)];
    [dvipdfButton      setEnabled:(mode == LATEXDVIPDF)];
    [userDefaults setInteger:(int)mode forKey:CompositionModeKey];
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
    default: break;
  }
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setResolvesAliases:NO];
  [openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self
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
}

-(void) controlTextDidEndEditing:(NSNotification*)aNotification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSTextField* textField = [aNotification object];
  BOOL isDirectory = NO;
  BOOL fileSeemsOk = [[NSFileManager defaultManager] fileExistsAtPath:[textField stringValue] isDirectory:&isDirectory] &&
                     !isDirectory;
  [textField setTextColor:(fileSeemsOk ? [NSColor blackColor] : [NSColor redColor])];
  if (textField == pdfLatexTextField)
  {
    if (didChangePdfLatexTextField)
    {
      [userDefaults setObject:[textField stringValue] forKey:PdfLatexPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangePdfLatexTextField = NO;
  }
  else if (textField == xeLatexTextField)
  {
    if (didChangeXeLatexTextField)
    {
      [userDefaults setObject:[textField stringValue] forKey:XeLatexPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangeXeLatexTextField = NO;
  }
  else if (textField == latexTextField)
  {
    if (didChangeLatexTextField)
    {
      [userDefaults setObject:[textField stringValue] forKey:LatexPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangeLatexTextField = NO;
  }
  else if (textField == dvipdfTextField)
  {
    if (didChangeDvipdfTextField)
    {
      [userDefaults setObject:[textField stringValue] forKey:DvipdfPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangeDvipdfTextField = NO;
  }
  else if (textField == gsTextField)
  {
    if (didChangeGsTextField)
    {
      [userDefaults setObject:[textField stringValue] forKey:GsPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
      
      //export to EPS needs ghostscript to be available
      NSString* exportType = [userDefaults stringForKey:DragExportTypeKey];
      if ([exportType isEqualToString:@"EPS"] && ![[AppController appController] isGsAvailable])
      {
        [userDefaults setObject:@"PDF" forKey:DragExportTypeKey];
        [dragExportPopupFormat selectItemWithTitle:[userDefaults stringForKey:DragExportTypeKey]];
        [self dragExportPopupFormatDidChange:dragExportPopupFormat];
      }
    }
    didChangeGsTextField = NO;
  }
  else if (textField == additionalTopMarginTextField)
    [userDefaults setFloat:[additionalTopMarginTextField floatValue] forKey:AdditionalTopMarginKey];
  else if (textField == additionalLeftMarginTextField)
    [userDefaults setFloat:[additionalLeftMarginTextField floatValue] forKey:AdditionalLeftMarginKey];
  else if (textField == additionalRightMarginTextField)
    [userDefaults setFloat:[additionalRightMarginTextField floatValue] forKey:AdditionalRightMarginKey];
  else if (textField == additionalBottomMarginTextField)
    [userDefaults setFloat:[additionalBottomMarginTextField floatValue] forKey:AdditionalBottomMarginKey];
}

-(IBAction) changeServiceConfiguration:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == serviceRespectsPointSizeMatrix)
    [userDefaults setBool:([[serviceRespectsPointSizeMatrix selectedCell] tag] == 1) forKey:ServiceRespectsPointSizeKey];
  else if (sender == serviceRespectsColorMatrix)
    [userDefaults setBool:([[serviceRespectsColorMatrix selectedCell] tag] == 1) forKey:ServiceRespectsColorKey];
  else if (sender == serviceRespectsBaselineButton)
    [userDefaults setBool:([serviceRespectsBaselineButton state] == NSOnState) forKey:ServiceRespectsBaselineKey];
  else if (sender == serviceUsesHistoryButton)
    [userDefaults setBool:([serviceUsesHistoryButton state] == NSOnState) forKey:ServiceUsesHistoryKey];
}

-(IBAction) changeAdvancedConfiguration:(id)sender
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
  //[encapsulationTableView edit:self];
}

-(IBAction) removeSelectedEncapsulations:(id)sender
{
  [[EncapsulationManager sharedManager] removeEncapsulationIndexes:[encapsulationTableView selectedRowIndexes]];
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

-(void) selectPreferencesPaneWithIdentifier:(id)identifier
{
  [preferencesTabView selectTabViewItemWithIdentifier:identifier];
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
  //only registered for encapsulationTableView
  [removeEncapsulationButton setEnabled:([encapsulationTableView selectedRow] >= 0)];
}

@end
