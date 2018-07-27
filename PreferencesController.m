//  PreferencesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/04/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The preferences controller centralizes the management of the preferences pane

#import "PreferencesController.h"

#import "AppController.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSSegmentedControlExtended.h"
#import "LineCountTextView.h"
#import "MyDocument.h"

NSString* DragExportTypeKey            = @"LaTeXiT_DragExportTypeKey";
NSString* DragExportJpegColorKey       = @"LaTeXiT_DragExportJpegColorKey";
NSString* DragExportJpegQualityKey     = @"LaTeXiT_DragExportJpegQualityKey";
NSString* DefaultColorKey              = @"LaTeXiT_DefaultColorKey";
NSString* DefaultPointSizeKey          = @"LaTeXiT_DefaultPointSizeKey";
NSString* DefaultModeKey               = @"LaTeXiT_DefaultModeKey";
NSString* DefaultPreambleAttributedKey = @"LaTeXiT_DefaultPreambleAttributedKey";
NSString* DefaultFontKey               = @"LaTeXiT_DefaultFontKey";
NSString* PdfLatexPathKey              = @"LaTeXiT_PdfLatexPathKey";
NSString* GsPathKey                    = @"LaTeXiT_GsPathKey";
NSString* ServiceRespectsColorKey      = @"LaTeXiT_ServiceRespectsColorKey";
NSString* ServiceRespectsBaselineKey   = @"LaTeXiT_ServiceRespectsBaselineKey";
NSString* ServiceRespectsPointSizeKey  = @"LaTeXiT_ServiceRespectsPointSizeKey";
NSString* AdditionalTopMarginKey       = @"LaTeXiT_AdditionalTopMarginKey";
NSString* AdditionalLeftMarginKey      = @"LaTeXiT_AdditionalLeftMarginKey";
NSString* AdditionalRightMarginKey     = @"LaTeXiT_AdditionalRightMarginKey";
NSString* AdditionalBottomMarginKey    = @"LaTeXiT_AdditionalBottomMarginKey";
NSString* AdvancedLibraryExportTypeKey              = @"LaTeXiT_AdvancedLibraryExportTypeKey";
NSString* AdvancedLibraryExportUseEncapsulationKey  = @"LaTeXiT_AdvancedLibraryExportUseEncapsulationKey";
NSString* AdvancedLibraryExportEncapsulationTextKey = @"LaTeXiT_AdvancedLibraryExportEncapsulationTextKey";

NSString* SomePathDidChangeNotification = @"SomePathDidChangeNotification"; //changing the path to an executable (like pdflatex)

@implementation PreferencesController

static NSAttributedString* factoryDefaultPreamble = nil;

