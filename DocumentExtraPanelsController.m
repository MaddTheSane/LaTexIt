//
//  DocumentExtraPanelsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/04/09.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import "DocumentExtraPanelsController.h"

#import "AppController.h"
#import "ExportFormatOptionsPanes.h"
#import "PreferencesController.h"
#import "Utils.h"

#import "NSButtonExtended.h"
#import "NSPopUpButtonExtended.h"
#import "NSViewExtended.h"

@interface DocumentExtraPanelsController ()
-(IBAction) nilAction:(id)sender;
@end

@implementation DocumentExtraPanelsController

#pragma mark init/load/dealloc

-(id) initWithLoadingFromNib
{
  if ((!(self = [super initWithNibNamed:@"DocumentExtraPanelsController" bundle:nil])))
    return nil;
  PreferencesController* preferencesController = [PreferencesController sharedController];
  self->saveAccessoryViewExportFormat               = [preferencesController exportFormatCurrentSession];
  self->saveAccessoryViewExportScalePercent         = [preferencesController exportScalePercent];
  self->saveAccessoryViewOptionsJpegQualityPercent  = [preferencesController exportJpegQualityPercent];
  self->saveAccessoryViewOptionsJpegBackgroundColor = [[preferencesController exportJpegBackgroundColor] retain];
  self->saveAccessoryViewOptionsSvgPdfToSvgPath     = [[preferencesController exportSvgPdfToSvgPath] retain];
  self->saveAccessoryViewOptionsSvgPdfToCairoPath     = [[preferencesController exportSvgPdfToCairoPath] retain];
  self->saveAccessoryViewOptionsTextExportPreamble         = [preferencesController exportTextExportPreamble];
  self->saveAccessoryViewOptionsTextExportEnvironment      = [preferencesController exportTextExportEnvironment];
  self->saveAccessoryViewOptionsTextExportBody             = [preferencesController exportTextExportBody];
  [self instantiateWithOwner:self topLevelObjects:&self->nibTopLevelObjects];
  [self->nibTopLevelObjects retain];
  return self;
}
//end initWithLoadingFromNib

