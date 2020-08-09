//
//  DocumentExtraPanelsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "DocumentExtraPanelsController.h"

#import "AppController.h"
#import "ExportFormatOptionsPanes.h"
#import "PreferencesController.h"
#import "Utils.h"

#import "NSButtonExtended.h"
#import "NSPopUpButtonExtended.h"
#import "NSViewExtended.h"

@interface DocumentExtraPanelsController () <ExportFormatOptionsDelegate>
-(IBAction) nilAction:(id)sender;
@end

@implementation DocumentExtraPanelsController
@synthesize currentSavePanel;
@synthesize saveAccessoryViewOptionsJpegBackgroundColor;
@synthesize saveAccessoryViewOptionsSvgPdfToSvgPath;
@synthesize saveAccessoryViewOptionsJpegQualityPercent;
@synthesize saveAccessoryViewOptionsTextExportPreamble;
@synthesize saveAccessoryViewOptionsTextExportEnvironment;
@synthesize saveAccessoryViewOptionsTextExportBody;
@synthesize saveAccessoryViewExportFormat;
@synthesize saveAccessoryViewScalePercent = saveAccessoryViewExportScalePercent;
@synthesize saveAccessoryViewOptionsPDFWofGSWriteEngine;
@synthesize saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel;
@synthesize saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled;

@synthesize saveAccessoryView;
@synthesize logWindow;
@synthesize logTextView;

#pragma mark init/load/dealloc

-(instancetype) initWithLoadingFromNib
{
  if ((!(self = [super initWithNibNamed:@"DocumentExtraPanelsController" bundle:nil])))
    return nil;
  PreferencesController* preferencesController = [PreferencesController sharedController];
  self->saveAccessoryViewExportFormat               = preferencesController.exportFormatCurrentSession;
  self->saveAccessoryViewExportScalePercent         = preferencesController.exportScalePercent;
  self->saveAccessoryViewOptionsJpegQualityPercent  = preferencesController.exportJpegQualityPercent;
  self->saveAccessoryViewOptionsJpegBackgroundColor = preferencesController.exportJpegBackgroundColor;
  self->saveAccessoryViewOptionsSvgPdfToSvgPath     = [preferencesController exportSvgPdfToSvgPath];
  self->saveAccessoryViewOptionsTextExportPreamble         = [preferencesController exportTextExportPreamble];
  self->saveAccessoryViewOptionsTextExportEnvironment      = [preferencesController exportTextExportEnvironment];
  self->saveAccessoryViewOptionsTextExportBody             = preferencesController.exportTextExportBody;
  NSArray *tmpNibs;
  [self instantiateWithOwner:self topLevelObjects:&tmpNibs];
  self->nibTopLevelObjects = tmpNibs;
  return self;
}
//end initWithLoadingFromNib

-(void) dealloc
{
  [self removeObserver:self forKeyPath:@"saveAccessoryViewExportFormat"];
  [self removeObserver:self forKeyPath:@"saveAccessoryViewOptionsSvgPdfToSvgPath"];
  [self->saveAccessoryViewPopupFormat unbind:NSSelectedTagBinding];
  [self->saveAccessoryViewScalePercentTextField unbind:NSValueBinding];
  //[self->saveAccessoryView release]; //release the extra retain count
}
//end dealloc

