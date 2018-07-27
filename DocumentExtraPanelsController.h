//
//  DocumentExtraPanelsController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/04/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class ExportFormatOptionsPanes;

@interface DocumentExtraPanelsController : NSNib {
  IBOutlet NSView*        saveAccessoryView;
  IBOutlet NSPopUpButton* saveAccessoryViewPopupFormat;
  IBOutlet NSButton*      saveAccessoryViewOptionsButton;
  IBOutlet NSButton*      saveAccessoryViewJpegWarning;
  IBOutlet NSTextField*   saveAccessoryViewScalePercentTextField;
  
  IBOutlet NSWindow*   logWindow;
  IBOutlet NSTextView* logTextView;

  ExportFormatOptionsPanes* saveAccessoryViewExportFormatOptionsPanes;
  
  export_format_t saveAccessoryViewExportFormat;
  CGFloat         saveAccessoryViewExportScalePercent;
  CGFloat         saveAccessoryViewOptionsJpegQualityPercent;
  NSColor*        saveAccessoryViewOptionsJpegBackgroundColor;

  NSSavePanel* currentSavePanel;
}

-(id) initWithLoadingFromNib;

-(NSWindow*)   logWindow;
-(NSTextView*) logTextView;
-(NSString*)   log;
-(void)        setLog:(NSString*)value;

-(export_format_t) saveAccessoryViewExportFormat;
-(void)            setSaveAccessoryViewExportFormat:(export_format_t)value;
-(CGFloat)         saveAccessoryViewScalePercent;
-(void)            setSaveAccessoryViewScalePercent:(CGFloat)value;
-(CGFloat)         saveAccessoryViewOptionsJpegQualityPercent;
-(void)            setSaveAccessoryViewOptionsJpegQualityPercent:(CGFloat)value;
-(NSColor*)        saveAccessoryViewOptionsJpegBackgroundColor;
-(void)            setSaveAccessoryViewOptionsJpegBackgroundColor:(NSColor*)value;

-(NSSavePanel*) currentSavePanel;
-(void) setCurrentSavePanel:(NSSavePanel*)value;

-(IBAction) openSaveAccessoryViewOptions:(id)sender;
-(void) exportFormatOptionsJpegPanel:(ExportFormatOptionsPanes*)exportFormatOptionsPanes didCloseWithOK:(BOOL)ok;

@end