-(void) dealloc
{
  [self removeObserver:self forKeyPath:@"saveAccessoryViewExportFormat"];
  [self removeObserver:self forKeyPath:@"saveAccessoryViewOptionsSvgPdfToSvgPath"];
  [self removeObserver:self forKeyPath:@"saveAccessoryViewOptionsSvgPdfToCairoPath"];
  [self->saveAccessoryViewPopupFormat unbind:NSSelectedTagBinding];
  [self->saveAccessoryViewScalePercentTextField unbind:NSValueBinding];
  [self->saveAccessoryViewExportFormatOptionsPanes release];
  [self->saveAccessoryViewOptionsJpegBackgroundColor release];
  [self->saveAccessoryViewOptionsSvgPdfToSvgPath release];
  [self->saveAccessoryViewOptionsSvgPdfToCairoPath release];
  [self->saveAccessoryView release]; //release the extra retain count
  [self->nibTopLevelObjects release];
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  [self->saveAccessoryView retain]; //to avoid unwanted deallocation when save panel is closed
  [self->logWindow setTitle:LocalLocalizedString(@"Execution log", @"")];
  [self->saveAccessoryViewFormatLabel setStringValue:
    [NSString stringWithFormat:@"%@ : ", LocalLocalizedString(@"Format", @"")]];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"PDF vector format", @"")
    tag:(NSInteger)EXPORT_FORMAT_PDF];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"PDF with outlined fonts", @"")
    tag:(NSInteger)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"EPS vector format", @"")
    tag:(NSInteger)EXPORT_FORMAT_EPS];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"SVG vector format", @"")
    tag:(NSInteger)EXPORT_FORMAT_SVG];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"TIFF bitmap format", @"")
    tag:(NSInteger)EXPORT_FORMAT_TIFF];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"PNG bitmap format", @"")
    tag:(NSInteger)EXPORT_FORMAT_PNG];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"JPEG bitmap format", @"")
    tag:(NSInteger)EXPORT_FORMAT_JPEG];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"MathML text format", @"")
    tag:(NSInteger)EXPORT_FORMAT_MATHML];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"Text format", @"")
    tag:(NSInteger)EXPORT_FORMAT_TEXT];
  [self->saveAccessoryViewOptionsButton setStringValue:
    [NSString stringWithFormat:@"%@...", LocalLocalizedString(@"Options", @"")]];
  [self->saveAccessoryViewScaleLabel setStringValue:
    [NSString stringWithFormat:@"%@ : ", LocalLocalizedString(@"Scale", @"")]];
  [self->saveAccessoryViewJpegWarning setTitle:
    LocalLocalizedString(@"Warning : jpeg does not manage transparency", @"")];
  [self->saveAccessoryViewSvgWarning setTitle:
    LocalLocalizedString(@"Warning : pdf2svg or pdftocairo was not found", @"")];
  [self->saveAccessoryViewSvgWarning setTextColor:[NSColor redColor]];
  [self->saveAccessoryViewMathMLWarning setTitle:
   LocalLocalizedString(@"Warning : the XML::LibXML perl module was not found", @"")];
  [self->saveAccessoryViewMathMLWarning setTextColor:[NSColor redColor]];
  
  [self->saveAccessoryViewFormatLabel sizeToFit];
  [self->saveAccessoryViewPopupFormat sizeToFit];
  [self->saveAccessoryViewOptionsButton sizeToFit];
  [self->saveAccessoryViewScaleLabel sizeToFit];
  [self->saveAccessoryViewJpegWarning sizeToFit];
  [self->saveAccessoryViewSvgWarning sizeToFit];
  [self->saveAccessoryViewMathMLWarning sizeToFit];
  [self->saveAccessoryView setFrameSize:NSMakeSize(
    [self->saveAccessoryViewFormatLabel frame].origin.x+
    [self->saveAccessoryViewFormatLabel frame].size.width+8+
    [self->saveAccessoryViewPopupFormat frame].size.width+8+
    [self->saveAccessoryViewOptionsButton frame].size.width+
    [self->saveAccessoryViewFormatLabel frame].origin.x,
    [self->saveAccessoryView frame].size.height)];
  [self->saveAccessoryViewPopupFormat setFrameOrigin:
    NSMakePoint(NSMaxX([self->saveAccessoryViewFormatLabel frame])+8,
                [self->saveAccessoryViewPopupFormat frame].origin.y)];
  [self->saveAccessoryViewOptionsButton setFrameOrigin:
    NSMakePoint(NSMaxX([self->saveAccessoryViewPopupFormat frame])+8,
                [self->saveAccessoryViewOptionsButton frame].origin.y)];
  [self->saveAccessoryViewScaleLabel setFrameOrigin:
    NSMakePoint(([[self->saveAccessoryViewScaleLabel superview] frame].size.width-
                 [self->saveAccessoryViewScaleLabel frame].size.width-8-
                 [self->saveAccessoryViewScalePercentTextField frame].size.width)/2,
                [self->saveAccessoryViewScaleLabel frame].origin.y)];
  [self->saveAccessoryViewScalePercentTextField setFrameOrigin:
    NSMakePoint(NSMaxX([self->saveAccessoryViewScaleLabel frame])+8,
                [self->saveAccessoryViewScalePercentTextField frame].origin.y)];
  [self->saveAccessoryViewJpegWarning centerInSuperviewHorizontally:YES vertically:NO];
  [self->saveAccessoryViewSvgWarning centerInSuperviewHorizontally:YES vertically:NO];
  [self->saveAccessoryViewMathMLWarning centerInSuperviewHorizontally:YES vertically:NO];
    
  [self->saveAccessoryViewPopupFormat setTarget:self];
  [self->saveAccessoryViewPopupFormat bind:NSSelectedTagBinding toObject:self
    withKeyPath:@"saveAccessoryViewExportFormat" options:nil];
  [self->saveAccessoryViewScalePercentTextField bind:NSValueBinding toObject:self
    withKeyPath:@"saveAccessoryViewExportScalePercent" options:nil];
  [self addObserver:self forKeyPath:@"saveAccessoryViewExportFormat" options:0 context:nil];
  [self observeValueForKeyPath:@"saveAccessoryViewExportFormat" ofObject:self change:nil context:nil];
  [self addObserver:self forKeyPath:@"saveAccessoryViewOptionsSvgPdfToSvgPath" options:0 context:nil];
  [self observeValueForKeyPath:@"saveAccessoryViewOptionsSvgPdfToSvgPath" ofObject:self change:nil context:nil];
  [self addObserver:self forKeyPath:@"saveAccessoryViewOptionsSvgPdfToCairoPath" options:0 context:nil];
  [self observeValueForKeyPath:@"saveAccessoryViewOptionsSvgPdfToCairoPath" ofObject:self change:nil context:nil];
}
//end awakeFromNib