-(void) awakeFromNib
{
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
    LocalLocalizedString(@"Warning : pdf2svg was not found", @"")];
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
    self->saveAccessoryViewFormatLabel.frame.origin.x+
    self->saveAccessoryViewFormatLabel.frame.size.width+8+
    self->saveAccessoryViewPopupFormat.frame.size.width+8+
    self->saveAccessoryViewOptionsButton.frame.size.width+
    self->saveAccessoryViewFormatLabel.frame.origin.x,
    self->saveAccessoryView.frame.size.height)];
  [self->saveAccessoryViewPopupFormat setFrameOrigin:
    NSMakePoint(NSMaxX(self->saveAccessoryViewFormatLabel.frame)+8,
                self->saveAccessoryViewPopupFormat.frame.origin.y)];
  [self->saveAccessoryViewOptionsButton setFrameOrigin:
    NSMakePoint(NSMaxX(self->saveAccessoryViewPopupFormat.frame)+8,
                self->saveAccessoryViewOptionsButton.frame.origin.y)];
  [self->saveAccessoryViewScaleLabel setFrameOrigin:
    NSMakePoint((self->saveAccessoryViewScaleLabel.superview.frame.size.width-
                 self->saveAccessoryViewScaleLabel.frame.size.width-8-
                 self->saveAccessoryViewScalePercentTextField.frame.size.width)/2,
                self->saveAccessoryViewScaleLabel.frame.origin.y)];
  [self->saveAccessoryViewScalePercentTextField setFrameOrigin:
    NSMakePoint(NSMaxX(self->saveAccessoryViewScaleLabel.frame)+8,
                self->saveAccessoryViewScalePercentTextField.frame.origin.y)];
  [self->saveAccessoryViewJpegWarning centerInSuperviewHorizontally:YES vertically:NO];
  [self->saveAccessoryViewSvgWarning centerInSuperviewHorizontally:YES vertically:NO];
  [self->saveAccessoryViewMathMLWarning centerInSuperviewHorizontally:YES vertically:NO];
    
  self->saveAccessoryViewPopupFormat.target = self;
  [self->saveAccessoryViewPopupFormat bind:NSSelectedTagBinding toObject:self
    withKeyPath:@"saveAccessoryViewExportFormat" options:nil];
  [self->saveAccessoryViewScalePercentTextField bind:NSValueBinding toObject:self
    withKeyPath:@"saveAccessoryViewExportScalePercent" options:nil];
  [self addObserver:self forKeyPath:@"saveAccessoryViewExportFormat" options:0 context:nil];
  [self observeValueForKeyPath:@"saveAccessoryViewExportFormat" ofObject:self change:nil context:nil];
  [self addObserver:self forKeyPath:@"saveAccessoryViewOptionsSvgPdfToSvgPath" options:0 context:nil];
  [self observeValueForKeyPath:@"saveAccessoryViewOptionsSvgPdfToSvgPath" ofObject:self change:nil context:nil];
}
//end awakeFromNib

#pragma mark getters/setters

-(NSString*) log
{
  NSString* result = self->logTextView.string;
  return result;
}
//end log

