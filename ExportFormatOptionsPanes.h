//
//  ExportFormatOptionsPanes.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ExportFormatOptionsPanes : NSNib {
  IBOutlet NSPanel*     exportFormatOptionsJpegPanel;
  IBOutlet NSBox*       exportFormatOptionsJpegBox;
  IBOutlet NSSlider*    exportFormatOptionsJpegQualitySlider;
  IBOutlet NSTextField* exportFormatOptionsJpegQualityLeastLabel;
  IBOutlet NSTextField* exportFormatOptionsJpegQualityLowLabel;
  IBOutlet NSTextField* exportFormatOptionsJpegQualityMediumLabel;
  IBOutlet NSTextField* exportFormatOptionsJpegQualityHighLabel;
  IBOutlet NSTextField* exportFormatOptionsJpegQualityMaxiLabel;
  IBOutlet NSTextField* exportFormatOptionsJpegQualityLabel;
  IBOutlet NSTextField* exportFormatOptionsJpegQualityTextField;
  IBOutlet NSTextField* exportFormatOptionsJpegBackgroundColorLabel;
  IBOutlet NSColorWell* exportFormatOptionsJpegBackgroundColorWell;
  IBOutlet NSButton*    exportFormatOptionsJpegOKButton;
  IBOutlet NSButton*    exportFormatOptionsJpegCancelButton;
  
  CGFloat  jpegQualityPercent;
  NSColor* jpegBackgroundColor;
  id       exportFormatOptionsJpegPanelDelegate;

  IBOutlet NSPanel*     exportFormatOptionsSvgPanel;
  IBOutlet NSBox*       exportFormatOptionsSvgBox;
  IBOutlet NSTextField* exportFormatOptionsSvgPdfToSvgPathTextField;
  IBOutlet NSButton*    exportFormatOptionsSvgPdfToSvgPathModifyButton;
  IBOutlet NSButton*    exportFormatOptionsSvgOKButton;
  IBOutlet NSButton*    exportFormatOptionsSvgCancelButton;


  NSString* svgPdfToSvgPath;
  id        exportFormatOptionsSvgPanelDelegate;
}

-(id) initWithLoadingFromNib;

-(NSPanel*) exportFormatOptionsJpegPanel;
-(CGFloat) jpegQualityPercent;
-(void)    setJpegQualityPercent:(CGFloat)value;
-(NSColor*) jpegBackgroundColor;
-(void)     setJpegBackgroundColor:(NSColor*)value;
-(id)   exportFormatOptionsJpegPanelDelegate;
-(void) setExportFormatOptionsJpegPanelDelegate:(id)delegate;

-(NSPanel*)  exportFormatOptionsSvgPanel;
-(NSString*) svgPdfToSvgPath;
-(void)      setSvgPdfToSvgPath:(NSString*)value;
-(id)   exportFormatOptionsSvgPanelDelegate;
-(void) setExportFormatOptionsSvgPanelDelegate:(id)delegate;

-(IBAction) svgPdfToSvgPathModify:(id)sender;
-(IBAction) close:(id)sender;

#pragma mark delegate
-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

@end
