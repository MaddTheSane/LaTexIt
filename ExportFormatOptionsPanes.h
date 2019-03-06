//
//  ExportFormatOptionsPanes.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/04/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ExportFormatOptionsDelegate;

@interface ExportFormatOptionsPanes : NSNib {
  __weak NSPanel*     exportFormatOptionsJpegPanel;
  IBOutlet __weak NSBox*       exportFormatOptionsJpegBox;
  IBOutlet __weak NSSlider*    exportFormatOptionsJpegQualitySlider;
  IBOutlet __weak NSTextField* exportFormatOptionsJpegQualityLeastLabel;
  IBOutlet __weak NSTextField* exportFormatOptionsJpegQualityLowLabel;
  IBOutlet __weak NSTextField* exportFormatOptionsJpegQualityMediumLabel;
  IBOutlet __weak NSTextField* exportFormatOptionsJpegQualityHighLabel;
  IBOutlet __weak NSTextField* exportFormatOptionsJpegQualityMaxiLabel;
  IBOutlet __weak NSTextField* exportFormatOptionsJpegQualityLabel;
  IBOutlet __weak NSTextField* exportFormatOptionsJpegQualityTextField;
  IBOutlet __weak NSTextField* exportFormatOptionsJpegBackgroundColorLabel;
  IBOutlet __weak NSColorWell* exportFormatOptionsJpegBackgroundColorWell;
  IBOutlet __weak NSButton*    exportFormatOptionsJpegOKButton;
  IBOutlet __weak NSButton*    exportFormatOptionsJpegCancelButton;
  
  float  jpegQualityPercent;
  NSColor* jpegBackgroundColor;
  __weak id<ExportFormatOptionsDelegate>       exportFormatOptionsJpegPanelDelegate;

  __weak NSPanel*     exportFormatOptionsSvgPanel;
  IBOutlet __weak NSBox*       exportFormatOptionsSvgBox;
  IBOutlet __weak NSTextField* exportFormatOptionsSvgPdfToSvgPathTextField;
  IBOutlet __weak NSButton*    exportFormatOptionsSvgPdfToSvgPathModifyButton;
  IBOutlet __weak NSButton*    exportFormatOptionsSvgOKButton;
  IBOutlet __weak NSButton*    exportFormatOptionsSvgCancelButton;
  
  NSString* svgPdfToSvgPath;
  __weak id<ExportFormatOptionsDelegate>        exportFormatOptionsSvgPanelDelegate;
  
  __weak NSPanel*  exportFormatOptionsTextPanel;
  __weak NSBox*    exportFormatOptionsTextBox;
  IBOutlet __weak NSButton* exportFormatOptionsTextExportPreambleButton;
  IBOutlet __weak NSButton* exportFormatOptionsTextExportEnvironmentButton;
  IBOutlet __weak NSButton* exportFormatOptionsTextExportBodyButton;
  IBOutlet __weak NSButton* exportFormatOptionsTextOKButton;
  IBOutlet __weak NSButton* exportFormatOptionsTextCancelButton;

  BOOL textExportPreamble;
  BOOL textExportEnvironment;
  BOOL textExportBody;
  __weak id<ExportFormatOptionsDelegate>   exportFormatOptionsTextPanelDelegate;
  
  IBOutlet __weak NSPanel*exportFormatOptionsPDFWofPanel;
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
  __weak id<ExportFormatOptionsDelegate>        exportFormatOptionsPDFWofPanelDelegate;

  IBOutlet NSPanel*       exportFormatOptionsPDFPanel;
  IBOutlet NSBox*         exportFormatOptionsPDFMetadataBox;
  IBOutlet NSButton*      exportFormatOptionsPDFMetaDataInvisibleGraphicsEnabledCheckBox;
  IBOutlet NSButton*      exportFormatOptionsPDFOKButton;
  IBOutlet NSButton*      exportFormatOptionsPDFCancelButton;
  
  BOOL      pdfMetaDataInvisibleGraphicsEnabled;
  __weak id<ExportFormatOptionsDelegate> exportFormatOptionsPDFPanelDelegate;
}

-(instancetype) initWithLoadingFromNib NS_DESIGNATED_INITIALIZER;

@property (weak) IBOutlet NSPanel *exportFormatOptionsJpegPanel;
@property float jpegQualityPercent;
@property (retain) NSColor *jpegBackgroundColor;
@property (weak) id<ExportFormatOptionsDelegate> exportFormatOptionsJpegPanelDelegate;

@property (weak) IBOutlet NSPanel *exportFormatOptionsSvgPanel;
@property (copy) NSString *svgPdfToSvgPath;
@property (weak) id<ExportFormatOptionsDelegate> exportFormatOptionsSvgPanelDelegate;

@property (weak) IBOutlet NSPanel *exportFormatOptionsTextPanel;
@property (weak) IBOutlet NSBox   *exportFormatOptionsTextBox;

@property BOOL textExportPreamble;
@property BOOL textExportEnvironment;
@property BOOL textExportBody;
@property (weak) id<ExportFormatOptionsDelegate> exportFormatOptionsTextPanelDelegate;

@property (weak) IBOutlet NSPanel *exportFormatOptionsPDFWofPanel;
@property (copy) NSString *pdfWofGSWriteEngine;
@property (copy) NSString *pdfWofGSPDFCompatibilityLevel;
@property BOOL pdfWofMetaDataInvisibleGraphicsEnabled;
@property (weak) id<ExportFormatOptionsDelegate> exportFormatOptionsPDFWofPanelDelegate;

-(NSPanel*)  exportFormatOptionsPDFPanel;
@property BOOL pdfMetaDataInvisibleGraphicsEnabled;
@property (weak) id<ExportFormatOptionsDelegate> exportFormatOptionsPDFPanelDelegate;

-(IBAction) svgPdfToSvgPathModify:(id)sender;

-(IBAction) close:(id)sender;

#pragma mark delegate
-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

@end

@protocol ExportFormatOptionsDelegate <NSObject>

-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

@end