+(void) initialize
{
  if (!factoryDefaultPreamble)
  {
    NSString* factoryDefaultPreambleString = [NSString stringWithFormat:
      @"\\documentclass[10pt]{article}\n"\
      @"\\usepackage[pdftex]{color} %%%@\n"\
      @"\\usepackage{amssymb} %%maths\n"\
      @"\\usepackage{amsmath} %%maths\n"\
      @"\\usepackage[utf8]{inputenc} %%%@\n",
      NSLocalizedString(@"used for font color", @"used for font color"),
      NSLocalizedString(@"useful to type directly accentuated characters",
                        @"useful to type directly accentuated characters")];
    factoryDefaultPreamble = [[NSAttributedString alloc] initWithString:factoryDefaultPreambleString];
    NSData* factoryDefaultPreambleData =
      [factoryDefaultPreamble RTFFromRange:NSMakeRange(0, [factoryDefaultPreamble length]) documentAttributes:nil];

    NSData* defaultFont = [[NSFont userFontOfSize:0] data];

    NSDictionary* defaults =
      [NSDictionary dictionaryWithObjectsAndKeys:@"PDF", DragExportTypeKey,
                                                 [[NSColor whiteColor] data],      DragExportJpegColorKey,
                                                 [NSNumber numberWithFloat:100],   DragExportJpegQualityKey,
                                                 [[NSColor  blackColor]   data],   DefaultColorKey,
                                                 [NSNumber numberWithDouble:36.0], DefaultPointSizeKey,
                                                 [NSNumber numberWithInt:DISPLAY], DefaultModeKey,
                                                 @"", PdfLatexPathKey,
                                                 @"", GsPathKey,
                                                 factoryDefaultPreambleData, DefaultPreambleAttributedKey,
                                                 defaultFont, DefaultFontKey,
                                                 [NSNumber numberWithBool:YES], ServiceRespectsColorKey,
                                                 [NSNumber numberWithBool:YES], ServiceRespectsBaselineKey,
                                                 [NSNumber numberWithBool:YES], ServiceRespectsPointSizeKey,
                                                 [NSNumber numberWithFloat:0], AdditionalTopMarginKey,
                                                 [NSNumber numberWithFloat:0], AdditionalLeftMarginKey,
                                                 [NSNumber numberWithFloat:0], AdditionalRightMarginKey,
                                                 [NSNumber numberWithFloat:0], AdditionalBottomMarginKey,
                                                 [NSNumber numberWithInt:1]   , AdvancedLibraryExportTypeKey,
                                                 [NSNumber numberWithBool:YES], AdvancedLibraryExportUseEncapsulationKey,
                                                 @"\\ref{@}"                  , AdvancedLibraryExportEncapsulationTextKey,
                                                 nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  }  
}

-(id) init
{
  self = [super initWithWindowNibName:@"Preferences"];
  if (self)
  {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(textDidChange:)
                                                 name:NSTextDidChangeNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(textDidChange:)
                                                 name:FontDidChangeNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification object:nil];
  }
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
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  [dragExportPopupFormat selectItemWithTitle:[userDefaults stringForKey:DragExportTypeKey]];
  [self dragExportPopupFormatDidChange:dragExportPopupFormat];
  
  [[defaultModeSegmentedControl cell] setTag:DISPLAY forSegment:0];
  [[defaultModeSegmentedControl cell] setTag:INLINE  forSegment:1];
  [[defaultModeSegmentedControl cell] setTag:NORMAL  forSegment:2];
  [defaultModeSegmentedControl selectSegmentWithTag:[userDefaults integerForKey:DefaultModeKey]];
  [defaultPointSizeTextField setDoubleValue:[userDefaults floatForKey:DefaultPointSizeKey]];
  [defaultColorColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:DefaultColorKey]]];

  //[preambleTextView setDelegate:self];//No ! preambleTextView's delegate is itself to manage forbidden lines
  [preambleTextView setForbiddenLine:0 forbidden:YES];
  [preambleTextView setForbiddenLine:1 forbidden:YES];
  NSData* attributedStringData = [userDefaults objectForKey:DefaultPreambleAttributedKey];
  NSAttributedString* attributedString = [[[NSAttributedString alloc] initWithRTF:attributedStringData documentAttributes:NULL] autorelease];
  [[preambleTextView layoutManager] replaceTextStorage:[[[NSTextStorage alloc] initWithAttributedString:attributedString] autorelease]];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];

  [self changeFont:self];//updates font textfield
  
  [pdfLatexTextField        setStringValue:[userDefaults stringForKey:PdfLatexPathKey]];
  [pdfLatexTextField        setDelegate:self];
  [gsTextField              setStringValue:[userDefaults stringForKey:GsPathKey]];
  [gsTextField              setDelegate:self];
  [serviceRespectsColor     setState:[userDefaults boolForKey:ServiceRespectsColorKey]  ? NSOnState : NSOffState];
  [serviceRespectsBaseline  setState:[userDefaults boolForKey:ServiceRespectsBaselineKey]  ? NSOnState : NSOffState];
  [serviceRespectsPointSize setState:[userDefaults boolForKey:ServiceRespectsPointSizeKey] ? NSOnState : NSOffState];
  
  [additionalTopMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalTopMarginKey]];
  [additionalTopMarginTextField setDelegate:self];
  [additionalLeftMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalLeftMarginKey]];
  [additionalLeftMarginTextField setDelegate:self];
  [additionalRightMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalRightMarginKey]];
  [additionalRightMarginTextField setDelegate:self];
  [additionalBottomMarginTextField setFloatValue:[userDefaults floatForKey:AdditionalBottomMarginKey]];
  [additionalBottomMarginTextField setDelegate:self];
  
  [advancedLibraryStringExportMatrix    selectCellWithTag:[userDefaults integerForKey:AdvancedLibraryExportTypeKey]];
  [advancedLibraryStringExportCheckBox  setState:([userDefaults boolForKey:AdvancedLibraryExportUseEncapsulationKey] ? NSOnState : NSOffState)];
  [advancedLibraryStringExportTextField setStringValue:[userDefaults objectForKey:AdvancedLibraryExportEncapsulationTextKey]];
  [advancedLibraryStringExportTextField setDelegate:self];
  
  [self tabView:preferencesTabView willSelectTabViewItem:[preferencesTabView selectedTabViewItem]];
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
  NSWindow* window = [aNotification object];
  if (window == [self window])
  {
    //useful for font selection
    NSFontManager* fontManager = [NSFontManager sharedFontManager];
    if ([fontManager delegate] == self)
      [fontManager setDelegate:nil];
  }
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
  if (sender == defaultColorColorWell)
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
  id sender = [aNotification object];
  if (sender == preambleTextView)
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSAttributedString* attributedString = [preambleTextView textStorage];
    [userDefaults setObject:[attributedString RTFFromRange:NSMakeRange(0, [attributedString length]) documentAttributes:nil]
                     forKey:DefaultPreambleAttributedKey];
  }
}