#pragma mark getters/setters

-(NSWindow*) logWindow
{
  return self->logWindow;
}
//end logWindow

-(NSTextView*) logTextView
{
  return self->logTextView;
}
//end logTextView

-(NSString*) log
{
  NSString* result = [self->logTextView string];
  return result;
}
//end log

-(void) setLog:(NSString*)value
{
  [self->logTextView setString:value];
}
//end setLog:

-(NSWindow*) baselineWindow
{
  return self->baselineWindow;
}
//end logWindow

-(NSTextField*) baselineTextField
{
  return self->baselineTextField;
}
//end baselineTextField

-(export_format_t) saveAccessoryViewExportFormat
{
  return self->saveAccessoryViewExportFormat;
}
//end saveAccessoryViewExportFormat

-(void) setSaveAccessoryViewExportFormat:(export_format_t)value
{
  if (value != self->saveAccessoryViewExportFormat)
  {
    [self willChangeValueForKey:@"saveAccessoryViewExportFormat"];
    self->saveAccessoryViewExportFormat = value;
    [self didChangeValueForKey:@"saveAccessoryViewExportFormat"];
  }//end if (value != self->saveAccessoryViewExportFormat)
}
//end setSaveAccessoryViewExportFormat:

-(CGFloat) saveAccessoryViewScalePercent
{
  return self->saveAccessoryViewExportScalePercent;
}
//end saveAccessoryViewScalePercent

-(void) setSaveAccessoryViewScalePercent:(CGFloat)value
{
  if (value != self->saveAccessoryViewExportScalePercent)
  {
    [self willChangeValueForKey:@"saveAccessoryViewExportScalePercent"];
    self->saveAccessoryViewExportScalePercent = value;
    [self didChangeValueForKey:@"saveAccessoryViewExportScalePercent"];
  }//end if (value != self->saveAccessoryViewExportScalePercent)
}
//end setSaveAccessoryViewExportScalePercent:

-(CGFloat) saveAccessoryViewOptionsJpegQualityPercent
{
  return self->saveAccessoryViewOptionsJpegQualityPercent;
}
//end saveAccessoryViewOptionsJpegQualityPercent

-(void) setSaveAccessoryViewOptionsJpegQualityPercent:(CGFloat)value
{
  self->saveAccessoryViewOptionsJpegQualityPercent = value;
}
//end setSaveAccessoryViewOptionsJpegQualityPercent:

-(NSColor*) saveAccessoryViewOptionsJpegBackgroundColor
{
  return self->saveAccessoryViewOptionsJpegBackgroundColor;
}
//end saveAccessoryViewOptionsJpegBackgroundColor

-(void) setSaveAccessoryViewOptionsJpegBackgroundColor:(NSColor*)value
{
  [value retain];
  [self->saveAccessoryViewOptionsJpegBackgroundColor release];
  self->saveAccessoryViewOptionsJpegBackgroundColor = value;
}
//end setSaveAccessoryViewOptionsJpegBackgroundColor:

-(NSString*) saveAccessoryViewOptionsSvgPdfToSvgPath
{
  return self->saveAccessoryViewOptionsSvgPdfToSvgPath;
}
//end saveAccessoryViewOptionsSvgPdfToSvgPath

