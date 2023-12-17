//
//  ExportFormatOptionsPanes.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
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
  IBOutlet NSBox*       exportFormatOptionsSvgPdfToSvgBox;
  IBOutlet NSTextField* exportFormatOptionsSvgPdfToSvgPathTextField;
  IBOutlet NSButton*    exportFormatOptionsSvgPdfToSvgPathModifyButton;
  IBOutlet NSBox*       exportFormatOptionsSvgPdfToCairoBox;
  IBOutlet NSTextField* exportFormatOptionsSvgPdfToCairoPathTextField;
  IBOutlet NSButton*    exportFormatOptionsSvgPdfToCairoPathModifyButton;
  IBOutlet NSButton*    exportFormatOptionsSvgOKButton;
  IBOutlet NSButton*    exportFormatOptionsSvgCancelButton;
  
  NSString* svgPdfToSvgPath;
  NSString* svgPdfToCairoPath;
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
  
  IBOutlet NSPanel*       exportFormatOptionsPDFWofPanel;
  IBOutlet NSBox*         exportFormatOptionsPDFWofGSBox;
  IBOutlet NSTextField*   exportFormatOptionsPDFWofGSWriteEngineLabel;
  IBOutlet NSPopUpButton* exportFormatOptionsPDFWofGSWriteEnginePopUpButton;
  IBOutlet NSTextField*   exportFormatOptionsPDFWofGSPDFCompatibilityLevelLabel;
  IBOutlet NSPopUpButton* exportFormatOptionsPDFWofGSPDFCompatibilityLevelPopUpButton;
  IBOutlet NSBox*         exportFormatOptionsPDFWofMetadataBox;
  IBOutlet NSButton*      exportFormatOptionsPDFWofMetaDataInvisibleGraphicsEnabledCheckBox;
  IBOutlet NSButton*      exportFormatOptionsPDFWofOKButton;
  IBOutlet NSButton*      exportFormatOptionsPDFWofCancelButton;
  
  NSString* pdfWofGSWriteEngine;
  NSString* pdfWofGSPDFCompatibilityLevel;
  BOOL      pdfWofMetaDataInvisibleGraphicsEnabled;
  id        exportFormatOptionsPDFWofPanelDelegate;

  IBOutlet NSPanel*       exportFormatOptionsPDFPanel;
  IBOutlet NSBox*         exportFormatOptionsPDFMetadataBox;
  IBOutlet NSButton*      exportFormatOptionsPDFMetaDataInvisibleGraphicsEnabledCheckBox;
  IBOutlet NSButton*      exportFormatOptionsPDFOKButton;
  IBOutlet NSButton*      exportFormatOptionsPDFCancelButton;
  
  BOOL      pdfMetaDataInvisibleGraphicsEnabled;
  id        exportFormatOptionsPDFPanelDelegate;
  
  NSArray* nibTopLevelObjects;
}

-(id) initWithLoadingFromNib;

-(NSPanel*) exportFormatOptionsJpegPanel;
-(CGFloat)  jpegQualityPercent;
-(void)     setJpegQualityPercent:(CGFloat)value;
-(NSColor*) jpegBackgroundColor;
-(void)     setJpegBackgroundColor:(NSColor*)value;
-(id)       exportFormatOptionsJpegPanelDelegate;
-(void)     setExportFormatOptionsJpegPanelDelegate:(id)delegate;

-(NSPanel*)  exportFormatOptionsSvgPanel;
-(NSString*) svgPdfToSvgPath;
-(void)      setSvgPdfToSvgPath:(NSString*)value;
-(NSString*) svgPdfToCairoPath;
-(void)      setSvgPdfToCairoPath:(NSString*)value;
-(id)        exportFormatOptionsSvgPanelDelegate;
-(void)      setExportFormatOptionsSvgPanelDelegate:(id)delegate;

-(NSPanel*)  exportFormatOptionsTextPanel;
-(NSBox*)    exportFormatOptionsTextBox;
-(BOOL)      textExportPreamble;
-(void)      setTextExportPreamble:(BOOL)value;
-(BOOL)      textExportEnvironment;
-(void)      setTextExportEnvironment:(BOOL)value;
-(BOOL)      textExportBody;
-(void)      setTextExportBody:(BOOL)value;
-(id)        exportFormatOptionsTextPanelDelegate;
-(void)      setExportFormatOptionsTextPanelDelegate:(id)delegate;

-(NSPanel*)  exportFormatOptionsPDFWofPanel;
-(NSString*) pdfWofGSWriteEngine;
-(void)      setPdfWofGSWriteEngine:(NSString*)value;
-(NSString*) pdfWofGSPDFCompatibilityLevel;
-(void)      setPdfWofGSPDFCompatibilityLevel:(NSString*)value;
-(BOOL)      pdfWofMetaDataInvisibleGraphicsEnabled;
-(void)      setPdfWofMetaDataInvisibleGraphicsEnabled:(BOOL)value;
-(id)        exportFormatOptionsPDFWofPanelDelegate;
-(void)      setExportFormatOptionsPDFWofPanelDelegate:(id)delegate;

-(NSPanel*)  exportFormatOptionsPDFPanel;
-(BOOL)      pdfMetaDataInvisibleGraphicsEnabled;
-(void)      setPdfMetaDataInvisibleGraphicsEnabled:(BOOL)value;
-(id)        exportFormatOptionsPDFPanelDelegate;
-(void)      setExportFormatOptionsPDFPanelDelegate:(id)delegate;

-(IBAction) svgPdfToSvgPathModify:(id)sender;
-(IBAction) svgPdfToCairoPathModify:(id)sender;

-(IBAction) close:(id)sender;

#pragma mark delegate
-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

@end