-(IBAction) resetDefaultPreamble:(id)sender
{
  [[preambleTextView layoutManager] replaceTextStorage:[[[NSTextStorage alloc] initWithAttributedString:factoryDefaultPreamble] autorelease]];
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

//opens a panel to let the user select a file, as the new path
-(IBAction) changePath:(id)sender
{
  int tag = [sender tag];
  NSTextField* textField = nil;
  switch(tag)
  {
    case 0 : textField = pdfLatexTextField; break;
    case 1 : textField = gsTextField; break;
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
      [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidEndEditingNotification object:textField];
    }
  }
}

-(void) controlTextDidChange:(NSNotification*)aNotification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSTextField* textField = [aNotification object];
  if (textField == pdfLatexTextField)
    didChangePdfLatexTextField = YES;
  else if (textField == gsTextField)
    didChangeGsTextField = YES;
  else if (textField == advancedLibraryStringExportTextField)
    [userDefaults setObject:[advancedLibraryStringExportTextField stringValue] forKey:AdvancedLibraryExportEncapsulationTextKey];
}

-(void) controlTextDidEndEditing:(NSNotification*)aNotification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSTextField* textField = [aNotification object];
  if (textField == pdfLatexTextField)
  {
    if (didChangePdfLatexTextField)
    {
      [userDefaults setObject:[textField stringValue] forKey:PdfLatexPathKey];
      [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
    }
    didChangePdfLatexTextField = NO;
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
  if (sender == serviceRespectsColor)
    [userDefaults setBool:([serviceRespectsColor state] == NSOnState) forKey:ServiceRespectsColorKey];
  else if (sender == serviceRespectsBaseline)
    [userDefaults setBool:([serviceRespectsBaseline state] == NSOnState) forKey:ServiceRespectsBaselineKey];
  else if (sender == serviceRespectsPointSize)
    [userDefaults setBool:([serviceRespectsPointSize state] == NSOnState) forKey:ServiceRespectsPointSizeKey];
}

-(IBAction) changeAdvancedConfiguration:(id)sender
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if (sender == advancedLibraryStringExportMatrix)
    [userDefaults setInteger:[[advancedLibraryStringExportMatrix selectedCell] tag] forKey:AdvancedLibraryExportTypeKey];
  else if (sender == advancedLibraryStringExportCheckBox)
    [userDefaults setBool:([advancedLibraryStringExportCheckBox state] == NSOnState) forKey:AdvancedLibraryExportUseEncapsulationKey];
  else if (sender == advancedLibraryStringExportTextField)
    [userDefaults setObject:[advancedLibraryStringExportTextField stringValue] forKey:AdvancedLibraryExportEncapsulationTextKey];
  else if (sender == additionalTopMarginTextField)
    [userDefaults setFloat:[additionalTopMarginTextField floatValue] forKey:AdditionalTopMarginKey];
  else if (sender == additionalLeftMarginTextField)
    [userDefaults setFloat:[additionalLeftMarginTextField floatValue] forKey:AdditionalLeftMarginKey];
  else if (sender == additionalRightMarginTextField)
    [userDefaults setFloat:[additionalRightMarginTextField floatValue] forKey:AdditionalRightMarginKey];
  else if (sender == additionalBottomMarginTextField)
    [userDefaults setFloat:[additionalBottomMarginTextField floatValue] forKey:AdditionalBottomMarginKey];
}

@end
