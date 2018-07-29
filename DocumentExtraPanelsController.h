//
//  DocumentExtraPanelsController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class ExportFormatOptionsPanes;

@interface DocumentExtraPanelsController : NSNib {
  NSView*        saveAccessoryView;
  IBOutlet NSTextField*   saveAccessoryViewFormatLabel;
  IBOutlet NSPopUpButton* saveAccessoryViewPopupFormat;
  IBOutlet NSButton*      saveAccessoryViewOptionsButton;
  IBOutlet NSButton*      saveAccessoryViewJpegWarning;
  IBOutlet NSButton*      saveAccessoryViewSvgWarning;
  IBOutlet NSButton*      saveAccessoryViewMathMLWarning;
  IBOutlet NSTextField*   saveAccessoryViewScaleLabel;
  IBOutlet NSTextField*   saveAccessoryViewScalePercentTextField;
  
  __weak NSWindow*   logWindow;
  __unsafe_unretained NSTextView* logTextView;

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
  
  NSSavePanel* __weak currentSavePanel;
}

-(instancetype) initWithLoadingFromNib;

@property (strong) IBOutlet NSView *saveAccessoryView;
@property (weak) IBOutlet NSWindow *logWindow;
@property (unsafe_unretained) IBOutlet NSTextView *logTextView;
@property (atomic, copy) NSString *log;

@property (nonatomic) export_format_t   saveAccessoryViewExportFormat;
@property (nonatomic) CGFloat           saveAccessoryViewScalePercent;
@property CGFloat           saveAccessoryViewOptionsJpegQualityPercent;
@property (strong) NSColor* saveAccessoryViewOptionsJpegBackgroundColor;
@property (nonatomic, copy) NSString*    saveAccessoryViewOptionsSvgPdfToSvgPath;
@property BOOL              saveAccessoryViewOptionsTextExportPreamble;
@property BOOL              saveAccessoryViewOptionsTextExportEnvironment;
@property BOOL              saveAccessoryViewOptionsTextExportBody;
@property (copy) NSString * saveAccessoryViewOptionsPDFWofGSWriteEngine;
@property (copy) NSString * saveAccessoryViewOptionsPDFWofGSPDFCompatibilityLevel;
@property BOOL              saveAccessoryViewOptionsPDFWofMetaDataInvisibleGraphicsEnabled;

@property (nonatomic, weak) NSSavePanel *currentSavePanel;

-(IBAction) openSaveAccessoryViewOptions:(id)sender;
-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok;

@end
