//
//  DocumentExtraPanelsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/04/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import "DocumentExtraPanelsController.h"

#import "ExportFormatOptionsPanes.h"
#import "PreferencesController.h"

@implementation DocumentExtraPanelsController

#pragma mark init/load/dealloc

-(id) initWithLoadingFromNib
{
  if ((!(self = [super initWithNibNamed:@"DocumentExtraPanelsController" bundle:nil])))
    return nil;
  PreferencesController* preferencesController = [PreferencesController sharedController];
  self->saveAccessoryViewExportFormat               = [preferencesController exportFormat];
  self->saveAccessoryViewExportScalePercent         = [preferencesController exportScalePercent];
  self->saveAccessoryViewOptionsJpegQualityPercent  = [preferencesController exportJpegQualityPercent];
  self->saveAccessoryViewOptionsJpegBackgroundColor = [[preferencesController exportJpegBackgroundColor] retain];
  [self instantiateNibWithOwner:self topLevelObjects:nil];
  return self;
}
//end initWithLoadingFromNib

-(void) dealloc
{
  [self removeObserver:self forKeyPath:@"saveAccessoryViewExportFormat"];
  [self->saveAccessoryViewPopupFormat unbind:NSSelectedTagBinding];
  [self->saveAccessoryViewScalePercentTextField unbind:NSValueBinding];
  [self->saveAccessoryViewExportFormatOptionsPanes release];
  [self->saveAccessoryViewOptionsJpegBackgroundColor release];
  [self->saveAccessoryView release]; //release the extra retain count
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  [self->saveAccessoryView retain]; //to avoid unwanted deallocation when save panel is closed
  [self->logWindow setTitle:NSLocalizedString(@"Execution log", @"Execution log")];
  [self->saveAccessoryViewPopupFormat bind:NSSelectedTagBinding toObject:self
    withKeyPath:@"saveAccessoryViewExportFormat" options:nil];
  [self->saveAccessoryViewScalePercentTextField bind:NSValueBinding toObject:self
    withKeyPath:@"saveAccessoryViewExportScalePercent" options:nil];
  [self addObserver:self forKeyPath:@"saveAccessoryViewExportFormat" options:0 context:nil];
  [self observeValueForKeyPath:@"saveAccessoryViewExportFormat" ofObject:self change:nil context:nil];
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
    }

    BOOL isJpegFormat = (exportFormat == EXPORT_FORMAT_JPEG);
    allowOptions = isJpegFormat;
    [self->saveAccessoryViewJpegWarning setHidden:!isJpegFormat];
    if (isJpegFormat)
      [self->currentSavePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpg", @"jpeg", nil]];
    else
      [self->currentSavePanel setRequiredFileType:extension];
    [self->saveAccessoryViewOptionsButton setEnabled:allowOptions];
  }//end if ([keyPath isEqualToString:@"saveAccessoryViewExportFormat"])
}
//end observeValueForKeyPath:ofObject:change:context:

#pragma mark actions
-(IBAction) openSaveAccessoryViewOptions:(id)sender
{
  if (!self->saveAccessoryViewExportFormatOptionsPanes)
  {
    self->saveAccessoryViewExportFormatOptionsPanes = [[ExportFormatOptionsPanes alloc] initWithLoadingFromNib];
    [self->saveAccessoryViewExportFormatOptionsPanes setExportFormatOptionsJpegPanelDelegate:self];
  }
  [self->saveAccessoryViewExportFormatOptionsPanes setJpegQualityPercent:self->saveAccessoryViewOptionsJpegQualityPercent];
  [self->saveAccessoryViewExportFormatOptionsPanes setJpegBackgroundColor:self->saveAccessoryViewOptionsJpegBackgroundColor];
  [NSApp runModalForWindow:[self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsJpegPanel]];
}
//end openSaveAccessoryViewOptions:

-(void) exportFormatOptionsJpegPanel:(ExportFormatOptionsPanes*)exportFormatOptionsPanes didCloseWithOK:(BOOL)ok
{
  if (ok)
  {
    [self setSaveAccessoryViewOptionsJpegQualityPercent:[exportFormatOptionsPanes jpegQualityPercent]];
    [self setSaveAccessoryViewOptionsJpegBackgroundColor:[exportFormatOptionsPanes jpegBackgroundColor]];
  }
  [NSApp stopModal];
  [[self->saveAccessoryViewExportFormatOptionsPanes exportFormatOptionsJpegPanel] orderOut:self];
}
//end exportFormatOptionsJpegPanel:didCloseWithOK:

@end