-(void) setLog:(NSString*)value
{
  self->logTextView.string = value;
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

-(void) setCurrentSavePanel:(NSSavePanel*)value
{
  [self->currentSavePanel setAccessoryView:nil];
  self->currentSavePanel = value;
  self->currentSavePanel.accessoryView = self->saveAccessoryView;
  self->saveAccessoryView.window.delegate = self;
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
    }

    BOOL isJpegFormat = (exportFormat == EXPORT_FORMAT_JPEG);
    BOOL isMathMLFormat = (exportFormat == EXPORT_FORMAT_MATHML);
    BOOL isSvgFormat = (exportFormat == EXPORT_FORMAT_SVG);
    BOOL isPdfWofFormat = (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS);
    allowOptions = isJpegFormat || isSvgFormat || isPdfWofFormat;
    self->saveAccessoryViewOptionsButton.enabled = allowOptions;
    self->saveAccessoryViewScaleLabel.hidden = isMathMLFormat;
    self->saveAccessoryViewScalePercentTextField.hidden = isMathMLFormat;
    self->saveAccessoryViewJpegWarning.hidden = !isJpegFormat;
    BOOL isDirectory = NO;
    self->saveAccessoryViewSvgWarning.hidden = (!isSvgFormat ||
       ([[NSFileManager defaultManager]
         fileExistsAtPath:self->saveAccessoryViewOptionsSvgPdfToSvgPath isDirectory:&isDirectory] && !isDirectory));
    self->saveAccessoryViewMathMLWarning.hidden = (!isMathMLFormat || [AppController appController].perlWithLibXMLAvailable);
    if (isJpegFormat)
      self->currentSavePanel.allowedFileTypes = @[@"jpg", @"jpeg", (id)kUTTypeJPEG];
    [self->currentSavePanel setAllowedFileTypes:[NSArray arrayWithObjects:extension, nil]];
  }//end if ([keyPath isEqualToString:@"saveAccessoryViewExportFormat"])
  else if ([keyPath isEqualToString:@"saveAccessoryViewOptionsSvgPdfToSvgPath"])
  {
    export_format_t exportFormat = self->saveAccessoryViewExportFormat;
    BOOL isSvgFormat = (exportFormat == EXPORT_FORMAT_SVG);
    BOOL isDirectory = NO;
    self->saveAccessoryViewSvgWarning.hidden = (!isSvgFormat ||
       ([[NSFileManager defaultManager]
         fileExistsAtPath:self->saveAccessoryViewOptionsSvgPdfToSvgPath isDirectory:&isDirectory] && !isDirectory));
  }//end if ([keyPath isEqualToString:@"saveAccessoryViewOptionsSvgPdfToSvgPath"])
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
    self->saveAccessoryViewExportFormatOptionsPanes.exportFormatOptionsJpegPanelDelegate = self;
    self->saveAccessoryViewExportFormatOptionsPanes.exportFormatOptionsSvgPanelDelegate = self;
    self->saveAccessoryViewExportFormatOptionsPanes.exportFormatOptionsTextPanelDelegate = self;
  }//end if (!self->saveAccessoryViewExportFormatOptionsPanes)
  self->saveAccessoryViewExportFormatOptionsPanes.jpegQualityPercent = self->saveAccessoryViewOptionsJpegQualityPercent;
  self->saveAccessoryViewExportFormatOptionsPanes.jpegBackgroundColor = self->saveAccessoryViewOptionsJpegBackgroundColor;
  self->saveAccessoryViewExportFormatOptionsPanes.svgPdfToSvgPath = self->saveAccessoryViewOptionsSvgPdfToSvgPath;
  self->saveAccessoryViewExportFormatOptionsPanes.textExportPreamble = self->saveAccessoryViewOptionsTextExportPreamble;
  self->saveAccessoryViewExportFormatOptionsPanes.textExportEnvironment = self->saveAccessoryViewOptionsTextExportEnvironment;
  self->saveAccessoryViewExportFormatOptionsPanes.textExportBody = self->saveAccessoryViewOptionsTextExportBody;
  self->saveAccessoryViewExportFormatOptionsPanes.pdfWofGSWriteEngine = self->saveAccessoryViewOptionsPDFWofGSWriteEngine;
  self->saveAccessoryViewExportFormatOptionsPanes.pdfWofGSPDFCompatibilityLevel = self->saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel;
  self->saveAccessoryViewExportFormatOptionsPanes.pdfWofMetaDataInvisibleGraphicsEnabled = self->saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled;
  NSPanel* panelToOpen = nil;
  export_format_t exportFormat = (export_format_t)[self->saveAccessoryViewPopupFormat selectedTag];
  if (exportFormat == EXPORT_FORMAT_JPEG)
    panelToOpen = self->saveAccessoryViewExportFormatOptionsPanes.exportFormatOptionsJpegPanel;
  else if (exportFormat == EXPORT_FORMAT_SVG)
    panelToOpen = self->saveAccessoryViewExportFormatOptionsPanes.exportFormatOptionsSvgPanel;
  if (panelToOpen)
    [NSApp runModalForWindow:panelToOpen];
}
//end openSaveAccessoryViewOptions:

-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok
{
  if (ok)
  {
    if (exportFormatOptionsPanel == self->saveAccessoryViewExportFormatOptionsPanes.exportFormatOptionsJpegPanel)
    {
      self.saveAccessoryViewOptionsJpegQualityPercent = self->saveAccessoryViewExportFormatOptionsPanes.jpegQualityPercent;
      self.saveAccessoryViewOptionsJpegBackgroundColor = self->saveAccessoryViewExportFormatOptionsPanes.jpegBackgroundColor;
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    else if (exportFormatOptionsPanel == self->saveAccessoryViewExportFormatOptionsPanes.exportFormatOptionsSvgPanel)
    {
      self.saveAccessoryViewOptionsSvgPdfToSvgPath = self->saveAccessoryViewExportFormatOptionsPanes.svgPdfToSvgPath;
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    else if (exportFormatOptionsPanel == self->saveAccessoryViewExportFormatOptionsPanes.exportFormatOptionsPDFWofPanel)
    {
      self.saveAccessoryViewOptionsPDFWofGSWriteEngine = self->saveAccessoryViewExportFormatOptionsPanes.pdfWofGSWriteEngine;
      self.saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel = self->saveAccessoryViewExportFormatOptionsPanes.pdfWofGSPDFCompatibilityLevel;
      self.saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled = self->saveAccessoryViewExportFormatOptionsPanes.pdfWofMetaDataInvisibleGraphicsEnabled;
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsPDFWofPanel])
  }//end if (ok)
  [NSApp stopModal];
  [exportFormatOptionsPanel orderOut:self];
}
//end exportFormatOptionsPanel:didCloseWithOK:

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

@end
