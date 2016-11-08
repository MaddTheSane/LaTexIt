//
//  ExportFormatOptionsPanes.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ExportFormatOptionsDelegate;

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
  
  IBOutlet NSPanel*  exportFormatOptionsTextPanel;
  IBOutlet NSBox*    exportFormatOptionsTextBox;
  IBOutlet NSButton* exportFormatOptionsTextExportPreambleButton;
  IBOutlet NSButton* exportFormatOptionsTextExportEnvironmentButton;
  IBOutlet NSButton* exportFormatOptionsTextExportBodyButton;
  IBOutlet NSButton* exportFormatOptionsTextOKButton;
  IBOutlet NSButton* exportFormatOptionsTextCancelButton;

  BOOL textExportPreamble;
  BOOL textExportEnvironment;
  BOOL textExportBody;
  id   exportFormatOptionsTextPanelDelegate;
}

-(id) initWithLoadingFromNib;

-(NSPanel*) exportFormatOptionsJpegPanel;
@property CGFloat jpegQualityPercent;
@property (retain) NSColor *jpegBackgroundColor;
@property (assign) id<ExportFormatOptionsDelegate> exportFormatOptionsJpegPanelDelegate;

-(NSPanel*)  exportFormatOptionsSvgPanel;
@property (copy) NSString *svgPdfToSvgPath;
@property (assign) id<ExportFormatOptionsDelegate> exportFormatOptionsSvgPanelDelegate;

-(NSPanel*)  exportFormatOptionsTextPanel;
-(NSBox*)    exportFormatOptionsTextBox;

@property BOOL textExportPreamble;
@property BOOL textExportEnvironment;
@property BOOL textExportBody;
@property (assign) id<ExportFormatOptionsDelegate> exportFormatOptionsTextPanelDelegate;

-(IBAction) svgPdfToSvgPathModify:(id)sender;
-(IBAction) close:(id)sender;

#pragma mark delegate
-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

@end

@protocol ExportFormatOptionsDelegate <NSObject>

-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

@end
