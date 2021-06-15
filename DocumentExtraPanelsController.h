//
//  DocumentExtraPanelsController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/04/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class ExportFormatOptionsPanes;

@interface DocumentExtraPanelsController : NSNib {
  IBOutlet NSView*        saveAccessoryView;
  IBOutlet NSTextField*   saveAccessoryViewFormatLabel;
  IBOutlet NSPopUpButton* saveAccessoryViewPopupFormat;
  IBOutlet NSButton*      saveAccessoryViewOptionsButton;
  IBOutlet NSButton*      saveAccessoryViewJpegWarning;
  IBOutlet NSButton*      saveAccessoryViewSvgWarning;
  IBOutlet NSButton*      saveAccessoryViewMathMLWarning;
  IBOutlet NSTextField*   saveAccessoryViewScaleLabel;
  IBOutlet NSTextField*   saveAccessoryViewScalePercentTextField;
  
  IBOutlet NSWindow*   logWindow;
  IBOutlet NSTextView* logTextView;

  IBOutlet NSWindow*    baselineWindow;
  IBOutlet NSTextField* baselineTextField;

  ExportFormatOptionsPanes* saveAccessoryViewExportFormatOptionsPanes;
  
  export_format_t saveAccessoryViewExportFormat;
  CGFloat         saveAccessoryViewExportScalePercent;
  CGFloat         saveAccessoryViewOptionsJpegQualityPercent;
  NSColor*        saveAccessoryViewOptionsJpegBackgroundColor;
  NSString*       saveAccessoryViewOptionsSvgPdfToSvgPath;
  BOOL            saveAccessoryViewOptionsTextExportPreamble;
  BOOL            saveAccessoryViewOptionsTextExportEnvironment;
  BOOL            saveAccessoryViewOptionsTextExportBody;
  NSString*       saveAccessoryViewOptionsPDFWofGSWriteEngine;
  NSString*       saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel;
  BOOL            saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled;
  
  NSSavePanel* currentSavePanel;
  NSArray* nibTopLevelObjects;
}

-(id) initWithLoadingFromNib;

-(NSWindow*)   logWindow;
-(NSTextView*) logTextView;
-(NSString*)   log;
-(void)        setLog:(NSString*)value;

-(NSWindow*)    baselineWindow;
-(NSTextField*) baselineTextField;

-(export_format_t) saveAccessoryViewExportFormat;
-(void)            setSaveAccessoryViewExportFormat:(export_format_t)value;
-(CGFloat)         saveAccessoryViewScalePercent;
-(void)            setSaveAccessoryViewScalePercent:(CGFloat)value;
-(CGFloat)         saveAccessoryViewOptionsJpegQualityPercent;
-(void)            setSaveAccessoryViewOptionsJpegQualityPercent:(CGFloat)value;
-(NSColor*)        saveAccessoryViewOptionsJpegBackgroundColor;
-(void)            setSaveAccessoryViewOptionsJpegBackgroundColor:(NSColor*)value;
-(NSString*)       saveAccessoryViewOptionsSvgPdfToSvgPath;
-(void)            setSaveAccessoryViewOptionsSvgPdfToSvgPath:(NSString*)value;
-(BOOL)            saveAccessoryViewOptionsTextExportPreamble;
-(void)            setSaveAccessoryViewOptionsTextExportPreamble:(BOOL)value;
-(BOOL)            saveAccessoryViewOptionsTextExportEnvironment;
-(void)            setSaveAccessoryViewOptionsTextExportEnvironment:(BOOL)value;
-(BOOL)            saveAccessoryViewOptionsTextExportBody;
-(void)            setSaveAccessoryViewOptionsTextExportBody:(BOOL)value;
-(NSString*)       saveAccessoryViewOptionsPDFWofGSWriteEngine;
-(void)            setSaveAccessoryViewOptionsPDFWofGSWriteEngine:(NSString*)value;
-(NSString*)       saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel;
-(void)            setSaveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel:(NSString*)value;
-(BOOL)            saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled;
-(void)            setSaveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled:(BOOL)value;

-(NSSavePanel*) currentSavePanel;
-(void) setCurrentSavePanel:(NSSavePanel*)value;

-(IBAction) openSaveAccessoryViewOptions:(id)sender;
-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

@end