-(void) setSaveAccessoryViewOptionsSvgPdfToSvgPath:(NSString*)value
{
  if (value != self->saveAccessoryViewOptionsSvgPdfToSvgPath)
  {
    [self willChangeValueForKey:@"saveAccessoryViewOptionsSvgPdfToSvgPath"];
    [self->saveAccessoryViewOptionsSvgPdfToSvgPath release];
    self->saveAccessoryViewOptionsSvgPdfToSvgPath = [value copy];
    [self didChangeValueForKey:@"saveAccessoryViewOptionsSvgPdfToSvgPath"];
  }//end if (value != self->saveAccessoryViewOptionsSvgPdfToSvgPath)
}
//end setSaveAccessoryViewOptionsSvgPdfToSvgPath:

-(NSString*) saveAccessoryViewOptionsSvgPdfToCairoPath
{
  return self->saveAccessoryViewOptionsSvgPdfToCairoPath;
}
//end saveAccessoryViewOptionsSvgPdfToCairoPath

-(void) setSaveAccessoryViewOptionsSvgPdfToCairoPath:(NSString*)value
{
  if (value != self->saveAccessoryViewOptionsSvgPdfToCairoPath)
  {
    [self willChangeValueForKey:@"saveAccessoryViewOptionsSvgPdfToCairoPath"];
    [self->saveAccessoryViewOptionsSvgPdfToCairoPath release];
    self->saveAccessoryViewOptionsSvgPdfToCairoPath = [value copy];
    [self didChangeValueForKey:@"saveAccessoryViewOptionsSvgPdfToCairoPath"];
  }//end if (value != self->saveAccessoryViewOptionsSvgPdfToCairoPath)
}
//end setSaveAccessoryViewOptionsSvgPdfToCairoPath:

-(BOOL) saveAccessoryViewOptionsTextExportPreamble
{
  return self->saveAccessoryViewOptionsTextExportPreamble;
}
//end saveAccessoryViewOptionsTextExportPreamble

-(void) setSaveAccessoryViewOptionsTextExportPreamble:(BOOL)value
{
  self->saveAccessoryViewOptionsTextExportPreamble = value;
}
//end setSaveAccessoryViewOptionsTextExportPreamble:

-(BOOL) saveAccessoryViewOptionsTextExportEnvironment
{
  return self->saveAccessoryViewOptionsTextExportEnvironment;
}
//end saveAccessoryViewOptionsTextExportEnvironment

-(void) setSaveAccessoryViewOptionsTextExportEnvironment:(BOOL)value
{
  self->saveAccessoryViewOptionsTextExportEnvironment = value;
}
//end setSaveAccessoryViewOptionsTextExportEnvironment:

-(BOOL) saveAccessoryViewOptionsTextExportBody
{
  return self->saveAccessoryViewOptionsTextExportBody;
}
//end saveAccessoryViewOptionsTextExportBody

-(void) setSaveAccessoryViewOptionsTextExportBody:(BOOL)value
{
  self->saveAccessoryViewOptionsTextExportBody = value;
}
//end setSaveAccessoryViewOptionsTextExportBody:

-(NSString*) saveAccessoryViewOptionsPDFWofGSWriteEngine
{
  return self->saveAccessoryViewOptionsPDFWofGSWriteEngine;
}
//end saveAccessoryViewOptionsPDFWofGSWriteEngine

-(void) setSaveAccessoryViewOptionsPDFWofGSWriteEngine:(NSString*)value
{
  [value retain];
  [self->saveAccessoryViewOptionsPDFWofGSWriteEngine release];
  self->saveAccessoryViewOptionsPDFWofGSWriteEngine = value;
}
//end setSaveAccessoryViewOptionsPDFWofGSWriteEngine:

-(NSString*) saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel
{
  return self->saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel;
}
//end saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel

-(void) setSaveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel:(NSString*)value
{
  [value retain];
  [self->saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel release];
  self->saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel = value;
}
//end setSaveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel:

-(BOOL) saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled
{
  return self->saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled;
}
//end saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled

-(void) setSaveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled:(BOOL)value
{
  self->saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled = value;
}
//end setSaveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled:

