//
//  DocumentExtraPanelsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/04/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "DocumentExtraPanelsController.h"

#import "AppController.h"
#import "ExportFormatOptionsPanes.h"
#import "PreferencesController.h"
#import "Utils.h"

#import "NSButtonExtended.h"
#import "NSPopupButtonExtended.h"
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
  [self instantiateNibWithOwner:self topLevelObjects:nil];
  return self;
}
//end initWithLoadingFromNib

-(void) dealloc
{
  [self removeObserver:self forKeyPath:@"saveAccessoryViewExportFormat"];
  [self removeObserver:self forKeyPath:@"saveAccessoryViewOptionsSvgPdfToSvgPath"];
  [self->saveAccessoryViewPopupFormat unbind:NSSelectedTagBinding];
  [self->saveAccessoryViewScalePercentTextField unbind:NSValueBinding];
  [self->saveAccessoryViewExportFormatOptionsPanes release];
  [self->saveAccessoryViewOptionsJpegBackgroundColor release];
  [self->saveAccessoryViewOptionsSvgPdfToSvgPath release];
  [self->saveAccessoryView release]; //release the extra retain count
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  [self->saveAccessoryView retain]; //to avoid unwanted deallocation when save panel is closed
  [self->logWindow setTitle:NSLocalizedString(@"Execution log", @"Execution log")];
  [self->saveAccessoryViewFormatLabel setStringValue:
    [NSString stringWithFormat:@"%@ : ", LocalLocalizedString(@"Format", @"Format")]];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"PDF vector format", @"PDF vector format")
    tag:(int)EXPORT_FORMAT_PDF];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"PDF with outlined fonts", @"PDF with outlined fonts")
    tag:(int)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"EPS vector format", @"EPS vector format")
    tag:(int)EXPORT_FORMAT_EPS];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"SVG vector format", @"SVG vector format")
    tag:(int)EXPORT_FORMAT_SVG];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"TIFF bitmap format", @"TIFF bitmap format")
    tag:(int)EXPORT_FORMAT_TIFF];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"PNG bitmap format", @"PNG bitmap format")
    tag:(int)EXPORT_FORMAT_PNG];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"JPEG bitmap format", @"JPEG bitmap format")
    tag:(int)EXPORT_FORMAT_JPEG];
  [self->saveAccessoryViewPopupFormat addItemWithTitle:LocalLocalizedString(@"MathML text format", @"MathML text format")
    tag:(int)EXPORT_FORMAT_MATHML];
  [self->saveAccessoryViewOptionsButton setStringValue:
    [NSString stringWithFormat:@"%@...", LocalLocalizedString(@"Options", @"Options")]];
  [self->saveAccessoryViewScaleLabel setStringValue:
    [NSString stringWithFormat:@"%@ : ", LocalLocalizedString(@"Scale", @"Scale")]];
  [self->saveAccessoryViewJpegWarning setTitle:
    LocalLocalizedString(@"Warning : jpeg does not manage transparency", @"Warning : jpeg does not manage transparency")];
  [self->saveAccessoryViewSvgWarning setTitle:
    LocalLocalizedString(@"Warning : pdf2svg path is invalid", @"Warning : pdf2svg path is invalid")];
  [self->saveAccessoryViewSvgWarning setTextColor:[NSColor redColor]];
  
  [self->saveAccessoryViewFormatLabel sizeToFit];
  [self->saveAccessoryViewPopupFormat sizeToFit];
  [self->saveAccessoryViewOptionsButton sizeToFit];
  [self->saveAccessoryViewScaleLabel sizeToFit];
  [self->saveAccessoryViewJpegWarning sizeToFit];
  [self->saveAccessoryViewSvgWarning sizeToFit];
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
    
  [self->saveAccessoryViewPopupFormat setTarget:self];
  [self->saveAccessoryViewPopupFormat setAction:@selector(nilAction:)];
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
    }

    BOOL isJpegFormat = (exportFormat == EXPORT_FORMAT_JPEG);
    BOOL isMathMLFormat = (exportFormat == EXPORT_FORMAT_MATHML);
    BOOL isSvgFormat = (exportFormat == EXPORT_FORMAT_SVG);
    allowOptions = isJpegFormat || isSvgFormat;
    [self->saveAccessoryViewOptionsButton setEnabled:allowOptions];
    [self->saveAccessoryViewScaleLabel setHidden:isMathMLFormat];
    [self->saveAccessoryViewScalePercentTextField setHidden:isMathMLFormat];
    [self->saveAccessoryViewJpegWarning setHidden:!isJpegFormat];
    BOOL isDirectory = NO;
    [self->saveAccessoryViewSvgWarning setHidden:
      (!isSvgFormat ||
       ([[NSFileManager defaultManager]
         fileExistsAtPath:self->saveAccessoryViewOptionsSvgPdfToSvgPath isDirectory:&isDirectory] && !isDirectory))];
    if (isJpegFormat)
      [self->currentSavePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpg", @"jpeg", nil]];
    else
      [self->currentSavePanel setRequiredFileType:extension];
  }//end if ([keyPath isEqualToString:@"saveAccessoryViewExportFormat"])
  else if ([keyPath isEqualToString:@"saveAccessoryViewOptionsSvgPdfToSvgPath"])
  {
    export_format_t exportFormat = self->saveAccessoryViewExportFormat;
    BOOL isSvgFormat = (exportFormat == EXPORT_FORMAT_SVG);
    BOOL isDirectory = NO;
    [self->saveAccessoryViewSvgWarning setHidden:
      (!isSvgFormat ||
       ([[NSFileManager defaultManager]
         fileExistsAtPath:self->saveAccessoryViewOptionsSvgPdfToSvgPath isDirectory:&isDirectory] && !isDirectory))];
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
    [self->saveAccessoryViewExportFormatOptionsPanes setExportFormatOptionsJpegPanelDelegate:self];
    [self->saveAccessoryViewExportFormatOptionsPanes setExportFormatOptionsSvgPanelDelegate:self];
  }//end if (!self->saveAccessoryViewExportFormatOptionsPanes)
  [self->saveAccessoryViewExportFormatOptionsPanes setJpegQualityPercent:self->saveAccessoryViewOptionsJpegQualityPercent];
  [self->saveAccessoryViewExportFormatOptionsPanes setJpegBackgroundColor:self->saveAccessoryViewOptionsJpegBackgroundColor];
  [self->saveAccessoryViewExportFormatOptionsPanes setSvgPdfToSvgPath:self->saveAccessoryViewOptionsSvgPdfToSvgPath];
  NSPanel* panelToOpen = nil;
  export_format_t exportFormat = [self->saveAccessoryViewPopupFormat selectedTag];
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
    if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    {
      [self setSaveAccessoryViewOptionsJpegQualityPercent:[self->saveAccessoryViewExportFormatOptionsPanes jpegQualityPercent]];
      [self setSaveAccessoryViewOptionsJpegBackgroundColor:[self->saveAccessoryViewExportFormatOptionsPanes jpegBackgroundColor]];
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    else if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    {
      [self setSaveAccessoryViewOptionsSvgPdfToSvgPath:[self->saveAccessoryViewExportFormatOptionsPanes svgPdfToSvgPath]];
    }//end if (exportFormatOptionsPanel == [self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsSvgPanel])
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
  /*else if ([sender tag] == EXPORT_FORMAT_SVG)
    ok = [[AppController appController] isPdfToSvgAvailable];*/
  return ok;
}
//end validateMenuItem:

@end