-(BOOL) saveAccessoryViewOptionsPDFMetaDataInvisibleGraphicsEnabled
{
  return self->saveAccessoryViewOptionsPDFMetaDataInvisibleGraphicsEnabled;
}
//end saveAccessoryViewOptionsPDFMetaDataInvisibleGraphicsEnabled

-(void) setSaveAccessoryViewOptionsPDFMetaDataInvisibleGraphicsEnabled:(BOOL)value
{
  self->saveAccessoryViewOptionsPDFMetaDataInvisibleGraphicsEnabled = value;
}
//end setSaveAccessoryViewOptionsPDFMetaDataInvisibleGraphicsEnabled:

-(NSSavePanel*) currentSavePanel
{
  return self->currentSavePanel;
}
//end currentSavePanel

-(void) setCurrentSavePanel:(NSSavePanel*)value
{
  [self->currentSavePanel setAccessoryView:nil];
  self->currentSavePanel = value;
  [self->currentSavePanel setAccessoryView:self->saveAccessoryView];
  [[self->saveAccessoryView window] setDelegate:(id)self];
}
//end setCurrentSavePanel:

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:@"saveAccessoryViewExportFormat"])
  {
    BOOL allowOptions = NO;
    export_format_t exportFormat = self->saveAccessoryViewExportFormat;
    NSString* extension = nil;
    switch(exportFormat)
    {
      case EXPORT_FORMAT_PDF:
      case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
        extension = @"pdf";
        break;
      case EXPORT_FORMAT_EPS:
        extension = @"eps";
        break;
      case EXPORT_FORMAT_TIFF:
        extension = @"tiff";
        break;
      case EXPORT_FORMAT_PNG:
        extension = @"png";
        break;
      case EXPORT_FORMAT_JPEG:
        extension = @"jpeg";
        break;
      case EXPORT_FORMAT_MATHML:
        extension = @"html";
        break;
      case EXPORT_FORMAT_SVG:
        extension = @"svg";
        break;
      case EXPORT_FORMAT_TEXT:
        extension = @"tex";
        break;
      case EXPORT_FORMAT_RTFD:
        extension = @"rtfd";
        break;
    }

    BOOL isJpegFormat = (exportFormat == EXPORT_FORMAT_JPEG);
    BOOL isMathMLFormat = (exportFormat == EXPORT_FORMAT_MATHML);
    BOOL isSvgFormat = (exportFormat == EXPORT_FORMAT_SVG);
    BOOL isPdfWofFormat = (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS);
    allowOptions = isJpegFormat || isSvgFormat || isPdfWofFormat;
    [self->saveAccessoryViewOptionsButton setEnabled:allowOptions];
    [self->saveAccessoryViewScaleLabel setHidden:isMathMLFormat];
    [self->saveAccessoryViewScalePercentTextField setHidden:isMathMLFormat];
    [self->saveAccessoryViewJpegWarning setHidden:!isJpegFormat];
    BOOL isDirectory = NO;
    [self->saveAccessoryViewSvgWarning setHidden:
      (!isSvgFormat ||
       ([[NSFileManager defaultManager]
         fileExistsAtPath:self->saveAccessoryViewOptionsSvgPdfToSvgPath isDirectory:&isDirectory] && !isDirectory) ||
       ([[NSFileManager defaultManager]
         fileExistsAtPath:self->saveAccessoryViewOptionsSvgPdfToCairoPath isDirectory:&isDirectory] && !isDirectory)
      )];
    [self->saveAccessoryViewMathMLWarning setHidden:
     (!isMathMLFormat || [[AppController appController] isPerlWithLibXMLAvailable])];
    if (isJpegFormat)
      [self->currentSavePanel setAllowedFileTypes:@[@"jpg", @"jpeg"]];
    [self->currentSavePanel setAllowedFileTypes:[NSArray arrayWithObjects:extension, nil]];
  }//end if ([keyPath isEqualToString:@"saveAccessoryViewExportFormat"])
  else if ([keyPath isEqualToString:@"saveAccessoryViewOptionsSvgPdfToSvgPath"] || [keyPath isEqualToString:@"saveAccessoryViewOptionsSvgPdfToCairoPath"])
  {
    export_format_t exportFormat = self->saveAccessoryViewExportFormat;
    BOOL isSvgFormat = (exportFormat == EXPORT_FORMAT_SVG);
    BOOL isDirectory = NO;
    [self->saveAccessoryViewSvgWarning setHidden:
      (!isSvgFormat ||
       ([[NSFileManager defaultManager]
         fileExistsAtPath:self->saveAccessoryViewOptionsSvgPdfToSvgPath isDirectory:&isDirectory] && !isDirectory) ||
       ([[NSFileManager defaultManager]
         fileExistsAtPath:self->saveAccessoryViewOptionsSvgPdfToCairoPath isDirectory:&isDirectory] && !isDirectory)
       )];
  }//end if ([keyPath isEqualToString:@"saveAccessoryViewOptionsSvgPdfToSvgPath"] || [keyPath isEqualToString:@"saveAccessoryViewOptionsSvgPdfToCairoPath"])
}
//end observeValueForKeyPath:ofObject:change:context:

#pragma mark actions
-(IBAction) nilAction:(id)sender
{
  //useful for validateMenuItem:
}
//end nilAction:

-(IBAction) openSaveAccessoryViewOptions:(id)sender
{
  if (!self->saveAccessoryViewExportFormatOptionsPanes)
  {
    self->saveAccessoryViewExportFormatOptionsPanes = [[ExportFormatOptionsPanes alloc] initWithLoadingFromNib];
    [self->saveAccessoryViewExportFormatOptionsPanes setExportFormatOptionsJpegPanelDelegate:self];
    [self->saveAccessoryViewExportFormatOptionsPanes setExportFormatOptionsSvgPanelDelegate:self];
    [self->saveAccessoryViewExportFormatOptionsPanes setExportFormatOptionsTextPanelDelegate:self];
  }//end if (!self->saveAccessoryViewExportFormatOptionsPanes)
  [self->saveAccessoryViewExportFormatOptionsPanes setJpegQualityPercent:self->saveAccessoryViewOptionsJpegQualityPercent];
  [self->saveAccessoryViewExportFormatOptionsPanes setJpegBackgroundColor:self->saveAccessoryViewOptionsJpegBackgroundColor];
  [self->saveAccessoryViewExportFormatOptionsPanes setSvgPdfToSvgPath:self->saveAccessoryViewOptionsSvgPdfToSvgPath];
  [self->saveAccessoryViewExportFormatOptionsPanes setSvgPdfToCairoPath:self->saveAccessoryViewOptionsSvgPdfToCairoPath];
  [self->saveAccessoryViewExportFormatOptionsPanes setTextExportPreamble:self->saveAccessoryViewOptionsTextExportPreamble];
  [self->saveAccessoryViewExportFormatOptionsPanes setTextExportEnvironment:self->saveAccessoryViewOptionsTextExportEnvironment];
  [self->saveAccessoryViewExportFormatOptionsPanes setTextExportBody:self->saveAccessoryViewOptionsTextExportBody];
  [self->saveAccessoryViewExportFormatOptionsPanes setPdfWofGSWriteEngine:self->saveAccessoryViewOptionsPDFWofGSWriteEngine];
  [self->saveAccessoryViewExportFormatOptionsPanes setPdfWofGSPDFCompatibilityLevel:self->saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel];
  [self->saveAccessoryViewExportFormatOptionsPanes setPdfWofMetaDataInvisibleGraphicsEnabled:self->saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled];
  NSPanel* panelToOpen = nil;
  export_format_t exportFormat = (export_format_t)[self->saveAccessoryViewPopupFormat selectedTag];
  if (exportFormat == EXPORT_FORMAT_JPEG)
    panelToOpen = [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsJpegPanel];
  else if (exportFormat == EXPORT_FORMAT_SVG)
    panelToOpen = [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsSvgPanel];
  if (panelToOpen)
    [NSApp runModalForWindow:panelToOpen];
}
//end openSaveAccessoryViewOptions:

-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok
{
  if (ok)
  {
    PreferencesController* preferencesController = [PreferencesController sharedController];
    if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    {
      [self setSaveAccessoryViewOptionsJpegQualityPercent:[self->saveAccessoryViewExportFormatOptionsPanes jpegQualityPercent]];
      [self setSaveAccessoryViewOptionsJpegBackgroundColor:[self->saveAccessoryViewExportFormatOptionsPanes jpegBackgroundColor]];
      [preferencesController setExportJpegQualityPercent:[self->saveAccessoryViewExportFormatOptionsPanes jpegQualityPercent]];
      [preferencesController setExportJpegBackgroundColor:[self->saveAccessoryViewExportFormatOptionsPanes jpegBackgroundColor]];
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    else if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    {
      [self setSaveAccessoryViewOptionsSvgPdfToSvgPath:[self->saveAccessoryViewExportFormatOptionsPanes svgPdfToSvgPath]];
      [self setSaveAccessoryViewOptionsSvgPdfToCairoPath:[self->saveAccessoryViewExportFormatOptionsPanes svgPdfToCairoPath]];
      [preferencesController setExportSvgPdfToSvgPath:[self->saveAccessoryViewExportFormatOptionsPanes svgPdfToSvgPath]];
      [preferencesController setExportSvgPdfToCairoPath:[self->saveAccessoryViewExportFormatOptionsPanes svgPdfToCairoPath]];
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    else if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsTextPanel])
    {
      [self setSaveAccessoryViewOptionsTextExportPreamble:[self->saveAccessoryViewExportFormatOptionsPanes textExportPreamble]];
      [self setSaveAccessoryViewOptionsTextExportEnvironment:[self->saveAccessoryViewExportFormatOptionsPanes textExportEnvironment]];
      [self setSaveAccessoryViewOptionsTextExportBody:[self->saveAccessoryViewExportFormatOptionsPanes textExportBody]];
      [preferencesController setExportTextExportPreamble:[self->saveAccessoryViewExportFormatOptionsPanes textExportPreamble]];
      [preferencesController setExportTextExportEnvironment:[self->saveAccessoryViewExportFormatOptionsPanes textExportEnvironment]];
      [preferencesController setExportTextExportBody:[self->saveAccessoryViewExportFormatOptionsPanes textExportBody]];
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsTextPanel])
    else if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsPDFWofPanel])
    {
      [self setSaveAccessoryViewOptionsPDFWofGSWriteEngine:[self->saveAccessoryViewExportFormatOptionsPanes pdfWofGSWriteEngine]];
      [self setSaveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel:[self->saveAccessoryViewExportFormatOptionsPanes pdfWofGSPDFCompatibilityLevel]];
      [self setSaveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled:[self->saveAccessoryViewExportFormatOptionsPanes pdfWofMetaDataInvisibleGraphicsEnabled]];
      [preferencesController setExportPDFWOFGsWriteEngine:[self->saveAccessoryViewExportFormatOptionsPanes pdfWofGSWriteEngine]];
      [preferencesController setExportPDFWOFGsPDFCompatibilityLevel:[self->saveAccessoryViewExportFormatOptionsPanes pdfWofGSPDFCompatibilityLevel]];
      [preferencesController setExportPDFWOFMetaDataInvisibleGraphicsEnabled:[self->saveAccessoryViewExportFormatOptionsPanes pdfWofMetaDataInvisibleGraphicsEnabled]];
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsPDFWofPanel])
    else if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsPDFPanel])
    {
      [self setSaveAccessoryViewOptionsPDFMetaDataInvisibleGraphicsEnabled:[self->saveAccessoryViewExportFormatOptionsPanes pdfMetaDataInvisibleGraphicsEnabled]];
      [preferencesController setExportPDFMetaDataInvisibleGraphicsEnabled:[self->saveAccessoryViewExportFormatOptionsPanes pdfMetaDataInvisibleGraphicsEnabled]];
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsPDFPanel])
  }//end if (ok)
  [NSApp stopModal];
  [exportFormatOptionsPanel orderOut:self];
}
//end exportFormatOptionsPanel:didCloseWithOK:

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

@end
